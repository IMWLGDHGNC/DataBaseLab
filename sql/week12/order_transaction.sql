-- Isolated demo after test_data.sql. Change @OrderID and @OperatorID for another
-- sample. Keeping one implementation preserves the Web API and trigger rules.
SET NOCOUNT ON;
DECLARE @OrderID varchar(12)='W12SALE', @OperatorID varchar(12)='P00';
SELECT SalesOrderID,OrderStatus,TotalAmount,CompletedAt
FROM dbo.SalesOrder WHERE SalesOrderID=@OrderID;

EXEC dbo.sp_CompleteOrder @OrderID=@OrderID,@OperatorID=@OperatorID;

SELECT i.ProductID,i.Quantity,r.BatchID,r.ReservationStatus,b.OnHandQty,m.QuantityDelta
FROM dbo.SalesOrderItem i
JOIN dbo.InventoryReservation r ON r.SalesItemID=i.SalesItemID AND r.ReservationStatus=N'已转出库'
JOIN dbo.InventoryBatch b ON b.BatchID=r.BatchID
JOIN dbo.InventoryMovement m ON m.BatchID=b.BatchID AND m.SalesItemID=i.SalesItemID
WHERE i.SalesOrderID=@OrderID
ORDER BY i.ProductID,b.BatchID;
SELECT @@TRANCOUNT AS RemainingTransactions;
