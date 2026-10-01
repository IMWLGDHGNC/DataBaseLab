SET NOCOUNT ON;
GO
CREATE OR ALTER VIEW dbo.vw_OrderDetail AS
SELECT o.SalesOrderID, o.OrderStatus, o.CreatedAt, c.CustomerID,
       c.CustomerName, i.SalesItemID, p.ProductID, p.ProductName,
       i.Quantity, i.DealUnitPrice,
       CAST(i.Quantity*i.DealUnitPrice AS decimal(12,2)) AS LineAmount
FROM dbo.SalesOrder AS o
JOIN dbo.Customer AS c ON c.CustomerID=o.CustomerID
LEFT JOIN dbo.SalesOrderItem AS i ON i.SalesOrderID=o.SalesOrderID
LEFT JOIN dbo.Product AS p ON p.ProductID=i.ProductID;
GO
CREATE OR ALTER VIEW dbo.vw_ProductSales AS
SELECT p.ProductID, p.ProductName,
       COALESCE(SUM(CASE WHEN o.OrderStatus=N'已完成' THEN i.Quantity ELSE 0 END),0) AS SoldQty,
       CAST(COALESCE(SUM(CASE WHEN o.OrderStatus=N'已完成'
           THEN i.Quantity*i.DealUnitPrice ELSE 0 END),0) AS decimal(12,2)) AS SalesAmount
FROM dbo.Product AS p
LEFT JOIN dbo.SalesOrderItem AS i ON i.ProductID=p.ProductID
LEFT JOIN dbo.SalesOrder AS o ON o.SalesOrderID=i.SalesOrderID
GROUP BY p.ProductID,p.ProductName;
GO
CREATE OR ALTER VIEW dbo.vw_InventoryStatus AS
SELECT b.BatchID,p.ProductID,p.ProductName,b.ExpiryDate,b.BatchStatus,b.OnHandQty,
       COALESCE(r.ReservedQty,0) AS ReservedQty,
       CASE WHEN b.ExpiryDate<=CONVERT(date,GETDATE()) OR b.BatchStatus<>N'合格'
                      OR p.SaleStatus<>N'在售' THEN 0
            ELSE b.OnHandQty-COALESCE(r.ReservedQty,0) END AS AvailableQty
FROM dbo.InventoryBatch AS b
JOIN dbo.PurchaseOrderItem AS pi ON pi.PurchaseItemID=b.PurchaseItemID
JOIN dbo.Product AS p ON p.ProductID=pi.ProductID
OUTER APPLY (SELECT SUM(ReservedQty) AS ReservedQty
             FROM dbo.InventoryReservation
             WHERE BatchID=b.BatchID AND ReservationStatus=N'有效') AS r;
GO
SET NOCOUNT ON;
SELECT * FROM dbo.vw_OrderDetail ORDER BY SalesOrderID,SalesItemID;
SELECT * FROM dbo.vw_ProductSales ORDER BY ProductID;
SELECT * FROM dbo.vw_InventoryStatus ORDER BY BatchID;
IF (SELECT COUNT(*) FROM dbo.vw_OrderDetail)<>4
    THROW 51410,'Expected four order detail rows.',1;
IF (SELECT SUM(SalesAmount) FROM dbo.vw_ProductSales)<>64.50
    THROW 51411,'Completed sales view total mismatch.',1;
IF (SELECT AvailableQty FROM dbo.vw_InventoryStatus WHERE BatchID='B01')<>0
    THROW 51412,'Expired batch must be unavailable.',1;
-- A valid order without lines must still appear in the detail view.
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.SalesOrder(SalesOrderID,CustomerID,CreatedAt,RecipientName,
                          RecipientPhone,ShippingAddress,TotalAmount)
    VALUES('W4EMPTY','C02','20260918 10:00:00',N'视图测试顾客',
           '13000000000',N'视图测试地址',1.00);
    IF (SELECT COUNT(*) FROM dbo.vw_OrderDetail WHERE SalesOrderID='W4EMPTY')<>1
        THROW 51413,'Order detail view omitted an order without lines.',1;
    IF EXISTS(SELECT 1 FROM dbo.vw_OrderDetail
              WHERE SalesOrderID='W4EMPTY' AND SalesItemID IS NOT NULL)
        THROW 51414,'Order detail view invented an order line.',1;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
SELECT 'VIEW_PASS' AS Result;
