-- On a third connection set @A and @B to the two SPIDs, then run while waiting.
DECLARE @A int=0,@B int=0;
SELECT session_id AS SessionID, transaction_isolation_level AS IsolationLevel,
       open_transaction_count AS TranCount
FROM sys.dm_exec_sessions WHERE session_id IN (@A,@B) ORDER BY session_id;
SELECT session_id AS SessionID, blocking_session_id AS Blocker, wait_type AS WaitType,
       wait_time AS WaitMs
FROM sys.dm_exec_requests WHERE session_id IN (@A,@B) AND blocking_session_id<>0 ORDER BY session_id;
SELECT l.request_session_id AS SessionID, l.resource_type AS ResourceType,
       OBJECT_NAME(p.object_id) AS TableName, RTRIM(l.resource_description) AS Resource,
       l.request_mode AS Mode, l.request_status AS Status
FROM sys.dm_tran_locks l
LEFT JOIN sys.partitions p ON p.hobt_id=l.resource_associated_entity_id AND l.resource_type IN ('KEY','PAGE','RID','HOBT')
WHERE l.resource_database_id=DB_ID() AND l.request_session_id IN (@A,@B)
ORDER BY l.request_session_id,l.resource_type,l.resource_description,l.request_mode,l.request_status;
