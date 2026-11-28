-- A1: round 1, read P=10 under READ COMMITTED. Wait for B1 to commit.
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRANSACTION;
SELECT Qty, (SELECT transaction_isolation_level FROM sys.dm_exec_sessions WHERE session_id=@@SPID) AS IsolationLevel
FROM week13_lab.Stock WITH(ROWLOCK) WHERE ProductID='P';

-- A2: round 1, read P=15 in the same transaction and commit.
SELECT Qty, (SELECT transaction_isolation_level FROM sys.dm_exec_sessions WHERE session_id=@@SPID) AS IsolationLevel
FROM week13_lab.Stock WITH(ROWLOCK) WHERE ProductID='P';
COMMIT;

-- A3: round 2, keep the shared lock on P after reading 10.
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRANSACTION;
SELECT Qty, (SELECT transaction_isolation_level FROM sys.dm_exec_sessions WHERE session_id=@@SPID) AS IsolationLevel
FROM week13_lab.Stock WITH(ROWLOCK) WHERE ProductID='P';

-- A4: after observing B1 waiting, read P=10 again and commit.
SELECT Qty, (SELECT transaction_isolation_level FROM sys.dm_exec_sessions WHERE session_id=@@SPID) AS IsolationLevel
FROM week13_lab.Stock WITH(ROWLOCK) WHERE ProductID='P';
COMMIT;
