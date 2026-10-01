-- Employee, ordinary-customer and member roles from Week 1. Loginless users are
-- reproducible test identities, not production authentication accounts.
-- Suppliers have no login in this phase. No db_owner/db_datawriter membership.
SET NOCOUNT ON;
IF DATABASE_PRINCIPAL_ID(N'shop_manager') IS NULL CREATE ROLE shop_manager;
IF DATABASE_PRINCIPAL_ID(N'shop_buyer') IS NULL CREATE ROLE shop_buyer;
IF DATABASE_PRINCIPAL_ID(N'shop_inventory') IS NULL CREATE ROLE shop_inventory;
IF DATABASE_PRINCIPAL_ID(N'shop_orders') IS NULL CREATE ROLE shop_orders;
IF DATABASE_PRINCIPAL_ID(N'shop_customer') IS NULL CREATE ROLE shop_customer;
IF DATABASE_PRINCIPAL_ID(N'shop_member') IS NULL CREATE ROLE shop_member;
IF USER_ID(N'test_manager') IS NULL CREATE USER test_manager WITHOUT LOGIN;
IF USER_ID(N'test_buyer') IS NULL CREATE USER test_buyer WITHOUT LOGIN;
IF USER_ID(N'test_inventory') IS NULL CREATE USER test_inventory WITHOUT LOGIN;
IF USER_ID(N'test_orders') IS NULL CREATE USER test_orders WITHOUT LOGIN;
IF USER_ID(N'test_customer') IS NULL CREATE USER test_customer WITHOUT LOGIN;
IF USER_ID(N'test_member') IS NULL CREATE USER test_member WITHOUT LOGIN;
IF USER_ID(N'test_other_member') IS NULL CREATE USER test_other_member WITHOUT LOGIN;
IF USER_ID(N'test_unbound_member') IS NULL CREATE USER test_unbound_member WITHOUT LOGIN;
IF IS_ROLEMEMBER(N'shop_manager',N'test_manager')<>1 ALTER ROLE shop_manager ADD MEMBER test_manager;
IF IS_ROLEMEMBER(N'shop_buyer',N'test_buyer')<>1 ALTER ROLE shop_buyer ADD MEMBER test_buyer;
IF IS_ROLEMEMBER(N'shop_inventory',N'test_inventory')<>1 ALTER ROLE shop_inventory ADD MEMBER test_inventory;
IF IS_ROLEMEMBER(N'shop_orders',N'test_orders')<>1 ALTER ROLE shop_orders ADD MEMBER test_orders;
IF IS_ROLEMEMBER(N'shop_customer',N'test_customer')<>1 ALTER ROLE shop_customer ADD MEMBER test_customer;
IF IS_ROLEMEMBER(N'shop_member',N'test_member')<>1 ALTER ROLE shop_member ADD MEMBER test_member;
IF IS_ROLEMEMBER(N'shop_member',N'test_other_member')<>1 ALTER ROLE shop_member ADD MEMBER test_other_member;
IF IS_ROLEMEMBER(N'shop_member',N'test_unbound_member')<>1 ALTER ROLE shop_member ADD MEMBER test_unbound_member;

GRANT SELECT ON dbo.vw_ProductSales TO shop_manager;
GRANT SELECT ON dbo.vw_InventoryStatus TO shop_manager;
GRANT SELECT ON dbo.vw_OrderDetail TO shop_manager;
GRANT SELECT ON dbo.Product TO shop_manager;
GRANT UPDATE (CurrentPrice,SaleStatus,ReorderLevel) ON dbo.Product TO shop_manager;

GRANT SELECT ON dbo.Supplier TO shop_buyer;
GRANT SELECT ON dbo.Product TO shop_buyer;
GRANT SELECT ON dbo.PurchaseOrder TO shop_buyer;
GRANT SELECT ON dbo.PurchaseOrderItem TO shop_buyer;
GRANT UPDATE (ContactName,ContactPhone,CooperationStatus) ON dbo.Supplier TO shop_buyer;

GRANT SELECT ON dbo.vw_InventoryStatus TO shop_inventory;
GRANT SELECT ON dbo.InventoryBatch TO shop_inventory;
GRANT SELECT ON dbo.InventoryMovement TO shop_inventory;
GRANT UPDATE (BatchStatus) ON dbo.InventoryBatch TO shop_inventory;

GRANT SELECT ON dbo.vw_OrderDetail TO shop_orders;
GRANT SELECT ON dbo.SalesOrder TO shop_orders;
GRANT SELECT ON dbo.OrderException TO shop_orders;
-- Exception resolution is a single-row operation protected by the Week 4 CHECK.
-- Multi-table order/payment/stock workflows remain intentionally unavailable.
GRANT UPDATE (HandlingStatus,HandlingNote) ON dbo.OrderException TO shop_orders;

-- Only an administrator can maintain the database-principal/customer binding.
-- Keeping it outside dbo leaves the business-table count at 15.
GO
IF SCHEMA_ID(N'customer_security') IS NULL
    EXEC(N'CREATE SCHEMA customer_security AUTHORIZATION dbo;');
GO
IF OBJECT_ID(N'customer_security.CustomerPrincipal',N'U') IS NULL
    CREATE TABLE customer_security.CustomerPrincipal (
        PrincipalName sysname NOT NULL PRIMARY KEY,
        CustomerID varchar(12) NOT NULL UNIQUE
            REFERENCES dbo.Customer(CustomerID)
    );
INSERT customer_security.CustomerPrincipal(PrincipalName,CustomerID)
SELECT v.PrincipalName,v.CustomerID
FROM (VALUES (N'test_customer','C02'),(N'test_member','C00'),
             (N'test_other_member','C01')) AS v(PrincipalName,CustomerID)
WHERE NOT EXISTS (SELECT 1 FROM customer_security.CustomerPrincipal AS cp
                  WHERE cp.PrincipalName=v.PrincipalName);
IF EXISTS (SELECT 1 FROM customer_security.CustomerPrincipal AS cp
           WHERE (cp.PrincipalName=N'test_customer' AND cp.CustomerID<>'C02')
              OR (cp.PrincipalName=N'test_member' AND cp.CustomerID<>'C00')
              OR (cp.PrincipalName=N'test_other_member' AND cp.CustomerID<>'C01'))
    THROW 51449,'Test principal has an unexpected customer binding.',1;
GO
CREATE OR ALTER PROCEDURE dbo.usp_MyOrders
    @SalesOrderID varchar(12)=NULL,
    @RowCount int=NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT o.SalesOrderID,o.OrderStatus,o.CreatedAt,o.CompletedAt,
           o.RecipientName,o.RecipientPhone,o.ShippingAddress,o.TotalAmount,
           i.SalesItemID,i.ProductID,p.ProductName,i.Quantity,i.DealUnitPrice
    FROM customer_security.CustomerPrincipal AS cp
    JOIN dbo.SalesOrder AS o ON o.CustomerID=cp.CustomerID
    LEFT JOIN dbo.SalesOrderItem AS i ON i.SalesOrderID=o.SalesOrderID
    LEFT JOIN dbo.Product AS p ON p.ProductID=i.ProductID
    WHERE cp.PrincipalName=USER_NAME()
      AND (@SalesOrderID IS NULL OR o.SalesOrderID=@SalesOrderID)
    ORDER BY o.SalesOrderID,i.SalesItemID;
    SET @RowCount=@@ROWCOUNT;
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_MyPoints
    @PointsMovementID varchar(12)=NULL,
    @RowCount int=NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.CustomerID,c.PointsBalance,p.PointsMovementID,
           p.SalesOrderID,p.PointsDelta,p.BasedAmount,p.Reason,p.OccurredAt
    FROM customer_security.CustomerPrincipal AS cp
    JOIN dbo.Customer AS c ON c.CustomerID=cp.CustomerID AND c.IsMember=1
    LEFT JOIN dbo.PointsMovement AS p ON p.CustomerID=c.CustomerID
    WHERE cp.PrincipalName=USER_NAME()
      AND (@PointsMovementID IS NULL OR p.PointsMovementID=@PointsMovementID)
    ORDER BY p.OccurredAt,p.PointsMovementID;
    SET @RowCount=@@ROWCOUNT;
END;
GO
GRANT SELECT (ProductID,ProductName,Brand,Specification,SaleUnit,CurrentPrice)
    ON dbo.Product TO shop_customer,shop_member;
GRANT EXECUTE ON dbo.usp_MyOrders TO shop_customer,shop_member;
GRANT EXECUTE ON dbo.usp_MyPoints TO shop_member;

-- Execute actual statements under each loginless identity. Writes are rolled back.
CREATE TABLE #RoleCases (CaseName varchar(50),UserName sysname,Statement nvarchar(max),ExpectedError int);
CREATE TABLE #RoleResults (CaseName varchar(50),ExpectedError int,ActualError int);
INSERT #RoleCases VALUES
('manager_read_sales','test_manager',N'SELECT TOP (1) ProductID FROM dbo.vw_ProductSales;',0),
('manager_change_price','test_manager',N'UPDATE dbo.Product SET CurrentPrice=CurrentPrice WHERE ProductID=''S00'';',0),
('manager_cannot_read_salary','test_manager',N'SELECT TOP (1) MonthlySalary FROM dbo.Employee;',229),
('buyer_read_supplier','test_buyer',N'SELECT TOP (1) SupplierID FROM dbo.Supplier;',0),
('buyer_edit_supplier','test_buyer',N'UPDATE dbo.Supplier SET ContactName=ContactName WHERE SupplierID=''SUP00'';',0),
('buyer_cannot_approve','test_buyer',N'UPDATE dbo.PurchaseOrder SET ApprovedBy=''P01'' WHERE PurchaseOrderID=''PO00'';',229),
('buyer_cannot_direct_create','test_buyer',N'INSERT dbo.PurchaseOrder(PurchaseOrderID,SupplierID,CreatedBy,CreatedAt) VALUES(''W4PO'',''SUP00'',''P02'',''20260923 10:00:00'');',229),
('inventory_read_stock','test_inventory',N'SELECT TOP (1) BatchID FROM dbo.vw_InventoryStatus;',0),
('inventory_quarantine','test_inventory',N'UPDATE dbo.InventoryBatch SET BatchStatus=BatchStatus WHERE BatchID=''B00'';',0),
('inventory_cannot_change_price','test_inventory',N'UPDATE dbo.Product SET CurrentPrice=5 WHERE ProductID=''S00'';',229),
('inventory_cannot_change_qty','test_inventory',N'UPDATE dbo.InventoryBatch SET OnHandQty=0 WHERE BatchID=''B00'';',230),
('orders_read_detail','test_orders',N'SELECT TOP (1) SalesOrderID FROM dbo.vw_OrderDetail;',0),
('orders_edit_note','test_orders',N'UPDATE dbo.OrderException SET HandlingNote=HandlingNote WHERE ExceptionID=''EX00'';',0),
('orders_resolve_exception','test_orders',N'UPDATE dbo.OrderException SET HandlingStatus=N''已解决'',HandlingNote=N''已核实并处理'' WHERE ExceptionID=''EX00'';',0),
('orders_cannot_resolve_blank','test_orders',N'UPDATE dbo.OrderException SET HandlingStatus=N''已解决'',HandlingNote=NULL WHERE ExceptionID=''EX00'';',547),
('orders_cannot_change_stock','test_orders',N'UPDATE dbo.InventoryBatch SET OnHandQty=0 WHERE BatchID=''B00'';',229),
('orders_cannot_change_points','test_orders',N'UPDATE dbo.Customer SET PointsBalance=0 WHERE CustomerID=''C00'';',229),
('customer_browse_product','test_customer',N'SELECT TOP (1) ProductName,CurrentPrice FROM dbo.Product;',0),
('customer_cannot_read_internal_product','test_customer',N'SELECT TOP (1) ReorderLevel FROM dbo.Product;',230),
('customer_own_order','test_customer',N'DECLARE @n int; EXEC dbo.usp_MyOrders @SalesOrderID=''ST02'',@RowCount=@n OUTPUT; IF @n<>1 THROW 51440,''Own order missing.'',1;',0),
('customer_other_order_hidden','test_customer',N'DECLARE @n int; EXEC dbo.usp_MyOrders @SalesOrderID=''ST00'',@RowCount=@n OUTPUT; IF @n<>0 THROW 51441,''Other order exposed.'',1;',0),
('customer_cannot_read_all_orders','test_customer',N'SELECT TOP (1) SalesOrderID FROM dbo.SalesOrder;',229),
('customer_cannot_read_identity_map','test_customer',N'SELECT TOP (1) CustomerID FROM customer_security.CustomerPrincipal;',229),
('customer_cannot_read_points','test_customer',N'EXEC dbo.usp_MyPoints;',229),
('customer_cannot_change_order','test_customer',N'UPDATE dbo.SalesOrder SET TotalAmount=1 WHERE SalesOrderID=''ST02'';',229),
('member_own_order','test_member',N'DECLARE @n int; EXEC dbo.usp_MyOrders @SalesOrderID=''ST00'',@RowCount=@n OUTPUT; IF @n<>2 THROW 51442,''Member order lines missing.'',1;',0),
('member_other_order_hidden','test_member',N'DECLARE @n int; EXEC dbo.usp_MyOrders @SalesOrderID=''ST01'',@RowCount=@n OUTPUT; IF @n<>0 THROW 51443,''Other member order exposed.'',1;',0),
('member_own_points','test_member',N'DECLARE @n int; EXEC dbo.usp_MyPoints @RowCount=@n OUTPUT; IF @n<>1 THROW 51444,''Own points missing.'',1;',0),
('member_other_points_hidden','test_member',N'DECLARE @n int; EXEC dbo.usp_MyPoints @PointsMovementID=''PM01'',@RowCount=@n OUTPUT; IF @n<>0 THROW 51446,''Other member points exposed.'',1;',0),
('other_member_own_points','test_other_member',N'DECLARE @n int; EXEC dbo.usp_MyPoints @RowCount=@n OUTPUT; IF @n<>1 THROW 51445,''Other member points missing.'',1;',0),
('member_cannot_change_points','test_member',N'UPDATE dbo.Customer SET PointsBalance=0 WHERE CustomerID=''C00'';',229),
('member_cannot_read_all_points','test_member',N'SELECT TOP (1) CustomerID FROM dbo.PointsMovement;',229),
('unbound_member_sees_no_orders','test_unbound_member',N'DECLARE @n int; EXEC dbo.usp_MyOrders @RowCount=@n OUTPUT; IF @n<>0 THROW 51447,''Unbound identity saw orders.'',1;',0),
('unbound_member_sees_no_points','test_unbound_member',N'DECLARE @n int; EXEC dbo.usp_MyPoints @RowCount=@n OUTPUT; IF @n<>0 THROW 51448,''Unbound identity saw points.'',1;',0);

DECLARE @CaseName varchar(50),@UserName sysname,@Statement nvarchar(max),
        @Expected int,@Actual int,@Impersonating bit;
DECLARE role_tests CURSOR LOCAL FAST_FORWARD FOR
    SELECT CaseName,UserName,Statement,ExpectedError FROM #RoleCases ORDER BY CaseName;
OPEN role_tests;
FETCH NEXT FROM role_tests INTO @CaseName,@UserName,@Statement,@Expected;
WHILE @@FETCH_STATUS=0
BEGIN
    SET @Actual=0;
    SET @Impersonating=0;
    BEGIN TRANSACTION;
    BEGIN TRY
        EXECUTE AS USER=@UserName;
        SET @Impersonating=1;
        EXEC sys.sp_executesql @Statement;
    END TRY
    BEGIN CATCH
        SET @Actual=ERROR_NUMBER();
    END CATCH;
    IF @Impersonating=1 REVERT;
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    INSERT #RoleResults VALUES(@CaseName,@Expected,@Actual);
    FETCH NEXT FROM role_tests INTO @CaseName,@UserName,@Statement,@Expected;
END;
CLOSE role_tests;
DEALLOCATE role_tests;
SELECT *,CASE WHEN ActualError=ExpectedError THEN 'PASS' ELSE 'FAIL' END AS Result
FROM #RoleResults ORDER BY CaseName;
IF EXISTS(SELECT 1 FROM #RoleResults WHERE ActualError<>ExpectedError)
    THROW 51430,'A role permission case did not match.',1;
SELECT 'ROLE_PASS' AS Result,COUNT(*) AS CaseCount FROM #RoleResults;
DROP TABLE #RoleCases;
DROP TABLE #RoleResults;
