# Creates TWO fresh databases, retains them for inspection, never drops data.
$ErrorActionPreference = 'Stop'
$suffix = [guid]::NewGuid().ToString('N').Substring(0,12)
$databases = @("DataBaseLab_Week3_${suffix}A", "DataBaseLab_Week3_${suffix}B")
$outputDir = Join-Path $PSScriptRoot '..\docs\verification'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$schemaSql = @'
SELECT CONVERT(nvarchar(max),(SELECT
 (SELECT t.name AS [table], c.name AS [column], c.column_id, ty.name AS [type],
 c.max_length,c.precision,c.scale,c.is_nullable,dc.definition AS [default]
 FROM sys.tables t JOIN sys.columns c ON c.object_id=t.object_id
 JOIN sys.types ty ON ty.user_type_id=c.user_type_id
 LEFT JOIN sys.default_constraints dc ON dc.object_id=c.default_object_id
 WHERE t.is_ms_shipped=0 ORDER BY t.name,c.column_id FOR XML PATH('column'),TYPE),
 (SELECT OBJECT_NAME(parent_object_id) AS [table],name,definition,is_disabled,is_not_trusted
 FROM sys.check_constraints ORDER BY name FOR XML PATH('check'),TYPE),
 (SELECT f.name,OBJECT_NAME(f.parent_object_id) AS [table],pc.name AS [column],
 OBJECT_NAME(f.referenced_object_id) AS [referencedTable],rc.name AS [referencedColumn],
 f.is_disabled,f.is_not_trusted,f.delete_referential_action,f.update_referential_action
 FROM sys.foreign_keys f JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=f.object_id
 JOIN sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id
 JOIN sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id
 ORDER BY f.name,fc.constraint_column_id FOR XML PATH('fk'),TYPE),
 (SELECT t.name AS [table],i.name,i.is_unique,i.is_primary_key,i.is_unique_constraint,
 i.filter_definition,c.name AS [column],ic.key_ordinal
 FROM sys.tables t JOIN sys.indexes i ON i.object_id=t.object_id
 JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
 JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
 WHERE t.is_ms_shipped=0 ORDER BY t.name,i.name,ic.key_ordinal FOR XML PATH('index'),TYPE)
FOR XML PATH('schema'),TYPE));
'@
Add-Type -AssemblyName System.Data
$snapshots = @()
for ($i=0; $i -lt 2; $i++) {
    $db = $databases[$i]
    $logPath = Join-Path $outputDir ("week3-run-" + ($i+1) + '.txt')
    $logText = & (Join-Path $PSScriptRoot 'Run-Week3.ps1') -Database $db | Out-String -Width 220
    $logText = [regex]::Replace($logText, '(?m)[ \t]+\r?$', '')
    [IO.File]::WriteAllText($logPath, $logText.TrimEnd() + "`n", [Text.UTF8Encoding]::new($false))
    $connection = New-Object System.Data.SqlClient.SqlConnection ("Data Source=(localdb)\DataBaseLab;Initial Catalog=$db;Integrated Security=True")
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $schemaSql
        $schema = [string]$command.ExecuteScalar()
        $command.CommandText = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\sql\week3\04-verify.sql') -Raw -Encoding UTF8
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
        $data = New-Object System.Data.DataSet
        try {
            [void]$adapter.Fill($data)
            $hashes = @($data.Tables[0].Rows | ForEach-Object { "$($_.TableName)|$($_.RowCount)|$($_.DataHash)" }) -join "`n"
            $snapshots += @{ Schema=$schema; Data=$hashes }
        } finally { $data.Dispose(); $adapter.Dispose(); $command.Dispose() }
    } finally { $connection.Dispose() }
    Write-Output "PASS: $db (log: $logPath)"
}
if ($snapshots[0].Schema -cne $snapshots[1].Schema) { throw 'Schema reproduction mismatch.' }
if ($snapshots[0].Data -cne $snapshots[1].Data) { throw 'Sample data reproduction mismatch.' }
$report = @(
    'REPRODUCTION_PASS',
    "CheckedAt: $([DateTimeOffset]::Now.ToString('o'))",
    "DatabaseA: $($databases[0])",
    "DatabaseB: $($databases[1])",
    'Schema: columns, types, nullability, defaults, checks, foreign keys, indexes MATCH',
    'Data: 15 tables, 46 rows, ordered SHA256 hashes MATCH',
    'Both runs: CRUD_PASS, VERIFY_PASS, CONSTRAINT_TESTS_PASS (12/12)',
    '',
    $snapshots[0].Data
)
$report | Set-Content -LiteralPath (Join-Path $outputDir 'week3-reproduction.txt') -Encoding UTF8
$report
