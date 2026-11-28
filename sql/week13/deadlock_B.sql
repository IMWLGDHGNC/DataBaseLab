-- B1: hold Q first. Lower priority makes the victim reproducible.
SET DEADLOCK_PRIORITY LOW;
BEGIN TRANSACTION;
UPDATE week13_lab.Stock WITH(ROWLOCK) SET Qty=Qty+5 WHERE ProductID='Q';

-- B2: request P. The server rolls back B, and the order can proceed.
BEGIN TRY
    UPDATE week13_lab.Stock WITH(ROWLOCK) SET Qty=Qty+5 WHERE ProductID='P';
    UPDATE week13_lab.Document SET Status='Received' WHERE DocumentID='RECEIPT';
    COMMIT;
    SELECT 0 AS ErrorNumber, @@TRANCOUNT AS TranCount, XACT_STATE() AS XactState;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER()<>1205 THROW;
    DECLARE @error int=ERROR_NUMBER(), @beforeCleanup int=XACT_STATE();
    IF @@TRANCOUNT>0 ROLLBACK;
    SELECT @error AS ErrorNumber, @beforeCleanup AS BeforeCleanup,
           @@TRANCOUNT AS TranCount, XACT_STATE() AS XactState;
END CATCH;
