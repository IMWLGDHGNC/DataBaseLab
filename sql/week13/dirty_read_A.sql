-- A1: uncommitted receipt updates P from 10 to 15.
BEGIN TRANSACTION;
UPDATE week13_lab.Stock WITH(ROWLOCK) SET Qty=Qty+5 WHERE ProductID='P';
UPDATE week13_lab.Document SET Status='Received' WHERE DocumentID='RECEIPT';

-- A2: after B1 returns 15, B2 waits/returns 10, or B3 waits, roll back.
ROLLBACK;
