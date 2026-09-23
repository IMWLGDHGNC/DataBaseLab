-- Week 4 queries use historical deal prices, not today's product prices.
SET NOCOUNT ON;

-- Q1: Every order line, including an unfinished order; LEFT JOIN retains unpaid orders.
SELECT o.SalesOrderID, o.OrderStatus, c.CustomerName, c.IsMember,
       i.SalesItemID, p.ProductName, i.Quantity, i.DealUnitPrice,
       CAST(i.Quantity * i.DealUnitPrice AS decimal(12,2)) AS LineAmount
FROM dbo.SalesOrder AS o
JOIN dbo.Customer AS c ON c.CustomerID = o.CustomerID
LEFT JOIN dbo.SalesOrderItem AS i ON i.SalesOrderID = o.SalesOrderID
LEFT JOIN dbo.Product AS p ON p.ProductID = i.ProductID
ORDER BY o.SalesOrderID, i.SalesItemID;

-- Q2: Completed sales only. ST02 is paid but not shipped, so it is excluded.
SELECT p.ProductID, p.ProductName, SUM(i.Quantity) AS SoldQty,
       CAST(SUM(i.Quantity * i.DealUnitPrice) AS decimal(12,2)) AS SalesAmount
FROM dbo.Product AS p
JOIN dbo.SalesOrderItem AS i ON i.ProductID = p.ProductID
JOIN dbo.SalesOrder AS o ON o.SalesOrderID = i.SalesOrderID
WHERE o.OrderStatus = N'已完成'
GROUP BY p.ProductID, p.ProductName
HAVING SUM(i.Quantity) > 0
ORDER BY SalesAmount DESC, p.ProductID;

-- Q3: Member spending on completed orders; LEFT JOIN keeps members with zero sales.
SELECT c.CustomerID, c.CustomerName, c.PointsBalance,
       COUNT(o.SalesOrderID) AS CompletedOrders,
       CAST(COALESCE(SUM(o.TotalAmount),0) AS decimal(12,2)) AS SpentAmount
FROM dbo.Customer AS c
LEFT JOIN dbo.SalesOrder AS o ON o.CustomerID = c.CustomerID
    AND o.OrderStatus = N'已完成'
WHERE c.IsMember = 1
GROUP BY c.CustomerID, c.CustomerName, c.PointsBalance
ORDER BY c.CustomerID;

-- Q4: Products sold above the completed-order average quantity (subquery).
SELECT p.ProductID, p.ProductName, SUM(i.Quantity) AS SoldQty
FROM dbo.Product AS p
JOIN dbo.SalesOrderItem AS i ON i.ProductID = p.ProductID
JOIN dbo.SalesOrder AS o ON o.SalesOrderID = i.SalesOrderID
WHERE o.OrderStatus = N'已完成'
GROUP BY p.ProductID, p.ProductName
HAVING SUM(i.Quantity) > (
    SELECT AVG(CAST(x.ProductQty AS decimal(12,2)))
    FROM (SELECT SUM(i2.Quantity) AS ProductQty
          FROM dbo.SalesOrderItem AS i2
          JOIN dbo.SalesOrder AS o2 ON o2.SalesOrderID = i2.SalesOrderID
          WHERE o2.OrderStatus = N'已完成'
          GROUP BY i2.ProductID) AS x)
ORDER BY p.ProductID;

-- Q5: Batch availability at a fixed demonstration date. An expired batch is not sellable.
DECLARE @AsOf date = '20260918';
SELECT b.BatchID, p.ProductName, b.OnHandQty,
       COALESCE(r.ReservedQty,0) AS ReservedQty,
       CASE WHEN b.ExpiryDate <= @AsOf OR b.BatchStatus <> N'合格'
                      OR p.SaleStatus <> N'在售' THEN 0
            ELSE b.OnHandQty - COALESCE(r.ReservedQty,0) END AS AvailableQty
FROM dbo.InventoryBatch AS b
JOIN dbo.PurchaseOrderItem AS pi ON pi.PurchaseItemID = b.PurchaseItemID
JOIN dbo.Product AS p ON p.ProductID = pi.ProductID
OUTER APPLY (SELECT SUM(ReservedQty) AS ReservedQty
             FROM dbo.InventoryReservation
             WHERE BatchID = b.BatchID AND ReservationStatus = N'有效') AS r
ORDER BY b.BatchID;

-- The seed's key totals make a syntactically correct but wrong business query fail.
IF (SELECT SUM(i.Quantity) FROM dbo.SalesOrderItem AS i
    JOIN dbo.SalesOrder AS o ON o.SalesOrderID=i.SalesOrderID
    WHERE o.OrderStatus=N'已完成') <> 15
    THROW 51400, 'Expected 15 completed sale units.', 1;
IF (SELECT SUM(o.TotalAmount) FROM dbo.SalesOrder AS o
    WHERE o.OrderStatus=N'已完成') <> 64.50
    THROW 51401, 'Expected 64.50 completed revenue.', 1;
IF (SELECT COUNT(*) FROM dbo.SalesOrder WHERE OrderStatus=N'待出库') <> 1
    THROW 51402, 'Expected one paid, unfinished order.', 1;
SELECT 'QUERY_PASS' AS Result;
