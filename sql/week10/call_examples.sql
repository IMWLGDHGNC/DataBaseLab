-- Read calls are safe to repeat. Run all writing examples only in the dedicated
-- Run-Week10.ps1 sample database; these demonstrations roll back their writes.
EXEC dbo.sp_SalesStatistics @StartDate='2026-09-16',@EndDate='2026-09-16';
EXEC dbo.sp_SalesStatistics @StartDate='1900-01-01',@EndDate='1900-01-01';
EXEC dbo.sp_SelectReplenishment @ProductID='S01',@TargetQty=300;
SELECT dbo.fn_ReplenishmentQty('S01',300) ReplenishmentQty,
    dbo.fn_DiscountRate('C00') MemberDiscount,
    dbo.fn_DiscountAmount(100,0.05) DiscountAmount;
SELECT * FROM dbo.fn_SalesSummary('2026-09-16','2026-09-16');
BEGIN TRANSACTION;
EXEC dbo.sp_AdjustInventory @ProductID='S01',@Delta=5,@Reason=N'模拟调用增加',@OperatorID='P00',@BatchID='B00';
EXEC dbo.sp_AdjustInventory @ProductID='S01',@Delta=-5,@Reason=N'模拟调用减少',@OperatorID='P00',@BatchID='B00';
ROLLBACK;
BEGIN TRY
    EXEC dbo.sp_AdjustInventory 'S01',0,N'非法零数量','P00','B00';
    THROW 59001,'Zero adjustment was unexpectedly accepted.',1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER()<>51801 THROW;
    SELECT ERROR_NUMBER() ErrorNumber,ERROR_MESSAGE() ExpectedError;
END CATCH;
-- Parameterized normal completion, repeat completion, failed completion and
-- per-table rollback digests are exercised by tests/Test-Week10.py fixtures.
