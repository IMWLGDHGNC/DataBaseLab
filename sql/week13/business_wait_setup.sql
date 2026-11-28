-- Prepare separate business fixtures for the commit (C) and rollback (R) rounds.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() NOT LIKE N'DataBaseLab[_]Week6[_]Week10%'
    THROW 51930,'Use a dedicated Week10 sample database.',1;
IF EXISTS(SELECT 1 FROM dbo.Product WHERE ProductID IN ('W13PC','W13PR'))
    THROW 51931,'Use a fresh sample database for the real-business experiment.',1;

BEGIN TRANSACTION;
DECLARE @now datetime2(0)=SYSDATETIME(), @today date=CONVERT(date,GETDATE()),
    @expiry date=DATEADD(day,365,CONVERT(date,GETDATE()));
DECLARE @rounds TABLE(Suffix char(1) PRIMARY KEY);
INSERT @rounds VALUES('C'),('R');

INSERT dbo.Product(ProductID,CategoryID,ProductName,Brand,Specification,SaleUnit,CurrentPrice)
SELECT 'W13P'+r.Suffix,p.CategoryID,N'第13周模拟商品P '+r.Suffix,N'课程样例',N'1袋',N'袋',5
FROM @rounds r CROSS JOIN dbo.Product p WHERE p.ProductID='S00';
INSERT dbo.PurchaseOrder(PurchaseOrderID,SupplierID,CreatedBy,CreatedAt,ApprovedBy,ApprovedAt,OrderStatus)
SELECT o.Prefix+r.Suffix,'SUP00','P00',@now,'P00',@now,N'已批准'
FROM @rounds r CROSS JOIN (VALUES('W13WO'),('W13WP')) o(Prefix);
INSERT dbo.PurchaseOrderItem(PurchaseItemID,PurchaseOrderID,ProductID,OrderedQty,UnitCost)
SELECT i.ItemPrefix+r.Suffix,i.OrderPrefix+r.Suffix,'W13P'+r.Suffix,i.Qty,2
FROM @rounds r CROSS JOIN (VALUES('W13WOI','W13WO',10),('W13WPI','W13WP',5)) i(ItemPrefix,OrderPrefix,Qty);
EXEC dbo.sp_ReceivePurchase 'W13WOIC','W13WBC','W13-OPEN-C',@today,@expiry,'W13WMC','P00',N'模拟期初库存';
EXEC dbo.sp_ReceivePurchase 'W13WOIR','W13WBR','W13-OPEN-R',@today,@expiry,'W13WMR','P00',N'模拟期初库存';

INSERT dbo.SalesOrder(SalesOrderID,CustomerID,CreatedAt,OrderStatus,RecipientName,RecipientPhone,ShippingAddress,TotalAmount)
SELECT 'W13WS'+Suffix,'C00',@now,N'待支付',N'模拟收件人','10000000000',N'模拟地址',10 FROM @rounds;
INSERT dbo.SalesOrderItem(SalesItemID,SalesOrderID,ProductID,Quantity,DealUnitPrice,ListUnitPrice)
SELECT 'W13WSI'+Suffix,'W13WS'+Suffix,'W13P'+Suffix,2,5,5 FROM @rounds;
INSERT dbo.InventoryReservation(ReservationID,SalesItemID,BatchID,ReservedQty,ReservationStatus,ReservedAt)
SELECT 'W13WRS'+Suffix,'W13WSI'+Suffix,'W13WB'+Suffix,2,N'有效',@now FROM @rounds;
INSERT dbo.PaymentRecord(PaymentID,SalesOrderID,MockTransactionNo,Amount,PaymentStatus,ResultAt)
SELECT 'W13WSP'+Suffix,'W13WS'+Suffix,'SIM-W13-WAIT-'+Suffix,10,N'成功',@now FROM @rounds;
UPDATE dbo.SalesOrder SET OrderStatus=N'待出库' WHERE SalesOrderID IN ('W13WSC','W13WSR');
COMMIT;
