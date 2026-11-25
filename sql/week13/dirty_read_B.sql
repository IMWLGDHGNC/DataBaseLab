-- B1: round 1, read uncommitted 15, then run A2.
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT Qty, (SELECT transaction_isolation_level FROM sys.dm_exec_sessions WHERE session_id=@@SPID) AS IsolationLevel
FROM week13_lab.Stock WITH(ROWLOCK) WHERE ProductID='P';

-- B2: round 2, plain READ COMMITTED. RCSI off waits; RCSI on returns 10.
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT Qty, (SELECT transaction_isolation_level FROM sys.dm_exec_sessions WHERE session_id=@@SPID) AS IsolationLevel
FROM week13_lab.Stock WHERE ProductID='P';

-- B3: optional round 3, force lock-based READ COMMITTED regardless of RCSI.
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT Qty, (SELECT transaction_isolation_level FROM sys.dm_exec_sessions WHERE session_id=@@SPID) AS IsolationLevel
FROM week13_lab.Stock WITH(READCOMMITTEDLOCK) WHERE ProductID='P';
