-- Create a real 10-piece batch and two paid test orders. Only A starts reserved.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() NOT LIKE N'DataBaseLab[_]Week6[_]Week10%'
    THROW 51930,'Use a dedicated Week10 sample database.',1;
IF EXISTS(SELECT 1 FROM dbo.Product WHERE ProductID='W13P')
    THROW 51931,'Use a fresh sample database for the real-business experiment.',1;

BEGIN TRANSACTION;
DECLARE @now datetime2(0)=SYSDATETIME(),@today date=CONVERT(date,GETDATE()),
    @expiry date=DATEADD(day,365,CONVERT(date,GETDATE()));
INSERT dbo.Product(ProductID,CategoryID,ProductName,Brand,Specification,SaleUnit,CurrentPrice)
SELECT 'W13P',CategoryID,N'第13周模拟商品P',N'课程样例',N'1袋',N'袋',5
FROM dbo.Product WHERE ProductID='S00';
INSERT dbo.PurchaseOrder(PurchaseOrderID,SupplierID,CreatedBy,CreatedAt,ApprovedBy,ApprovedAt,OrderStatus)
VALUES('W13OPEN','SUP00','P00',@now,'P00',@now,N'已批准');
INSERT dbo.PurchaseOrderItem(PurchaseItemID,PurchaseOrderID,ProductID,OrderedQty,UnitCost)
VALUES('W13OPENI','W13OPEN','W13P',10,2);
EXEC dbo.sp_ReceivePurchase 'W13OPENI','W13BP','W13-OPEN-P',@today,@expiry,'W13OPENM','P00',N'模拟期初库存';

INSERT dbo.SalesOrder(SalesOrderID,CustomerID,CreatedAt,OrderStatus,RecipientName,RecipientPhone,ShippingAddress,TotalAmount)
VALUES('W13OA','C00',@now,N'待支付',N'模拟收件人','10000000000',N'模拟地址',30),
      ('W13OB','C00',@now,N'待支付',N'模拟收件人','10000000000',N'模拟地址',30);
INSERT dbo.SalesOrderItem(SalesItemID,SalesOrderID,ProductID,Quantity,DealUnitPrice,ListUnitPrice)
VALUES('W13IA','W13OA','W13P',6,5,5),('W13IB','W13OB','W13P',6,5,5);
INSERT dbo.InventoryReservation(ReservationID,SalesItemID,BatchID,ReservedQty,ReservationStatus,ReservedAt)
VALUES('W13RA','W13IA','W13BP',6,N'有效',@now);
INSERT dbo.PaymentRecord(PaymentID,SalesOrderID,MockTransactionNo,Amount,PaymentStatus,ResultAt)
VALUES('W13PA','W13OA','SIM-W13-A',30,N'成功',@now),('W13PB','W13OB','SIM-W13-B',30,N'成功',@now);
UPDATE dbo.SalesOrder SET OrderStatus=N'待出库' WHERE SalesOrderID IN ('W13OA','W13OB');
COMMIT;
