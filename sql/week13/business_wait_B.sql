-- B1: use the same round as A1; receive five units into a new batch.
DECLARE @Round char(1)='C';
DECLARE @ItemID varchar(12)='W13WPI'+@Round, @BatchID varchar(12)='W13WRC'+@Round,
    @MovementID varchar(12)='W13WRM'+@Round, @SupplierBatchNo varchar(40)='W13-WAIT-'+@Round,
    @today date=CONVERT(date,GETDATE()), @expiry date=DATEADD(day,365,GETDATE());
EXEC dbo.sp_ReceivePurchase @ItemID,@BatchID,@SupplierBatchNo,@today,@expiry,@MovementID,'P00',N'模拟补货验收',5;
