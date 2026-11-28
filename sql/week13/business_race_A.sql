-- A1: run the real procedure; hold the outer transaction open at P=4.
BEGIN TRANSACTION;
EXEC dbo.sp_CompleteOrder 'W13OA','P00';

-- A2: observe B1 waiting on the transaction-owned application lock, then commit.
COMMIT;
