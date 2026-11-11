-- Inclusive completion dates. Adjust these two parameters for a reporting run.
DECLARE @StartDate date='2026-09-01',@EndDate date='2026-09-30';
IF @StartDate IS NULL OR @EndDate IS NULL OR @StartDate>@EndDate
    THROW 51801,'Invalid inclusive reporting range.',1;

-- 1. Product revenue ranking: ties share rank without gaps. ProductID only
-- breaks ties in presentation, not in the DENSE_RANK business definition.
SELECT ProductID,ProductName,SalesQty,SalesAmount,OrderCount,
    DENSE_RANK() OVER(ORDER BY SalesAmount DESC) RevenueRank
FROM dbo.fn_SalesSummary(@StartDate,@EndDate)
ORDER BY RevenueRank,ProductID;

-- 2. Every completed order remains one row. Completion timestamp plus unique
-- order ID is a deterministic sequence even when timestamps are equal.
SELECT SalesOrderID,CompletedAt,TotalAmount,
    SUM(TotalAmount) OVER(ORDER BY CompletedAt,SalesOrderID
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) CumulativeAmount
FROM dbo.SalesOrder
WHERE OrderStatus=N'已完成' AND CONVERT(date,CompletedAt) BETWEEN @StartDate AND @EndDate
ORDER BY CompletedAt,SalesOrderID;

-- 3. Trailing three completed orders (not three calendar days): current row and
-- two predecessors. Initial rows use the actual count, with no synthetic zeros.
SELECT SalesOrderID,CompletedAt,TotalAmount,
    COUNT(*) OVER(ORDER BY CompletedAt,SalesOrderID
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) WindowOrders,
    AVG(CONVERT(decimal(18,2),TotalAmount)) OVER(ORDER BY CompletedAt,SalesOrderID
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) MovingAverage3Orders
FROM dbo.SalesOrder
WHERE OrderStatus=N'已完成' AND CONVERT(date,CompletedAt) BETWEEN @StartDate AND @EndDate
ORDER BY CompletedAt,SalesOrderID;
