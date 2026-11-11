-- Functions query/compute values; invalid scalar input returns NULL, invalid
-- date ranges return an empty table. Procedures turn these into explicit errors.
CREATE OR ALTER FUNCTION dbo.fn_ReplenishmentQty(@ProductID varchar(12), @TargetQty int)
RETURNS bigint
AS
BEGIN
    DECLARE @target int, @available bigint;
    SELECT @target=COALESCE(@TargetQty,ReorderLevel) FROM dbo.Product WHERE ProductID=@ProductID;
    IF @target IS NULL OR @target<0 RETURN NULL;
    SELECT @available=COALESCE(SUM(CONVERT(bigint,b.OnHandQty)-COALESCE(r.Qty,0)),0)
    FROM dbo.InventoryBatch b JOIN dbo.PurchaseOrderItem i ON i.PurchaseItemID=b.PurchaseItemID
    OUTER APPLY (SELECT SUM(CONVERT(bigint,ReservedQty)) Qty FROM dbo.InventoryReservation
        WHERE BatchID=b.BatchID AND ReservationStatus=N'有效') r
    WHERE i.ProductID=@ProductID AND b.BatchStatus=N'合格' AND b.ExpiryDate>CONVERT(date,GETDATE());
    RETURN CASE WHEN @available>=@target THEN 0 ELSE CONVERT(bigint,@target)-@available END;
END;
GO
CREATE OR ALTER FUNCTION dbo.fn_DiscountRate(@CustomerID varchar(12))
RETURNS decimal(5,4)
AS
BEGIN
    DECLARE @rate decimal(5,4);
    SELECT @rate=CASE WHEN IsMember=1 THEN 0.05 ELSE 0 END
    FROM dbo.Customer WHERE CustomerID=@CustomerID AND ActiveStatus=N'正常';
    RETURN @rate;
END;
GO
CREATE OR ALTER FUNCTION dbo.fn_DiscountAmount(@Amount decimal(18,2), @Rate decimal(9,6))
RETURNS decimal(18,2)
AS
BEGIN
    IF @Amount IS NULL OR @Amount<0 OR @Rate IS NULL OR @Rate<0 OR @Rate>=1 RETURN NULL;
    RETURN CONVERT(decimal(18,2),ROUND(@Amount*@Rate,2));
END;
GO
CREATE OR ALTER FUNCTION dbo.fn_SalesSummary(@StartDate date,@EndDate date)
RETURNS TABLE
AS RETURN
(
    SELECT p.ProductID,p.ProductName,SUM(CONVERT(bigint,i.Quantity)) SalesQty,
        SUM(CONVERT(decimal(18,2),i.Quantity)*i.DealUnitPrice) SalesAmount,
        COUNT(DISTINCT o.SalesOrderID) OrderCount
    FROM dbo.SalesOrder o JOIN dbo.SalesOrderItem i ON i.SalesOrderID=o.SalesOrderID
    JOIN dbo.Product p ON p.ProductID=i.ProductID
    WHERE @StartDate<=@EndDate AND CONVERT(date,o.CompletedAt) BETWEEN @StartDate AND @EndDate
        AND o.OrderStatus=N'已完成'
    GROUP BY p.ProductID,p.ProductName
);
GO
