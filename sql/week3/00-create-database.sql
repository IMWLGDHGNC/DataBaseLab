SET NOCOUNT ON;
SELECT @@VERSION AS SqlServerVersion, ORIGINAL_LOGIN() AS WindowsLogin;
IF DB_ID(N'DataBaseLab_Week3') IS NULL
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
    DECLARE @FileBase NVARCHAR(4000) = @Directory + N'DataBaseLab_Week3_'
        + CONVERT(NVARCHAR(36), NEWID());
    DECLARE @CreateSql NVARCHAR(MAX) =
        N'CREATE DATABASE [DataBaseLab_Week3] ON PRIMARY '
        + N'(NAME = N''DataBaseLab_Week3_Data'', FILENAME = N'''
        + REPLACE(@FileBase + N'.mdf', N'''', N'''''') + N''') '
        + N'LOG ON (NAME = N''DataBaseLab_Week3_Log'', FILENAME = N'''
        + REPLACE(@FileBase + N'_log.ldf', N'''', N'''''') + N''');';
    EXEC sys.sp_executesql @CreateSql;
END;
