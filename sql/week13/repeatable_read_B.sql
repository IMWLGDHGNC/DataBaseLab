-- B1: receipt commits after A1; in round 2 it waits until A4.
BEGIN TRANSACTION;
UPDATE week13_lab.Stock WITH(ROWLOCK) SET Qty=Qty+5 WHERE ProductID='P';
UPDATE week13_lab.Document SET Status='Received' WHERE DocumentID='RECEIPT';
COMMIT;
