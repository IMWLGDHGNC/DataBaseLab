-- A1: order holds P, then run B1.
BEGIN TRANSACTION;
UPDATE week13_lab.Stock WITH(ROWLOCK) SET Qty=Qty-2 WHERE ProductID='P' AND Qty>=2;

-- A2: order requests Q, then observe A blocked by B before running B2.
UPDATE week13_lab.Stock WITH(ROWLOCK) SET Qty=Qty-2 WHERE ProductID='Q' AND Qty>=2;

-- A3: when A2 returns, finish the order and commit.
UPDATE week13_lab.Document SET Status='Completed' WHERE DocumentID='ORDER';
COMMIT;
