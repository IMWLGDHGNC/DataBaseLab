-- Four business roles from Week 1. Loginless users are reproducible test identities,
-- not production authentication accounts. No db_owner/db_datawriter membership.
SET NOCOUNT ON;
CREATE ROLE shop_manager;
CREATE ROLE shop_buyer;
CREATE ROLE shop_inventory;
CREATE ROLE shop_orders;
CREATE USER test_manager WITHOUT LOGIN;
CREATE USER test_buyer WITHOUT LOGIN;
CREATE USER test_inventory WITHOUT LOGIN;
CREATE USER test_orders WITHOUT LOGIN;
ALTER ROLE shop_manager ADD MEMBER test_manager;
ALTER ROLE shop_buyer ADD MEMBER test_buyer;
ALTER ROLE shop_inventory ADD MEMBER test_inventory;
ALTER ROLE shop_orders ADD MEMBER test_orders;

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
GRANT UPDATE (HandlingNote) ON dbo.OrderException TO shop_orders;

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
('inventory_read_stock','test_inventory',N'SELECT TOP (1) BatchID FROM dbo.vw_InventoryStatus;',0),
('inventory_quarantine','test_inventory',N'UPDATE dbo.InventoryBatch SET BatchStatus=BatchStatus WHERE BatchID=''B00'';',0),
('inventory_cannot_change_price','test_inventory',N'UPDATE dbo.Product SET CurrentPrice=5 WHERE ProductID=''S00'';',229),
('orders_read_detail','test_orders',N'SELECT TOP (1) SalesOrderID FROM dbo.vw_OrderDetail;',0),
('orders_edit_note','test_orders',N'UPDATE dbo.OrderException SET HandlingNote=HandlingNote WHERE ExceptionID=''EX00'';',0),
('orders_cannot_change_stock','test_orders',N'UPDATE dbo.InventoryBatch SET OnHandQty=0 WHERE BatchID=''B00'';',229),
('orders_cannot_change_points','test_orders',N'UPDATE dbo.Customer SET PointsBalance=0 WHERE CustomerID=''C00'';',229);

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
