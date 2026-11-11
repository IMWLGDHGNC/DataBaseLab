-- Writes use the same transaction-owned lock as v1.0 Web writes. Standalone
-- calls commit; calls inside a transaction use a savepoint and never commit it.
CREATE OR ALTER PROCEDURE dbo.sp_BusinessLock
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @result int;
    EXEC @result=sys.sp_getapplock @Resource=N'DataBaseLab.WebWrite',
        @LockMode='Exclusive',@LockOwner='Transaction',@DbPrincipal='public',@LockTimeout=10000;
    IF @result<0 THROW 51701,'Business transaction lock unavailable.',1;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_SalesStatistics @StartDate date,@EndDate date
AS
BEGIN
    SET NOCOUNT ON;
    IF @StartDate IS NULL OR @EndDate IS NULL OR @StartDate>@EndDate
        THROW 51801,'Invalid inclusive date range.',1;
    SELECT COUNT_BIG(*) OrderCount,
        COALESCE(SUM(TotalAmount),0) SalesAmount,
        COALESCE((SELECT SUM(SalesQty) FROM dbo.fn_SalesSummary(@StartDate,@EndDate)),0) SalesQty
    FROM dbo.SalesOrder WHERE OrderStatus=N'已完成'
        AND CONVERT(date,CompletedAt) BETWEEN @StartDate AND @EndDate;
    SELECT * FROM dbo.fn_SalesSummary(@StartDate,@EndDate) ORDER BY ProductID;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_AdjustInventory
    @ProductID varchar(12),@Delta int,@Reason nvarchar(200),@OperatorID varchar(12),
    @BatchID varchar(12)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @ProductID IS NULL OR @Delta IS NULL OR @Delta=0 OR ABS(CONVERT(bigint,@Delta))>100000
        OR NULLIF(LTRIM(RTRIM(@Reason)),N'') IS NULL
        THROW 51801,'Invalid inventory adjustment input.',1;
    DECLARE @entry int=@@TRANCOUNT,@oldActor sql_variant=SESSION_CONTEXT(N'OperatorID');
    BEGIN TRY
        IF @entry=0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION AdjustInventory;
        EXEC dbo.sp_BusinessLock;
        IF NOT EXISTS(SELECT 1 FROM dbo.Product WHERE ProductID=@ProductID)
            THROW 51802,'Product not found.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.Employee WHERE EmployeeID=@OperatorID AND ActiveStatus=N'在职')
            THROW 51803,'Active employee required.',1;
        IF @BatchID IS NULL
        BEGIN
            -- A product can have several expiry/cost batches. Never silently
            -- adjust an arbitrary batch; require its identifier when ambiguous.
            IF (SELECT COUNT(*) FROM dbo.InventoryBatch b JOIN dbo.PurchaseOrderItem i
                ON i.PurchaseItemID=b.PurchaseItemID WHERE i.ProductID=@ProductID)<>1
                THROW 51804,'Specify one existing batch for this product.',1;
            SELECT @BatchID=b.BatchID FROM dbo.InventoryBatch b JOIN dbo.PurchaseOrderItem i
                ON i.PurchaseItemID=b.PurchaseItemID WHERE i.ProductID=@ProductID;
        END;
        DECLARE @before int,@reserved bigint;
        SELECT @before=b.OnHandQty FROM dbo.InventoryBatch b WITH(UPDLOCK,HOLDLOCK)
            JOIN dbo.PurchaseOrderItem i ON i.PurchaseItemID=b.PurchaseItemID
            WHERE b.BatchID=@BatchID AND i.ProductID=@ProductID;
        IF @before IS NULL THROW 51802,'Batch does not belong to product.',1;
        SELECT @reserved=COALESCE(SUM(CONVERT(bigint,ReservedQty)),0) FROM dbo.InventoryReservation
            WHERE BatchID=@BatchID AND ReservationStatus=N'有效';
        IF CONVERT(bigint,@before)+@Delta<@reserved OR CONVERT(bigint,@before)+@Delta>2147483647
            THROW 51804,'Stock would be below reservations or exceed integer range.',1;
        EXEC sys.sp_set_session_context @key=N'OperatorID',@value=@OperatorID;
        UPDATE dbo.InventoryBatch SET OnHandQty=OnHandQty+@Delta WHERE BatchID=@BatchID;
        INSERT dbo.InventoryMovement(MovementID,BatchID,MovementType,QuantityDelta,SalesItemID,Reason,OperatorID,OccurredAt)
        VALUES('IM'+LEFT(REPLACE(CONVERT(varchar(36),NEWID()),'-',''),10),@BatchID,N'盘点调整',@Delta,NULL,@Reason,@OperatorID,SYSDATETIME());
        EXEC sys.sp_set_session_context @key=N'OperatorID',@value=@oldActor;
        IF @entry=0 COMMIT;
        SELECT @BatchID BatchID,@before BeforeQty,@before+@Delta AfterQty,@Delta Delta;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key=N'OperatorID',@value=@oldActor;
        IF XACT_STATE()=-1 OR (@entry=0 AND XACT_STATE()=1) ROLLBACK;
        ELSE IF XACT_STATE()=1 ROLLBACK TRANSACTION AdjustInventory;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_PriceOrder @OrderID varchar(12),@Initialize bit=0
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @entry int=@@TRANCOUNT;
    BEGIN TRY
        IF @entry=0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION PriceOrder;
        EXEC dbo.sp_BusinessLock;
        DECLARE @customer varchar(12),@rate decimal(5,4),@total decimal(38,2),@gross decimal(38,2);
        SELECT @customer=CustomerID,@rate=DiscountRate FROM dbo.SalesOrder WITH(UPDLOCK,HOLDLOCK)
            WHERE SalesOrderID=@OrderID AND OrderStatus=N'待支付';
        IF @customer IS NULL THROW 51804,'Editable order required.',1;
        IF @Initialize IS NULL THROW 51801,'Initialize cannot be NULL.',1;
        IF @Initialize=1 SET @rate=dbo.fn_DiscountRate(@customer);
        IF @rate IS NULL THROW 51802,'Active customer required.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.SalesOrderItem WHERE SalesOrderID=@OrderID)
            THROW 51804,'Empty order cannot be priced.',1;
        UPDATE dbo.SalesOrderItem SET ListUnitPrice=COALESCE(ListUnitPrice,DealUnitPrice),
            DealUnitPrice=COALESCE(ListUnitPrice,DealUnitPrice)
                -dbo.fn_DiscountAmount(COALESCE(ListUnitPrice,DealUnitPrice),@rate)
            WHERE SalesOrderID=@OrderID;
        SELECT @total=SUM(CONVERT(decimal(18,2),Quantity)*DealUnitPrice),
            @gross=SUM(CONVERT(decimal(18,2),Quantity)*ListUnitPrice)
            FROM dbo.SalesOrderItem WHERE SalesOrderID=@OrderID;
        IF @total<=0 OR @total>99999999.99 OR @gross-@total>99999999.99
            THROW 51801,'Order amount outside allowed range.',1;
        UPDATE dbo.SalesOrder SET TotalAmount=@total,DiscountRate=@rate,DiscountAmount=@gross-@total
            WHERE SalesOrderID=@OrderID;
        IF @entry=0 COMMIT;
        SELECT CONVERT(decimal(10,2),@total) TotalAmount,@rate DiscountRate,
            CONVERT(decimal(10,2),@gross-@total) DiscountAmount;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()=-1 OR (@entry=0 AND XACT_STATE()=1) ROLLBACK;
        ELSE IF XACT_STATE()=1 ROLLBACK TRANSACTION PriceOrder;
        THROW;
    END CATCH;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_SelectReplenishment @ProductID varchar(12),@TargetQty int=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @qty bigint=dbo.fn_ReplenishmentQty(@ProductID,@TargetQty);
    IF @qty IS NULL THROW 51801,'Unknown product or invalid target.',1;
    SELECT @ProductID ProductID,@qty ReplenishmentQty;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_CompleteOrder @OrderID varchar(12),@OperatorID varchar(12)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @entry int=@@TRANCOUNT,@oldActor sql_variant=SESSION_CONTEXT(N'OperatorID');
    BEGIN TRY
        IF @entry=0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION CompleteOrder;
        EXEC dbo.sp_BusinessLock;
        DECLARE @customer varchar(12),@amount decimal(10,2),@member bit,@now datetime2(0)=SYSDATETIME();
        IF NOT EXISTS(SELECT 1 FROM dbo.Employee WHERE EmployeeID=@OperatorID AND ActiveStatus=N'在职')
            THROW 51803,'Active employee required.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.SalesOrder WHERE SalesOrderID=@OrderID)
            THROW 51802,'Order not found.',1;
        SELECT @customer=CustomerID,@amount=TotalAmount FROM dbo.SalesOrder WITH(UPDLOCK,HOLDLOCK)
            WHERE SalesOrderID=@OrderID AND OrderStatus=N'待出库';
        IF @customer IS NULL THROW 51804,'Paid uncompleted order required.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.PaymentRecord WHERE SalesOrderID=@OrderID
            AND PaymentStatus=N'成功' AND Amount=@amount)
            THROW 51804,'Successful payment must equal order amount.',1;
        IF NOT EXISTS(SELECT 1 FROM dbo.SalesOrderItem WHERE SalesOrderID=@OrderID)
            OR @amount<>(SELECT SUM(CONVERT(decimal(18,2),Quantity)*DealUnitPrice)
                FROM dbo.SalesOrderItem WHERE SalesOrderID=@OrderID)
            THROW 51804,'Order items or amount are inconsistent.',1;
        IF EXISTS(SELECT 1 FROM dbo.SalesOrderItem i OUTER APPLY
            (SELECT SUM(CONVERT(bigint,r.ReservedQty)) Qty FROM dbo.InventoryReservation r
             WHERE r.SalesItemID=i.SalesItemID AND r.ReservationStatus=N'有效') x
            WHERE i.SalesOrderID=@OrderID AND (COALESCE(x.Qty,0)<>i.Quantity OR i.Quantity<=0))
            THROW 51804,'Item reservations must exactly match quantity.',1;
        IF EXISTS(SELECT 1 FROM dbo.InventoryReservation r JOIN dbo.SalesOrderItem i ON i.SalesItemID=r.SalesItemID
            JOIN dbo.InventoryBatch b WITH(UPDLOCK,HOLDLOCK) ON b.BatchID=r.BatchID
            JOIN dbo.PurchaseOrderItem p ON p.PurchaseItemID=b.PurchaseItemID
            WHERE i.SalesOrderID=@OrderID AND r.ReservationStatus=N'有效'
            AND (p.ProductID<>i.ProductID OR b.BatchStatus<>N'合格' OR b.ExpiryDate<=CONVERT(date,@now)
              OR b.OnHandQty<(SELECT SUM(CONVERT(bigint,ReservedQty)) FROM dbo.InventoryReservation
                   WHERE BatchID=b.BatchID AND ReservationStatus=N'有效')))
            THROW 51804,'Reserved batch is unavailable or overcommitted.',1;
        DECLARE @ship TABLE(ReservationID varchar(12),BatchID varchar(12),SalesItemID varchar(12),Qty int);
        INSERT @ship SELECT r.ReservationID,r.BatchID,r.SalesItemID,r.ReservedQty
            FROM dbo.InventoryReservation r JOIN dbo.SalesOrderItem i ON i.SalesItemID=r.SalesItemID
            WHERE i.SalesOrderID=@OrderID AND r.ReservationStatus=N'有效';
        EXEC sys.sp_set_session_context @key=N'OperatorID',@value=@OperatorID;
        UPDATE r SET ReservationStatus=N'已转出库',EndedAt=@now
            FROM dbo.InventoryReservation r JOIN @ship s ON s.ReservationID=r.ReservationID;
        UPDATE b SET OnHandQty=b.OnHandQty-s.Qty FROM dbo.InventoryBatch b
            JOIN (SELECT BatchID,SUM(Qty) Qty FROM @ship GROUP BY BatchID) s ON s.BatchID=b.BatchID;
        INSERT dbo.InventoryMovement(MovementID,BatchID,MovementType,QuantityDelta,SalesItemID,Reason,OperatorID,OccurredAt)
            SELECT 'IM'+LEFT(REPLACE(CONVERT(varchar(36),NEWID()),'-',''),10),BatchID,N'销售出库',-Qty,SalesItemID,
                N'订单确认出库',@OperatorID,@now FROM @ship;
        UPDATE dbo.SalesOrder SET OrderStatus=N'已完成',CompletedAt=@now WHERE SalesOrderID=@OrderID;
        SELECT @member=IsMember FROM dbo.Customer WITH(UPDLOCK,HOLDLOCK) WHERE CustomerID=@customer;
        IF @member=1 AND FLOOR(@amount)>0
        BEGIN
            INSERT dbo.PointsMovement(PointsMovementID,CustomerID,SalesOrderID,PointsDelta,BasedAmount,Reason,OccurredAt)
                VALUES('PM'+LEFT(REPLACE(CONVERT(varchar(36),NEWID()),'-',''),10),@customer,@OrderID,
                    FLOOR(@amount),@amount,N'订单完成赠分',@now);
            UPDATE dbo.Customer SET PointsBalance=PointsBalance+CONVERT(int,FLOOR(@amount)) WHERE CustomerID=@customer;
        END;
        EXEC sys.sp_set_session_context @key=N'OperatorID',@value=@oldActor;
        IF @entry=0 COMMIT;
        SELECT @OrderID OrderID,N'已完成' OrderStatus;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key=N'OperatorID',@value=@oldActor;
        IF XACT_STATE()=-1 OR (@entry=0 AND XACT_STATE()=1) ROLLBACK;
        ELSE IF XACT_STATE()=1 ROLLBACK TRANSACTION CompleteOrder;
        THROW;
    END CATCH;
END;
GO
