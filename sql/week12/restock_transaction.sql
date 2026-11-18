-- One approved purchase item is received in full. The human-entered OrderedQty
-- remains the source of truth. @Quantity can explicitly confirm that quantity.
CREATE OR ALTER PROCEDURE dbo.sp_ReceivePurchase
    @PurchaseItemID varchar(12), @BatchID varchar(12), @SupplierBatchNo varchar(40),
    @ProductionDate date, @ExpiryDate date, @MovementID varchar(12),
    @OperatorID varchar(12), @Reason nvarchar(200), @Quantity int=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @entry int=@@TRANCOUNT, @oldActor sql_variant=SESSION_CONTEXT(N'OperatorID');
    BEGIN TRY
        IF @entry=0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION ReceivePurchase;
        EXEC dbo.sp_BusinessLock;

        DECLARE @now datetime2(0)=SYSDATETIME(), @today date,
            @orderID varchar(12), @productID varchar(12), @status nvarchar(10), @ordered int;
        SET @today=CONVERT(date,@now);
        IF @ProductionDate IS NULL OR @ExpiryDate IS NULL OR @ProductionDate>@today
            OR @ExpiryDate<=@today OR @ExpiryDate<=@ProductionDate OR @Quantity<=0
            OR NULLIF(LTRIM(RTRIM(@BatchID)),'') IS NULL
            OR NULLIF(LTRIM(RTRIM(@MovementID)),'') IS NULL
            OR NULLIF(LTRIM(RTRIM(@SupplierBatchNo)),'') IS NULL
            OR NULLIF(LTRIM(RTRIM(@Reason)),N'') IS NULL
            THROW 51801,'Invalid receipt dates, quantity or batch information.',1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Employee WHERE EmployeeID=@OperatorID AND ActiveStatus=N'在职')
            THROW 51803,'Active employee required.',1;

        SELECT @orderID=o.PurchaseOrderID,@productID=p.ProductID,@status=o.OrderStatus,@ordered=i.OrderedQty
        FROM dbo.PurchaseOrderItem i WITH(UPDLOCK,HOLDLOCK)
        JOIN dbo.PurchaseOrder o WITH(UPDLOCK,HOLDLOCK) ON o.PurchaseOrderID=i.PurchaseOrderID
        JOIN dbo.Product p ON p.ProductID=i.ProductID
        WHERE i.PurchaseItemID=@PurchaseItemID;
        IF @orderID IS NULL THROW 51802,'Purchase item or product not found.',1;
        IF @status=N'已收货' THROW 51804,'Purchase order has already been received.',1;
        IF @status<>N'已批准' OR (SELECT COUNT_BIG(*) FROM dbo.PurchaseOrderItem WITH(UPDLOCK,HOLDLOCK)
                                 WHERE PurchaseOrderID=@orderID)<>1
            THROW 51804,'An approved single-item purchase order is required.',1;
        SET @Quantity=COALESCE(@Quantity,@ordered);
        IF @Quantity<=0 OR @Quantity<>@ordered
            THROW 51801,'Receipt quantity must be positive and equal the approved quantity.',1;
        IF EXISTS (SELECT 1 FROM dbo.InventoryBatch WITH(UPDLOCK,HOLDLOCK) WHERE PurchaseItemID=@PurchaseItemID)
            THROW 51804,'A receipt batch already exists for this item.',1;

        EXEC sys.sp_set_session_context @key=N'OperatorID',@value=@OperatorID;
        INSERT dbo.InventoryBatch(BatchID,PurchaseItemID,SupplierBatchNo,ProductionDate,ExpiryDate,ReceivedAt,OnHandQty,BatchStatus)
        VALUES(@BatchID,@PurchaseItemID,@SupplierBatchNo,@ProductionDate,@ExpiryDate,@now,@Quantity,N'合格');
        INSERT dbo.InventoryMovement(MovementID,BatchID,MovementType,QuantityDelta,SalesItemID,Reason,OperatorID,OccurredAt)
        VALUES(@MovementID,@BatchID,N'采购入库',@Quantity,NULL,@Reason,@OperatorID,@now);
        UPDATE dbo.PurchaseOrder SET ReceivedBy=@OperatorID,ReceivedAt=@now,OrderStatus=N'已收货'
            WHERE PurchaseOrderID=@orderID AND OrderStatus=N'已批准';
        IF @@ROWCOUNT<>1 THROW 51804,'Purchase order is no longer approved.',1;

        EXEC sys.sp_set_session_context @key=N'OperatorID',@value=@oldActor;
        IF @entry=0 COMMIT;
        SELECT @orderID PurchaseOrderID,@BatchID BatchID,@productID ProductID,@Quantity ReceivedQty,N'已收货' OrderStatus;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key=N'OperatorID',@value=@oldActor;
        IF @entry=0 AND XACT_STATE()<>0 ROLLBACK;
        ELSE IF @entry>0 AND XACT_STATE()=1 ROLLBACK TRANSACTION ReceivePurchase;
        -- The owner of an uncommittable outer transaction must roll it back.
        THROW;
    END CATCH;
END;
GO

-- Isolated sample call after test_data.sql, or see Test-Week12.py for rollback cases.
-- DECLARE @today date=CONVERT(date,SYSDATETIME()), @expiry date=DATEADD(day,365,SYSDATETIME());
-- EXEC dbo.sp_ReceivePurchase 'W12RI','W12BR','W12-RESTOCK',@today,@expiry,'W12MR','P00',N'模拟验收入库',7;
