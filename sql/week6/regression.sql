-- Week 6 post-migration regression checks. Run only in DataBaseLab_Week6 (optionally with a timestamp suffix) after migration.sql.
-- Negative writes and the positive write are isolated in rolled-back transactions.
SET NOCOUNT ON;
SET XACT_ABORT OFF;
IF DB_NAME()<>N'DataBaseLab_Week6' AND DB_NAME() NOT LIKE N'DataBaseLab[_]Week6[_]%'
    THROW 51700, 'Run regression checks only in the isolated DataBaseLab_Week6 staging database.', 1;
IF COL_LENGTH(N'dbo.InventoryMovement',N'PurchaseItemID') IS NOT NULL
    THROW 51701, 'Week 6 migration has not removed the redundant purchase source column.', 1;
CREATE TABLE #Week6Cases(CaseName varchar(60),ExpectedValue nvarchar(100),ActualValue nvarchar(100),Result varchar(4));

DECLARE @TableCount int=(SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'dbo') AND is_ms_shipped=0);
DECLARE @ColumnCount int=(SELECT COUNT(*) FROM sys.columns AS c JOIN sys.tables AS t ON t.object_id=c.object_id WHERE t.schema_id=SCHEMA_ID(N'dbo') AND t.is_ms_shipped=0);
DECLARE @ForeignKeyCount int=(SELECT COUNT(*) FROM sys.foreign_keys AS f JOIN sys.tables AS t ON t.object_id=f.parent_object_id WHERE t.schema_id=SCHEMA_ID(N'dbo') AND t.is_ms_shipped=0);
DECLARE @UniqueConstraintCount int=(SELECT COUNT(*) FROM sys.key_constraints AS k JOIN sys.tables AS t ON t.object_id=k.parent_object_id WHERE t.schema_id=SCHEMA_ID(N'dbo') AND t.is_ms_shipped=0 AND k.type=N'UQ');
DECLARE @BusinessRows bigint;
SELECT @BusinessRows=
    (SELECT COUNT_BIG(*) FROM dbo.ProductCategory)+(SELECT COUNT_BIG(*) FROM dbo.Product)+
    (SELECT COUNT_BIG(*) FROM dbo.Supplier)+(SELECT COUNT_BIG(*) FROM dbo.Employee)+
    (SELECT COUNT_BIG(*) FROM dbo.Customer)+(SELECT COUNT_BIG(*) FROM dbo.PurchaseOrder)+
    (SELECT COUNT_BIG(*) FROM dbo.PurchaseOrderItem)+(SELECT COUNT_BIG(*) FROM dbo.InventoryBatch)+
    (SELECT COUNT_BIG(*) FROM dbo.SalesOrder)+(SELECT COUNT_BIG(*) FROM dbo.SalesOrderItem)+
    (SELECT COUNT_BIG(*) FROM dbo.InventoryReservation)+(SELECT COUNT_BIG(*) FROM dbo.InventoryMovement)+
    (SELECT COUNT_BIG(*) FROM dbo.PaymentRecord)+(SELECT COUNT_BIG(*) FROM dbo.PointsMovement)+
    (SELECT COUNT_BIG(*) FROM dbo.OrderException);
IF @TableCount<>15 OR @BusinessRows<>46
    THROW 51702, 'Expected 15 business tables and 46 baseline rows.', 1;
IF @ColumnCount<>106 OR @ForeignKeyCount<>23 OR @UniqueConstraintCount<>9
    THROW 51723, 'The v1.0 catalog does not match 106 columns, 23 foreign keys and 9 UNIQUE constraints.', 1;
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name IN (N'FK_Movement_BatchPurchase',N'FK_InventoryMovement_PurchaseItemID'))
   OR EXISTS (SELECT 1 FROM sys.key_constraints WHERE name=N'UQ_InventoryBatch_2')
    THROW 51724, 'Redundant v0.1 source constraints remain after migration.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.triggers WHERE name=N'TR_InventoryBatch_PurchaseSourceImmutable' AND parent_id=OBJECT_ID(N'dbo.InventoryBatch') AND is_disabled=0)
    THROW 51725, 'Batch purchase source history protection is missing.', 1;

-- Key business results must retain their Week 4 baseline meaning.
DECLARE @CompletedQty int, @CompletedAmount decimal(12,2);
SELECT @CompletedQty=COALESCE(SUM(i.Quantity),0),
       @CompletedAmount=COALESCE(SUM(i.Quantity*i.DealUnitPrice),0)
FROM dbo.SalesOrder AS o JOIN dbo.SalesOrderItem AS i ON i.SalesOrderID=o.SalesOrderID
WHERE o.OrderStatus=N'已完成';
IF @CompletedQty<>15 OR @CompletedAmount<>64.50
    THROW 51703, 'Completed sales baseline differs from 15 items and 64.50 yuan.', 1;
IF EXISTS (
    SELECT 1 FROM dbo.SalesOrder AS o
    OUTER APPLY (SELECT SUM(i.Quantity*i.DealUnitPrice) AS Amount FROM dbo.SalesOrderItem AS i WHERE i.SalesOrderID=o.SalesOrderID) AS x
    WHERE x.Amount IS NULL OR o.TotalAmount<>x.Amount
)
    THROW 51704, 'Order totals do not reconcile to order detail.', 1;
IF EXISTS (
    SELECT 1 FROM dbo.InventoryBatch AS b
    OUTER APPLY (SELECT SUM(m.QuantityDelta) AS NetQty FROM dbo.InventoryMovement AS m WHERE m.BatchID=b.BatchID) AS x
    WHERE b.OnHandQty<>COALESCE(x.NetQty,0)
)
    THROW 51705, 'Inventory balances do not reconcile to movement history.', 1;
IF EXISTS (
    SELECT 1 FROM dbo.Customer AS c
    OUTER APPLY (SELECT SUM(p.PointsDelta) AS Balance FROM dbo.PointsMovement AS p WHERE p.CustomerID=c.CustomerID) AS x
    WHERE c.PointsBalance<>COALESCE(x.Balance,0)
) OR EXISTS (SELECT 1 FROM dbo.Customer WHERE IsMember=0 AND PointsBalance<>0)
    THROW 51706, 'Customer balances do not reconcile to points movements.', 1;
IF EXISTS (
    SELECT 1 FROM dbo.InventoryBatch AS b
    CROSS APPLY (SELECT COALESCE(SUM(r.ReservedQty),0) AS Qty FROM dbo.InventoryReservation AS r WHERE r.BatchID=b.BatchID AND r.ReservationStatus=N'有效') AS x
    WHERE x.Qty>b.OnHandQty
)
    THROW 51707, 'Active reservations exceed on-hand inventory.', 1;
DECLARE @B01AvailableAtBaseline int;
SELECT @B01AvailableAtBaseline=CASE WHEN b.ExpiryDate<='20260918' OR b.BatchStatus<>N'合格' OR p.SaleStatus<>N'在售' THEN 0 ELSE b.OnHandQty-COALESCE(r.ActiveQty,0) END
FROM dbo.InventoryBatch AS b
JOIN dbo.PurchaseOrderItem AS pi ON pi.PurchaseItemID=b.PurchaseItemID
JOIN dbo.Product AS p ON p.ProductID=pi.ProductID
OUTER APPLY (SELECT SUM(x.ReservedQty) AS ActiveQty FROM dbo.InventoryReservation AS x WHERE x.BatchID=b.BatchID AND x.ReservationStatus=N'有效') AS r
WHERE b.BatchID='B01';
IF @B01AvailableAtBaseline<>0 THROW 51722, 'B01 fixed-date available quantity differs from baseline.', 1;

IF EXISTS (
    SELECT 1 FROM dbo.InventoryReservation AS r
    JOIN dbo.SalesOrderItem AS si ON si.SalesItemID=r.SalesItemID
    JOIN dbo.InventoryBatch AS b ON b.BatchID=r.BatchID
    JOIN dbo.PurchaseOrderItem AS pi ON pi.PurchaseItemID=b.PurchaseItemID
    WHERE si.ProductID<>pi.ProductID
)
    THROW 51708, 'Reservation batch product differs from sales item product.', 1;
IF EXISTS (
    SELECT 1 FROM dbo.InventoryMovement AS m
    LEFT JOIN dbo.InventoryBatch AS b ON b.BatchID=m.BatchID
    LEFT JOIN dbo.PurchaseOrderItem AS pi ON pi.PurchaseItemID=b.PurchaseItemID
    WHERE m.MovementType=N'采购入库' AND pi.PurchaseItemID IS NULL
)
    THROW 51709, 'Inbound movement purchase source cannot be recovered through its batch.', 1;
IF EXISTS (
    SELECT 1 FROM dbo.PurchaseOrderItem AS i
    JOIN dbo.PurchaseOrder AS o ON o.PurchaseOrderID=i.PurchaseOrderID
    OUTER APPLY (
        SELECT SUM(m.QuantityDelta) AS ReceivedQty
        FROM dbo.InventoryBatch AS b
        JOIN dbo.InventoryMovement AS m ON m.BatchID=b.BatchID AND m.MovementType=N'采购入库'
        WHERE b.PurchaseItemID=i.PurchaseItemID
    ) AS x
    WHERE o.OrderStatus=N'已收货' AND COALESCE(x.ReceivedQty,0)<>i.OrderedQty
)
    THROW 51718, 'Received purchase quantities do not match inbound movement rows.', 1;
IF EXISTS (
    SELECT 1 FROM dbo.InventoryMovement AS m
    JOIN dbo.InventoryBatch AS b ON b.BatchID=m.BatchID
    JOIN dbo.PurchaseOrderItem AS p ON p.PurchaseItemID=b.PurchaseItemID
    JOIN dbo.SalesOrderItem AS s ON s.SalesItemID=m.SalesItemID
    JOIN dbo.SalesOrder AS o ON o.SalesOrderID=s.SalesOrderID
    WHERE m.MovementType=N'销售出库'
      AND (p.ProductID<>s.ProductID OR o.OrderStatus<>N'已完成' OR m.OccurredAt<>o.CompletedAt OR CONVERT(date,m.OccurredAt)>=b.ExpiryDate)
)
    THROW 51719, 'Sales movement, batch product, completion time, or expiry mapping is inconsistent.', 1;
IF EXISTS (
    SELECT 1 FROM dbo.SalesOrderItem AS i
    JOIN dbo.SalesOrder AS o ON o.SalesOrderID=i.SalesOrderID
    OUTER APPLY (SELECT -SUM(m.QuantityDelta) AS ShippedQty FROM dbo.InventoryMovement AS m WHERE m.SalesItemID=i.SalesItemID) AS x
    WHERE (o.OrderStatus=N'已完成' AND COALESCE(x.ShippedQty,0)<>i.Quantity)
       OR (o.OrderStatus<>N'已完成' AND COALESCE(x.ShippedQty,0)<>0)
)
    THROW 51720, 'Shipped quantities do not match order status and detail quantity.', 1;

-- A valid write is accepted, then rolled back so the fixed seed remains unchanged.
IF EXISTS (SELECT 1 FROM dbo.Product WHERE ProductID='W6OK')
    THROW 51710, 'W6OK already exists; use a fresh staging database.', 1;
BEGIN TRANSACTION;
INSERT dbo.Product(ProductID,CategoryID,ProductName,Brand,Specification,SaleUnit,CurrentPrice)
VALUES('W6OK','CAT00',N'第六周回滚验证商品',N'W6TEST',N'1g',N'包',1.00);
IF NOT EXISTS (SELECT 1 FROM dbo.Product WHERE ProductID='W6OK' AND SaleStatus=N'在售' AND ReorderLevel=0)
    THROW 51711, 'Valid insert or defaults failed.', 1;
ROLLBACK TRANSACTION;
IF EXISTS (SELECT 1 FROM dbo.Product WHERE ProductID='W6OK') THROW 51721, 'Valid test row was not rolled back.', 1;
INSERT #Week6Cases VALUES('valid_write_rollback',N'insert accepted; row absent after rollback',N'insert accepted; row absent after rollback','PASS');

-- Invalid FK and non-positive quantity must both be rejected (SQL Server error 547).
DECLARE @Actual int=0;
BEGIN TRANSACTION;
BEGIN TRY
    INSERT dbo.InventoryMovement(MovementID,BatchID,MovementType,QuantityDelta,SalesItemID,Reason,OperatorID,OccurredAt)
    VALUES('W6BADFK','W6MISSING',N'盘点调整',1,NULL,N'第六周负例',N'P00','20261010 10:00:00');
END TRY
BEGIN CATCH
    SET @Actual=ERROR_NUMBER();
END CATCH;
IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
IF @Actual<>547 THROW 51712, 'Invalid batch foreign key was not rejected with error 547.', 1;
INSERT #Week6Cases VALUES('invalid_batch_fk',N'547',CONVERT(nvarchar(100),@Actual),'PASS');

SET @Actual=0;
BEGIN TRANSACTION;
BEGIN TRY
    INSERT dbo.InventoryReservation(ReservationID,SalesItemID,BatchID,ReservedQty,ReservationStatus,ReservedAt,EndedAt)
    VALUES('W6BADQTY','SI03','B01',0,N'有效','20261010 10:00:00',NULL);
END TRY
BEGIN CATCH
    SET @Actual=ERROR_NUMBER();
END CATCH;
IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
IF @Actual<>547 THROW 51713, 'Zero reservation quantity was not rejected with error 547.', 1;
INSERT #Week6Cases VALUES('zero_reservation_qty',N'547',CONVERT(nvarchar(100),@Actual),'PASS');

-- A batch with movement history must not be relabeled to another purchase row.
SET @Actual=0;
BEGIN TRANSACTION;
BEGIN TRY
    UPDATE dbo.InventoryBatch SET PurchaseItemID='PDI02' WHERE BatchID='B00';
END TRY
BEGIN CATCH
    SET @Actual=ERROR_NUMBER();
END CATCH;
IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
IF @Actual<>51620 THROW 51726, 'Historical batch purchase source change was not rejected.', 1;
INSERT #Week6Cases VALUES('batch_purchase_source_immutable',N'51620',CONVERT(nvarchar(100),@Actual),'PASS');

-- Confirm the six established Week 4 role test identities remain present.
IF USER_ID(N'test_manager') IS NULL OR USER_ID(N'test_buyer') IS NULL OR
   USER_ID(N'test_inventory') IS NULL OR USER_ID(N'test_orders') IS NULL OR
   USER_ID(N'test_customer') IS NULL OR USER_ID(N'test_member') IS NULL
    THROW 51714, 'Week 4 role test identities are missing; run sql/week4/role.sql first.', 1;

-- Allowed read and denied stock write are executed as real database principals.
DECLARE @RoleActual int=0, @Impersonating bit=0, @ViewRows int=0;
BEGIN TRANSACTION;
BEGIN TRY
    EXECUTE AS USER=N'test_manager';
    SET @Impersonating=1;
    SELECT @ViewRows=COUNT(*) FROM dbo.vw_ProductSales;
END TRY
BEGIN CATCH
    SET @RoleActual=ERROR_NUMBER();
END CATCH;
IF @Impersonating=1 REVERT;
IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
IF @RoleActual<>0 OR @ViewRows=0 THROW 51715, 'Manager could not read the sales view.', 1;
INSERT #Week6Cases VALUES('manager_sales_view',N'allowed; at least one row',N'allowed; rows='+CONVERT(nvarchar(20),@ViewRows),'PASS');

SET @RoleActual=0;
SET @Impersonating=0;
BEGIN TRANSACTION;
BEGIN TRY
    EXECUTE AS USER=N'test_orders';
    SET @Impersonating=1;
    UPDATE dbo.InventoryBatch SET OnHandQty=OnHandQty WHERE BatchID='B00';
END TRY
BEGIN CATCH
    SET @RoleActual=ERROR_NUMBER();
END CATCH;
IF @Impersonating=1 REVERT;
IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
IF @RoleActual<>229 THROW 51716, 'Order role was not denied direct inventory updates with error 229.', 1;
INSERT #Week6Cases VALUES('orders_cannot_update_stock',N'229',CONVERT(nvarchar(100),@RoleActual),'PASS');

-- A customer must see their own order through the procedure and no other customer's order.
DECLARE @OwnOrderRows int=0, @OtherOrderRows int=0;
EXECUTE AS USER=N'test_customer';
EXEC dbo.usp_MyOrders @SalesOrderID='ST02',@RowCount=@OwnOrderRows OUTPUT;
EXEC dbo.usp_MyOrders @SalesOrderID='ST00',@RowCount=@OtherOrderRows OUTPUT;
REVERT;
IF @OwnOrderRows<>1 OR @OtherOrderRows<>0
    THROW 51717, 'Customer order procedure did not enforce own-order scope.', 1;
INSERT #Week6Cases VALUES('customer_order_scope',N'own=1; other=0',N'own='+CONVERT(nvarchar(20),@OwnOrderRows)+N'; other='+CONVERT(nvarchar(20),@OtherOrderRows),'PASS');

SELECT Metric,ExpectedValue,ActualValue,
       CASE WHEN ExpectedValue=ActualValue THEN N'一致' ELSE N'差异' END AS Comparison
FROM (VALUES
    (N'dbo business tables',N'15',CONVERT(nvarchar(30),@TableCount)),
    (N'dbo business attributes',N'106',CONVERT(nvarchar(30),@ColumnCount)),
    (N'dbo foreign keys',N'23',CONVERT(nvarchar(30),@ForeignKeyCount)),
    (N'dbo UNIQUE constraints',N'9',CONVERT(nvarchar(30),@UniqueConstraintCount)),
    (N'business rows',N'46',CONVERT(nvarchar(30),@BusinessRows)),
    (N'completed item quantity',N'15',CONVERT(nvarchar(30),@CompletedQty)),
    (N'completed sales amount',N'64.50',CONVERT(nvarchar(30),@CompletedAmount)),
    (N'InventoryMovement rows',N'6',CONVERT(nvarchar(30),(SELECT COUNT(*) FROM dbo.InventoryMovement)))
) AS CheckValues(Metric,ExpectedValue,ActualValue);

SELECT CaseName,ExpectedValue,ActualValue,Result FROM #Week6Cases ORDER BY CaseName;

-- These detail rows make the log auditable beyond a single PASS marker.
SELECT o.SalesOrderID,o.OrderStatus,COUNT(i.SalesItemID) AS DetailLines,
       SUM(i.Quantity) AS ItemQuantity,
       SUM(i.Quantity*i.DealUnitPrice) AS DetailAmount,
       o.TotalAmount AS StoredOrderAmount
FROM dbo.SalesOrder AS o LEFT JOIN dbo.SalesOrderItem AS i ON i.SalesOrderID=o.SalesOrderID
GROUP BY o.SalesOrderID,o.OrderStatus,o.TotalAmount ORDER BY o.SalesOrderID;
SELECT b.BatchID,pi.PurchaseItemID,pi.ProductID,b.OnHandQty,
       COALESCE(m.NetQty,0) AS MovementNetQty,COALESCE(r.ActiveQty,0) AS ActiveReservedQty,
       CASE WHEN b.ExpiryDate<='20260918' OR b.BatchStatus<>N'合格' OR p.SaleStatus<>N'在售'
            THEN 0 ELSE b.OnHandQty-COALESCE(r.ActiveQty,0) END AS AvailableAtBaselineDate
FROM dbo.InventoryBatch AS b
JOIN dbo.PurchaseOrderItem AS pi ON pi.PurchaseItemID=b.PurchaseItemID
JOIN dbo.Product AS p ON p.ProductID=pi.ProductID
OUTER APPLY (SELECT SUM(x.QuantityDelta) AS NetQty FROM dbo.InventoryMovement AS x WHERE x.BatchID=b.BatchID) AS m
OUTER APPLY (SELECT SUM(x.ReservedQty) AS ActiveQty FROM dbo.InventoryReservation AS x WHERE x.BatchID=b.BatchID AND x.ReservationStatus=N'有效') AS r
ORDER BY b.BatchID;
SELECT c.CustomerID,c.PointsBalance,COALESCE(p.PointsDeltaTotal,0) AS LedgerPoints
FROM dbo.Customer AS c
OUTER APPLY (SELECT SUM(x.PointsDelta) AS PointsDeltaTotal FROM dbo.PointsMovement AS x WHERE x.CustomerID=c.CustomerID) AS p
ORDER BY c.CustomerID;

DROP TABLE #Week6Cases;
SELECT N'W6_REGRESSION_PASS' AS Result, @TableCount AS BusinessTableCount,
       @BusinessRows AS BusinessRows, @CompletedQty AS CompletedItemCount,
       @CompletedAmount AS CompletedSalesAmount,
       N'Valid insert rolled back; invalid FK/quantity/source update rejected; role boundary checked' AS Checks;
