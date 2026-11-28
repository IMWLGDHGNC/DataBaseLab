-- A1: P goes to 8 in an open order transaction; next run B1.
BEGIN TRANSACTION;
UPDATE week13_lab.Stock WITH(ROWLOCK) SET Qty=Qty-2 WHERE ProductID='P' AND Qty>=2;

-- A2: after observing B1 waiting, finish the order and commit (P ends at 13).
UPDATE week13_lab.Document SET Status='Completed' WHERE DocumentID='ORDER';
COMMIT;

-- A3: alternative to A2 in the reset round; roll back (P ends at 15).
ROLLBACK;
