-- Teaching fixtures only. Never delete real historical orders or stock records.
-- Every UPDATE/DELETE below is preceded by a SELECT with the same filter.
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;

-- 1. Product: insert, select, update, delete an unreferenced test SKU.
SELECT N'Product BEFORE' AS Stage, COUNT(*) AS [RowCount] FROM dbo.Product WHERE ProductID='W3_PRODUCT';
IF EXISTS (SELECT 1 FROM dbo.Product WHERE ProductID='W3_PRODUCT')
    THROW 51100, 'Demo ID already exists.', 1;
INSERT dbo.Product(ProductID,CategoryID,ProductName,Brand,Specification,SaleUnit,CurrentPrice)
VALUES ('W3_PRODUCT','CAT00',N'演示零食',N'实验品牌',N'10g',N'包',3.00);
SELECT N'Product INSERT' AS Stage,ProductID,CurrentPrice,SaleStatus,ReorderLevel
FROM dbo.Product WHERE ProductID='W3_PRODUCT';
UPDATE dbo.Product SET CurrentPrice=3.50 WHERE ProductID='W3_PRODUCT';
IF @@ROWCOUNT<>1 THROW 51101, 'Expected one product update.', 1;
SELECT N'Product UPDATE' AS Stage,ProductID,CurrentPrice FROM dbo.Product WHERE ProductID='W3_PRODUCT';
DELETE dbo.Product WHERE ProductID='W3_PRODUCT';
SELECT N'Product DELETE' AS Stage,COUNT(*) AS [RowCount] FROM dbo.Product WHERE ProductID='W3_PRODUCT';
IF EXISTS (SELECT 1 FROM dbo.Product WHERE ProductID='W3_PRODUCT') THROW 51102, 'Product deletion failed.', 1;

-- 2. Inventory: a new receipt and an explicit loss movement explain the balance.
SELECT N'Inventory BEFORE' AS Stage,COUNT(*) AS [RowCount] FROM dbo.InventoryBatch WHERE BatchID='W3_BATCH';
IF EXISTS (SELECT 1 FROM dbo.PurchaseOrder WHERE PurchaseOrderID='W3_PO')
    THROW 51103, 'Demo purchase ID already exists.', 1;
INSERT dbo.PurchaseOrder(PurchaseOrderID,SupplierID,CreatedBy,CreatedAt,ApprovedBy,ApprovedAt,ReceivedBy,ReceivedAt,OrderStatus)
VALUES ('W3_PO','SUP00','P02','20260917 09:00:00','P01','20260917 09:05:00','P00','20260917 09:30:00',N'已收货');
INSERT dbo.PurchaseOrderItem(PurchaseItemID,PurchaseOrderID,ProductID,OrderedQty,UnitCost)
VALUES ('W3_PDI','W3_PO','S01',20,2.20);
INSERT dbo.InventoryBatch(BatchID,PurchaseItemID,SupplierBatchNo,ProductionDate,ExpiryDate,ReceivedAt,OnHandQty)
VALUES ('W3_BATCH','W3_PDI','DEMO-260917','20260901','20270901','20260917 09:30:00',20);
INSERT dbo.InventoryMovement(MovementID,BatchID,MovementType,QuantityDelta,PurchaseItemID,Reason,OperatorID,OccurredAt)
VALUES ('W3_IN','W3_BATCH',N'采购入库',20,'W3_PDI',N'演示整单验收','P00','20260917 09:30:00');
SELECT N'Inventory INSERT' AS Stage,BatchID,OnHandQty FROM dbo.InventoryBatch WHERE BatchID='W3_BATCH';
UPDATE dbo.InventoryBatch SET OnHandQty=OnHandQty-2 WHERE BatchID='W3_BATCH';
IF @@ROWCOUNT<>1 THROW 51104, 'Expected one batch update.', 1;
INSERT dbo.InventoryMovement(MovementID,BatchID,MovementType,QuantityDelta,Reason,OperatorID,OccurredAt)
VALUES ('W3_LOSS','W3_BATCH',N'报损',-2,N'演示包装破损','P00','20260917 10:00:00');
SELECT N'Inventory UPDATE' AS Stage,BatchID,OnHandQty FROM dbo.InventoryBatch WHERE BatchID='W3_BATCH';
IF (SELECT OnHandQty FROM dbo.InventoryBatch WHERE BatchID='W3_BATCH') <> 18
 OR (SELECT SUM(QuantityDelta) FROM dbo.InventoryMovement WHERE BatchID='W3_BATCH') <> 18
    THROW 51105, 'Inventory movement and balance disagree.', 1;
-- Remove only this transaction's teaching fixture, children before parents.
SELECT * FROM dbo.InventoryMovement WHERE BatchID='W3_BATCH';
DELETE dbo.InventoryMovement WHERE BatchID='W3_BATCH';
SELECT * FROM dbo.InventoryBatch WHERE BatchID='W3_BATCH';
DELETE dbo.InventoryBatch WHERE BatchID='W3_BATCH';
SELECT * FROM dbo.PurchaseOrderItem WHERE PurchaseItemID='W3_PDI';
DELETE dbo.PurchaseOrderItem WHERE PurchaseItemID='W3_PDI';
SELECT * FROM dbo.PurchaseOrder WHERE PurchaseOrderID='W3_PO';
DELETE dbo.PurchaseOrder WHERE PurchaseOrderID='W3_PO';
SELECT N'Inventory DELETE' AS Stage,COUNT(*) AS [RowCount] FROM dbo.InventoryBatch WHERE BatchID='W3_BATCH';
IF EXISTS (SELECT 1 FROM dbo.InventoryBatch WHERE BatchID='W3_BATCH') THROW 51106, 'Batch deletion failed.', 1;

-- 3. Orders: header + item + reservation form a single teaching transaction.
-- Fixed business time keeps the historical sample reproducible in future years.
DECLARE @DemoTime DATETIME2(0)='20260917 12:00:00';
SELECT N'Order BEFORE' AS Stage,COUNT(*) AS [RowCount] FROM dbo.SalesOrder WHERE SalesOrderID='W3_ORDER';
IF EXISTS (SELECT 1 FROM dbo.SalesOrder WHERE SalesOrderID='W3_ORDER') THROW 51107, 'Demo order ID already exists.', 1;
IF NOT EXISTS (
    SELECT 1 FROM dbo.InventoryBatch b WITH (UPDLOCK,HOLDLOCK)
    JOIN dbo.PurchaseOrderItem pi ON pi.PurchaseItemID=b.PurchaseItemID
    JOIN dbo.Product p ON p.ProductID=pi.ProductID
    WHERE b.BatchID='B00' AND p.ProductID='S01' AND p.SaleStatus=N'在售'
      AND b.BatchStatus=N'合格' AND b.ExpiryDate>CONVERT(date,@DemoTime)
      AND b.OnHandQty-COALESCE((SELECT SUM(r.ReservedQty) FROM dbo.InventoryReservation r
          WHERE r.BatchID=b.BatchID AND r.ReservationStatus=N'有效'),0)>=1
) THROW 51108, 'No eligible stock for the order demo.', 1;
INSERT dbo.SalesOrder(SalesOrderID,CustomerID,CreatedAt,RecipientName,RecipientPhone,ShippingAddress,TotalAmount)
VALUES ('W3_ORDER','C02',@DemoTime,N'演示收件人','13000000000',N'演示地址 A',4.40);
INSERT dbo.SalesOrderItem(SalesItemID,SalesOrderID,ProductID,Quantity,DealUnitPrice)
VALUES ('W3_ITEM','W3_ORDER','S01',1,4.40);
INSERT dbo.InventoryReservation(ReservationID,SalesItemID,BatchID,ReservedQty,ReservedAt)
VALUES ('W3_RES','W3_ITEM','B00',1,@DemoTime);
SELECT N'Order INSERT' AS Stage,SalesOrderID,OrderStatus,TotalAmount,ShippingAddress
FROM dbo.SalesOrder WHERE SalesOrderID='W3_ORDER';
UPDATE dbo.SalesOrder SET ShippingAddress=N'演示地址 B' WHERE SalesOrderID='W3_ORDER';
IF @@ROWCOUNT<>1 THROW 51109, 'Expected one order update.', 1;
SELECT N'Order UPDATE' AS Stage,SalesOrderID,OrderStatus,TotalAmount,ShippingAddress
FROM dbo.SalesOrder WHERE SalesOrderID='W3_ORDER';
SELECT * FROM dbo.InventoryReservation WHERE ReservationID='W3_RES';
DELETE dbo.InventoryReservation WHERE ReservationID='W3_RES';
SELECT * FROM dbo.SalesOrderItem WHERE SalesItemID='W3_ITEM';
DELETE dbo.SalesOrderItem WHERE SalesItemID='W3_ITEM';
SELECT * FROM dbo.SalesOrder WHERE SalesOrderID='W3_ORDER';
DELETE dbo.SalesOrder WHERE SalesOrderID='W3_ORDER';
SELECT N'Order DELETE' AS Stage,COUNT(*) AS [RowCount] FROM dbo.SalesOrder WHERE SalesOrderID='W3_ORDER';
IF EXISTS (SELECT 1 FROM dbo.SalesOrder WHERE SalesOrderID='W3_ORDER') THROW 51110, 'Order deletion failed.', 1;

ROLLBACK TRANSACTION;
SELECT N'CRUD_PASS' AS Result,N'All teaching changes rolled back' AS Detail;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
