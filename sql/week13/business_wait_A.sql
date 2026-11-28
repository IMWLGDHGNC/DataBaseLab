-- A1: choose C (commit) or R (rollback), then hold the outer transaction open.
DECLARE @Round char(1)='C';
DECLARE @OrderID varchar(12)='W13WS'+@Round;
BEGIN TRANSACTION;
EXEC dbo.sp_CompleteOrder @OrderID,'P00';

-- A2: after observing B1 blocked, commit round C.
COMMIT;

-- A3: after observing B1 blocked, roll back round R.
ROLLBACK;
