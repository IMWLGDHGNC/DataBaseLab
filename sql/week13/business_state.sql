-- Read from a separate connection before A1 and after both sessions finish.
SELECT BatchID,OnHandQty FROM dbo.InventoryBatch WHERE BatchID='W13BP';
SELECT SalesOrderID,OrderStatus,CompletedAt FROM dbo.SalesOrder
WHERE SalesOrderID IN ('W13OA','W13OB') ORDER BY SalesOrderID;
SELECT ReservationID,ReservedQty,ReservationStatus FROM dbo.InventoryReservation
WHERE SalesItemID IN ('W13IA','W13IB') ORDER BY ReservationID;
SELECT SalesItemID,QuantityDelta FROM dbo.InventoryMovement
WHERE BatchID='W13BP' AND MovementType=N'销售出库' ORDER BY SalesItemID;
SELECT BeforeQty,AfterQty,QuantityDelta FROM dbo.InventoryAudit
WHERE BatchID='W13BP' AND OperationType='UPDATE' ORDER BY AuditID;
SELECT SalesOrderID,PointsDelta FROM dbo.PointsMovement
WHERE SalesOrderID IN ('W13OA','W13OB') ORDER BY SalesOrderID;
