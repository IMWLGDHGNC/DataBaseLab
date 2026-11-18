-- Run once in a fresh Week12 sample database. The test harness confirms this
-- starting state before each independent case; use a new database to reset.
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;
DECLARE @now datetime2(0)=SYSDATETIME(), @today date=CONVERT(date,GETDATE()),
    @expiry date=DATEADD(day,365,CONVERT(date,GETDATE()));

INSERT dbo.ProductCategory(CategoryID,CategoryName,ParentCategoryID)
VALUES('W12ROOT',N'第12周模拟零食',NULL);
INSERT dbo.ProductCategory(CategoryID,CategoryName,ParentCategoryID)
VALUES('W12A',N'第12周模拟饼干','W12ROOT'),('W12B',N'第12周模拟坚果','W12ROOT');
INSERT dbo.ProductCategory(CategoryID,CategoryName,ParentCategoryID)
VALUES('W12LEAF',N'第12周模拟夹心饼干','W12A');

INSERT dbo.Product(ProductID,CategoryID,ProductName,Brand,Specification,SaleUnit,CurrentPrice)
VALUES('W12P','W12LEAF',N'模拟商品P',N'课程样例',N'1袋',N'袋',5),
      ('W12Q','W12B',N'模拟商品Q',N'课程样例',N'1袋',N'袋',3);

INSERT dbo.PurchaseOrder(PurchaseOrderID,SupplierID,CreatedBy,CreatedAt,ApprovedBy,ApprovedAt,OrderStatus)
VALUES('W12OPENP','SUP00','P00',@now,'P00',@now,N'已批准'),
      ('W12OPENQ','SUP00','P00',@now,'P00',@now,N'已批准'),
      ('W12PUR','SUP00','P00',@now,'P00',@now,N'已批准'),
      ('W12PEND','SUP00','P00',@now,NULL,NULL,N'待审批');
INSERT dbo.PurchaseOrderItem(PurchaseItemID,PurchaseOrderID,ProductID,OrderedQty,UnitCost)
VALUES('W12IP','W12OPENP','W12P',20,2),('W12IQ','W12OPENQ','W12Q',15,1),
      ('W12RI','W12PUR','W12Q',7,1),('W12PI','W12PEND','W12Q',7,1);
EXEC dbo.sp_ReceivePurchase 'W12IP','W12BP','W12-OPEN-P',@today,@expiry,'W12MP','P00',N'模拟期初库存';
EXEC dbo.sp_ReceivePurchase 'W12IQ','W12BQ','W12-OPEN-Q',@today,@expiry,'W12MQ','P00',N'模拟期初库存';

INSERT dbo.SalesOrder(SalesOrderID,CustomerID,CreatedAt,OrderStatus,RecipientName,RecipientPhone,ShippingAddress,TotalAmount)
VALUES('W12SALE','C00',@now,N'待支付',N'模拟收件人','10000000000',N'模拟地址',27);
INSERT dbo.SalesOrderItem(SalesItemID,SalesOrderID,ProductID,Quantity,DealUnitPrice,ListUnitPrice)
VALUES('W12SP','W12SALE','W12P',3,5,5),('W12SQ','W12SALE','W12Q',4,3,3);
INSERT dbo.InventoryReservation(ReservationID,SalesItemID,BatchID,ReservedQty,ReservationStatus,ReservedAt)
VALUES('W12RP','W12SP','W12BP',3,N'有效',@now),('W12RQ','W12SQ','W12BQ',4,N'有效',@now);
INSERT dbo.PaymentRecord(PaymentID,SalesOrderID,MockTransactionNo,Amount,PaymentStatus,ResultAt)
VALUES('W12PAY','W12SALE','SIM-W12-SALE',27,N'成功',@now);
UPDATE dbo.SalesOrder SET OrderStatus=N'待出库' WHERE SalesOrderID='W12SALE';
COMMIT;
