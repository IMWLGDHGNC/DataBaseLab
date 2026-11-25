-- Set @Round to C or R to read one business fixture from an independent connection.
DECLARE @Round char(1)='C';
SELECT b.BatchID,b.OnHandQty FROM dbo.InventoryBatch b
JOIN dbo.PurchaseOrderItem i ON i.PurchaseItemID=b.PurchaseItemID
WHERE i.ProductID='W13P'+@Round ORDER BY b.BatchID;
SELECT s.OrderStatus AS SaleStatus, p.OrderStatus AS ReceiptStatus
FROM dbo.SalesOrder s CROSS JOIN dbo.PurchaseOrder p
WHERE s.SalesOrderID='W13WS'+@Round AND p.PurchaseOrderID='W13WP'+@Round;
SELECT m.BatchID,m.QuantityDelta,m.MovementType FROM dbo.InventoryMovement m
WHERE m.SalesItemID='W13WSI'+@Round OR m.MovementID='W13WRM'+@Round ORDER BY m.BatchID;
