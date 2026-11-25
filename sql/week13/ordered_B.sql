-- B1: receipt also starts with P and waits for A2 without holding Q.
BEGIN TRANSACTION;
UPDATE week13_lab.Stock WITH(ROWLOCK) SET Qty=Qty+5 WHERE ProductID='P';

-- B2: only after B1 returns, acquire Q and finish the receipt.
UPDATE week13_lab.Stock WITH(ROWLOCK) SET Qty=Qty+5 WHERE ProductID='Q';
UPDATE week13_lab.Document SET Status='Received' WHERE DocumentID='RECEIPT';
COMMIT;
