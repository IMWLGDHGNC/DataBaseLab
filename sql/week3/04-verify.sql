-- Snapshot verification, not triggers or a concurrent business workflow.
SET NOCOUNT ON;
IF (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped=0)<>15
    THROW 51200, '15 business tables', 1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE is_disabled=1 OR is_not_trusted=1) OR EXISTS(SELECT 1 FROM sys.check_constraints WHERE is_disabled=1 OR is_not_trusted=1)
    THROW 51201, 'Constraints enabled and trusted', 1;
IF EXISTS(SELECT 1 FROM dbo.SalesOrder o OUTER APPLY(SELECT SUM(Quantity*DealUnitPrice) Total FROM dbo.SalesOrderItem i WHERE i.SalesOrderID=o.SalesOrderID) x WHERE x.Total IS NULL OR x.Total<>o.TotalAmount)
    THROW 51202, 'Order totals and at least one item', 1;
IF EXISTS(SELECT 1 FROM dbo.InventoryBatch b OUTER APPLY(SELECT SUM(QuantityDelta) Qty FROM dbo.InventoryMovement m WHERE m.BatchID=b.BatchID) x WHERE COALESCE(x.Qty,0)<>b.OnHandQty)
    THROW 51203, 'Batch balances match ledger', 1;
IF EXISTS(SELECT 1 FROM dbo.InventoryBatch b CROSS APPLY(SELECT SUM(ReservedQty) Qty FROM dbo.InventoryReservation r WHERE r.BatchID=b.BatchID AND r.ReservationStatus=N'有效') x WHERE x.Qty>b.OnHandQty)
    THROW 51204, 'Reserved quantity does not exceed stock', 1;
IF EXISTS(SELECT 1 FROM dbo.InventoryReservation r JOIN dbo.InventoryBatch b ON b.BatchID=r.BatchID JOIN dbo.PurchaseOrderItem p ON p.PurchaseItemID=b.PurchaseItemID JOIN dbo.SalesOrderItem s ON s.SalesItemID=r.SalesItemID WHERE p.ProductID<>s.ProductID)
    THROW 51205, 'Reservation product matches item', 1;
IF EXISTS(SELECT 1 FROM dbo.PurchaseOrderItem i JOIN dbo.PurchaseOrder o ON o.PurchaseOrderID=i.PurchaseOrderID OUTER APPLY(SELECT SUM(m.QuantityDelta) Qty FROM dbo.InventoryMovement m WHERE m.PurchaseItemID=i.PurchaseItemID AND m.MovementType=N'采购入库') x WHERE o.OrderStatus=N'已收货' AND COALESCE(x.Qty,0)<>i.OrderedQty) OR EXISTS(SELECT 1 FROM dbo.InventoryBatch b JOIN dbo.PurchaseOrderItem i ON i.PurchaseItemID=b.PurchaseItemID JOIN dbo.PurchaseOrder o ON o.PurchaseOrderID=i.PurchaseOrderID WHERE o.ReceivedAt IS NULL OR b.ReceivedAt<>o.ReceivedAt)
    THROW 51206, 'Received purchase quantities and timestamps', 1;
IF EXISTS(SELECT 1 FROM dbo.PaymentRecord p JOIN dbo.SalesOrder o ON o.SalesOrderID=p.SalesOrderID WHERE p.PaymentStatus=N'成功' AND (p.Amount<>o.TotalAmount OR p.ResultAt<o.CreatedAt OR p.ResultAt>=DATEADD(minute,15,o.CreatedAt) OR o.OrderStatus NOT IN(N'待出库',N'已完成'))) OR EXISTS(SELECT 1 FROM dbo.SalesOrder o WHERE o.OrderStatus IN(N'待出库',N'已完成') AND NOT EXISTS(SELECT 1 FROM dbo.PaymentRecord p WHERE p.SalesOrderID=o.SalesOrderID AND p.PaymentStatus=N'成功'))
    THROW 51207, 'Successful payments equal order amount and are timely', 1;
IF EXISTS(SELECT 1 FROM dbo.SalesOrderItem i JOIN dbo.SalesOrder o ON o.SalesOrderID=i.SalesOrderID OUTER APPLY(SELECT -SUM(QuantityDelta) Qty FROM dbo.InventoryMovement m WHERE m.SalesItemID=i.SalesItemID) x WHERE (o.OrderStatus=N'已完成' AND COALESCE(x.Qty,0)<>i.Quantity) OR (o.OrderStatus<>N'已完成' AND COALESCE(x.Qty,0)<>0))
    THROW 51208, 'Completed items shipped once in full', 1;
IF EXISTS(SELECT 1 FROM dbo.InventoryMovement m JOIN dbo.InventoryBatch b ON b.BatchID=m.BatchID JOIN dbo.PurchaseOrderItem p ON p.PurchaseItemID=b.PurchaseItemID JOIN dbo.SalesOrderItem s ON s.SalesItemID=m.SalesItemID JOIN dbo.SalesOrder o ON o.SalesOrderID=s.SalesOrderID WHERE m.MovementType=N'销售出库' AND (p.ProductID<>s.ProductID OR o.CompletedAt IS NULL OR m.OccurredAt<>o.CompletedAt OR CONVERT(date,m.OccurredAt)>=b.ExpiryDate))
    THROW 51209, 'Outgoing product and completion time', 1;
IF EXISTS(SELECT 1 FROM dbo.Customer c OUTER APPLY(SELECT SUM(PointsDelta) Qty FROM dbo.PointsMovement p WHERE p.CustomerID=c.CustomerID) x WHERE c.PointsBalance<>COALESCE(x.Qty,0)) OR EXISTS(SELECT 1 FROM dbo.PointsMovement p JOIN dbo.SalesOrder o ON o.SalesOrderID=p.SalesOrderID JOIN dbo.Customer c ON c.CustomerID=p.CustomerID WHERE o.OrderStatus<>N'已完成' OR o.CompletedAt<>p.OccurredAt OR p.BasedAmount<>o.TotalAmount OR c.IsMember<>1 OR c.JoinedAt>p.OccurredAt)
    THROW 51210, 'Points balances and award basis', 1;
IF EXISTS(SELECT 1 FROM dbo.SalesOrder o JOIN dbo.Customer c ON c.CustomerID=o.CustomerID WHERE o.OrderStatus=N'已完成' AND c.IsMember=1 AND c.JoinedAt<=o.CompletedAt AND o.TotalAmount>=1 AND NOT EXISTS(SELECT 1 FROM dbo.PointsMovement p WHERE p.SalesOrderID=o.SalesOrderID))
    THROW 51211, 'Eligible completed member orders have awards', 1;
IF EXISTS(SELECT 1 FROM dbo.SalesOrderItem i JOIN dbo.SalesOrder o ON o.SalesOrderID=i.SalesOrderID OUTER APPLY(SELECT SUM(CASE WHEN ReservationStatus=N'有效' THEN ReservedQty ELSE 0 END) ActiveQty,SUM(CASE WHEN ReservationStatus=N'已转出库' THEN ReservedQty ELSE 0 END) ShippedQty FROM dbo.InventoryReservation r WHERE r.SalesItemID=i.SalesItemID) x WHERE (o.OrderStatus IN(N'待支付',N'待出库') AND COALESCE(x.ActiveQty,0)<>i.Quantity) OR (o.OrderStatus=N'已完成' AND (COALESCE(x.ShippedQty,0)<>i.Quantity OR COALESCE(x.ActiveQty,0)<>0)) OR (o.OrderStatus=N'已取消' AND COALESCE(x.ActiveQty,0)<>0))
    THROW 51212, 'Reservation lifecycle quantities', 1;
IF EXISTS(SELECT 1 FROM dbo.OrderException e JOIN dbo.SalesOrder o ON o.SalesOrderID=e.SalesOrderID WHERE e.RecordedAt<o.CreatedAt OR (e.BatchID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.InventoryBatch b JOIN dbo.PurchaseOrderItem p ON p.PurchaseItemID=b.PurchaseItemID JOIN dbo.SalesOrderItem s ON s.ProductID=p.ProductID WHERE b.BatchID=e.BatchID AND s.SalesOrderID=e.SalesOrderID)))
    THROW 51213, 'Exception belongs to order product', 1;
CREATE TABLE #Summary(TableName sysname, [RowCount] int, DataHash varchar(64));
IF (SELECT COUNT(*) FROM dbo.[ProductCategory])<>3 THROW 51250, 'Unexpected row count: ProductCategory', 1;
INSERT #Summary SELECT 'ProductCategory', COUNT(*), CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT * FROM dbo.[ProductCategory] ORDER BY [CategoryID] FOR XML PATH('row'),ROOT('rows'),TYPE))),2) FROM dbo.[ProductCategory];
IF (SELECT COUNT(*) FROM dbo.[Product])<>3 THROW 51250, 'Unexpected row count: Product', 1;
INSERT #Summary SELECT 'Product', COUNT(*), CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT * FROM dbo.[Product] ORDER BY [ProductID] FOR XML PATH('row'),ROOT('rows'),TYPE))),2) FROM dbo.[Product];
IF (SELECT COUNT(*) FROM dbo.[Supplier])<>2 THROW 51250, 'Unexpected row count: Supplier', 1;
INSERT #Summary SELECT 'Supplier', COUNT(*), CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT * FROM dbo.[Supplier] ORDER BY [SupplierID] FOR XML PATH('row'),ROOT('rows'),TYPE))),2) FROM dbo.[Supplier];
IF (SELECT COUNT(*) FROM dbo.[Employee])<>3 THROW 51250, 'Unexpected row count: Employee', 1;
INSERT #Summary SELECT 'Employee', COUNT(*), CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT * FROM dbo.[Employee] ORDER BY [EmployeeID] FOR XML PATH('row'),ROOT('rows'),TYPE))),2) FROM dbo.[Employee];
IF (SELECT COUNT(*) FROM dbo.[Customer])<>3 THROW 51250, 'Unexpected row count: Customer', 1;
INSERT #Summary SELECT 'Customer', COUNT(*), CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT * FROM dbo.[Customer] ORDER BY [CustomerID] FOR XML PATH('row'),ROOT('rows'),TYPE))),2) FROM dbo.[Customer];
IF (SELECT COUNT(*) FROM dbo.[PurchaseOrder])<>2 THROW 51250, 'Unexpected row count: PurchaseOrder', 1;
INSERT #Summary SELECT 'PurchaseOrder', COUNT(*), CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT * FROM dbo.[PurchaseOrder] ORDER BY [PurchaseOrderID] FOR XML PATH('row'),ROOT('rows'),TYPE))),2) FROM dbo.[PurchaseOrder];
IF (SELECT COUNT(*) FROM dbo.[PurchaseOrderItem])<>3 THROW 51250, 'Unexpected row count: PurchaseOrderItem', 1;
INSERT #Summary SELECT 'PurchaseOrderItem', COUNT(*), CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT * FROM dbo.[PurchaseOrderItem] ORDER BY [PurchaseItemID] FOR XML PATH('row'),ROOT('rows'),TYPE))),2) FROM dbo.[PurchaseOrderItem];
IF (SELECT COUNT(*) FROM dbo.[InventoryBatch])<>3 THROW 51250, 'Unexpected row count: InventoryBatch', 1;
INSERT #Summary SELECT 'InventoryBatch', COUNT(*), CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT * FROM dbo.[InventoryBatch] ORDER BY [BatchID] FOR XML PATH('row'),ROOT('rows'),TYPE))),2) FROM dbo.[InventoryBatch];
IF (SELECT COUNT(*) FROM dbo.[SalesOrder])<>3 THROW 51250, 'Unexpected row count: SalesOrder', 1;
INSERT #Summary SELECT 'SalesOrder', COUNT(*), CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT * FROM dbo.[SalesOrder] ORDER BY [SalesOrderID] FOR XML PATH('row'),ROOT('rows'),TYPE))),2) FROM dbo.[SalesOrder];
IF (SELECT COUNT(*) FROM dbo.[SalesOrderItem])<>4 THROW 51250, 'Unexpected row count: SalesOrderItem', 1;
INSERT #Summary SELECT 'SalesOrderItem', COUNT(*), CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT * FROM dbo.[SalesOrderItem] ORDER BY [SalesItemID] FOR XML PATH('row'),ROOT('rows'),TYPE))),2) FROM dbo.[SalesOrderItem];
IF (SELECT COUNT(*) FROM dbo.[InventoryReservation])<>4 THROW 51250, 'Unexpected row count: InventoryReservation', 1;
INSERT #Summary SELECT 'InventoryReservation', COUNT(*), CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT * FROM dbo.[InventoryReservation] ORDER BY [ReservationID] FOR XML PATH('row'),ROOT('rows'),TYPE))),2) FROM dbo.[InventoryReservation];
IF (SELECT COUNT(*) FROM dbo.[InventoryMovement])<>6 THROW 51250, 'Unexpected row count: InventoryMovement', 1;
INSERT #Summary SELECT 'InventoryMovement', COUNT(*), CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT * FROM dbo.[InventoryMovement] ORDER BY [MovementID] FOR XML PATH('row'),ROOT('rows'),TYPE))),2) FROM dbo.[InventoryMovement];
IF (SELECT COUNT(*) FROM dbo.[PaymentRecord])<>3 THROW 51250, 'Unexpected row count: PaymentRecord', 1;
INSERT #Summary SELECT 'PaymentRecord', COUNT(*), CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT * FROM dbo.[PaymentRecord] ORDER BY [PaymentID] FOR XML PATH('row'),ROOT('rows'),TYPE))),2) FROM dbo.[PaymentRecord];
IF (SELECT COUNT(*) FROM dbo.[PointsMovement])<>2 THROW 51250, 'Unexpected row count: PointsMovement', 1;
INSERT #Summary SELECT 'PointsMovement', COUNT(*), CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT * FROM dbo.[PointsMovement] ORDER BY [PointsMovementID] FOR XML PATH('row'),ROOT('rows'),TYPE))),2) FROM dbo.[PointsMovement];
IF (SELECT COUNT(*) FROM dbo.[OrderException])<>2 THROW 51250, 'Unexpected row count: OrderException', 1;
INSERT #Summary SELECT 'OrderException', COUNT(*), CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT * FROM dbo.[OrderException] ORDER BY [ExceptionID] FOR XML PATH('row'),ROOT('rows'),TYPE))),2) FROM dbo.[OrderException];
SELECT * FROM #Summary ORDER BY TableName;
SELECT N'VERIFY_PASS' AS Result,COUNT(*) AS TableCount,SUM([RowCount]) AS TotalRows FROM #Summary;
DECLARE @AsOf date='20260918';
SELECT b.BatchID,b.OnHandQty,COALESCE(r.Qty,0) AS ReservedQty,CASE WHEN b.ExpiryDate<=@AsOf OR b.BatchStatus<>N'合格' OR p.SaleStatus<>N'在售' THEN 0 ELSE b.OnHandQty-COALESCE(r.Qty,0) END AS AvailableQty FROM dbo.InventoryBatch b JOIN dbo.PurchaseOrderItem pi ON pi.PurchaseItemID=b.PurchaseItemID JOIN dbo.Product p ON p.ProductID=pi.ProductID OUTER APPLY(SELECT SUM(ReservedQty) Qty FROM dbo.InventoryReservation WHERE BatchID=b.BatchID AND ReservationStatus=N'有效') r ORDER BY b.BatchID;
DROP TABLE #Summary;
