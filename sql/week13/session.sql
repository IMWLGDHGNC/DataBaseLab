-- Run in both A and B before each experiment; record the two different SPIDs.
IF DB_NAME() NOT LIKE N'DataBaseLab[_]Week6[_]Week10%' OR OBJECT_ID(N'week13_lab.Stock',N'U') IS NULL
    THROW 51930,'Initialize the dedicated Week13 sample database first.',1;
SET NOCOUNT ON;
SET IMPLICIT_TRANSACTIONS OFF;
SET LOCK_TIMEOUT 30000;
SET DEADLOCK_PRIORITY NORMAL;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT @@SPID AS SessionID, transaction_isolation_level AS IsolationLevel, @@TRANCOUNT AS TranCount,
       CONVERT(varchar(32),SERVERPROPERTY('ProductVersion')) AS SqlServerVersion,
       is_read_committed_snapshot_on AS RCSI
FROM sys.dm_exec_sessions AS s CROSS JOIN sys.databases AS d
WHERE s.session_id=@@SPID AND d.database_id=DB_ID();
