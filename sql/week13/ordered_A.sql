-- A1: order locks P first; next start B1 and observe its wait.
BEGIN TRANSACTION;
UPDATE week13_lab.Stock WITH(ROWLOCK) SET Qty=Qty-2 WHERE ProductID='P' AND Qty>=2;

-- A2: order can acquire Q, complete the order and commit without waiting on B.
UPDATE week13_lab.Stock WITH(ROWLOCK) SET Qty=Qty-2 WHERE ProductID='Q' AND Qty>=2;
UPDATE week13_lab.Document SET Status='Completed' WHERE DocumentID='ORDER';
COMMIT;
