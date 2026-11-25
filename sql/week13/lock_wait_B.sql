-- B1: after A1, receipt attempts to update P; observe the wait before A2/A3.
BEGIN TRANSACTION;
UPDATE week13_lab.Stock WITH(ROWLOCK) SET Qty=Qty+5 WHERE ProductID='P';

-- B2: after B1 returns, finish receipt document and commit.
UPDATE week13_lab.Document SET Status='Received' WHERE DocumentID='RECEIPT';
COMMIT;
