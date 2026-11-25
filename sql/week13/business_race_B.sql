-- B1: request the same application lock before staging the competing reservation.
-- After A commits, the procedure must reject it and the caller must roll it back.
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.sp_BusinessLock;
    INSERT dbo.InventoryReservation(ReservationID,SalesItemID,BatchID,ReservedQty,ReservationStatus,ReservedAt)
    VALUES('W13RB','W13IB','W13BP',6,N'有效',SYSDATETIME());
    EXEC dbo.sp_CompleteOrder 'W13OB','P00';
    COMMIT;
    SELECT 0 AS ErrorNumber, @@TRANCOUNT AS TranCount, XACT_STATE() AS XactState;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK;
    SELECT ERROR_NUMBER() AS ErrorNumber, ERROR_MESSAGE() AS ErrorMessage,
           @@TRANCOUNT AS TranCount, XACT_STATE() AS XactState;
END CATCH;
