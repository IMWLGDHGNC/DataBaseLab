SET NOCOUNT ON;
SELECT @@VERSION AS SqlServerVersion, ORIGINAL_LOGIN() AS WindowsLogin;
IF DB_ID(N'DataBaseLab') IS NULL
BEGIN
    -- Use this instance's master directory rather than LocalDB's shared user
    -- profile default. A unique suffix also avoids orphaned files from an old
    -- instance; existing files are never overwritten or attached automatically.
    DECLARE @MasterFile NVARCHAR(260) = (
        SELECT physical_name FROM sys.master_files
        WHERE database_id = DB_ID(N'master') AND file_id = 1
    );
    IF @MasterFile IS NULL OR CHARINDEX(N'\', REVERSE(@MasterFile)) = 0
        THROW 50002, 'Cannot determine the LocalDB instance data directory.', 1;
    DECLARE @Directory NVARCHAR(260) = LEFT(
        @MasterFile, LEN(@MasterFile) - CHARINDEX(N'\', REVERSE(@MasterFile)) + 1
    );
    DECLARE @FileBase NVARCHAR(4000) = @Directory + N'DataBaseLab_'
        + CONVERT(NVARCHAR(36), NEWID());
    DECLARE @CreateSql NVARCHAR(MAX) =
        N'CREATE DATABASE [DataBaseLab] ON PRIMARY '
        + N'(NAME = N''DataBaseLab_Data'', FILENAME = N'''
        + REPLACE(@FileBase + N'.mdf', N'''', N'''''') + N''') '
        + N'LOG ON (NAME = N''DataBaseLab_Log'', FILENAME = N'''
        + REPLACE(@FileBase + N'_log.ldf', N'''', N'''''') + N''');';
    EXEC sys.sp_executesql @CreateSql;
END;
GO
USE [DataBaseLab];
SET XACT_ABORT ON;
BEGIN TRANSACTION;
CREATE TABLE #EnvironmentSmokeTest (
    ID INT NOT NULL PRIMARY KEY,
    Amount DECIMAL(10,2) NOT NULL CHECK (Amount > 0)
);
INSERT INTO #EnvironmentSmokeTest (ID, Amount) VALUES (1, 0.50), (2, 1.00);
IF (SELECT COUNT(*) FROM #EnvironmentSmokeTest) <> 2
    THROW 50001, 'Environment smoke test failed.', 1;
SELECT ID, Amount, FLOOR(Amount) AS CalculatedPoints,
       CASE WHEN Amount >= 1.00 THEN 1 ELSE 0 END AS ShouldCreatePointsMovement
FROM #EnvironmentSmokeTest;
ROLLBACK TRANSACTION;
SELECT DB_NAME() AS DatabaseName, N'PASS' AS EnvironmentSmokeTest;
SELECT name AS LogicalFileName, physical_name AS DatabaseFile
FROM sys.database_files;
