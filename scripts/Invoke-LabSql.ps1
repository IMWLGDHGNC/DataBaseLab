param(
    [string]$Database = 'DataBaseLab',
    [Parameter(Mandatory = $true)][string]$InputFile
)
$ErrorActionPreference = 'Stop'
# Validate the file before contacting SQL Server, so a placeholder path cannot
# be hidden by an unrelated connection error.
if (-not (Test-Path -LiteralPath $InputFile -PathType Leaf)) {
    throw "SQL file does not exist: $InputFile. To initialize and verify this environment, run: powershell.exe -NoProfile -File .\scripts\Initialize-LocalDB.ps1"
}
$sql = Get-Content -LiteralPath $InputFile -Raw -Encoding UTF8
$localDb = Join-Path $env:ProgramFiles 'Microsoft SQL Server\160\Tools\Binn\SqlLocalDB.exe'
if (-not (Test-Path -LiteralPath $localDb)) {
    throw 'SQL Server 2022 LocalDB is not installed. Run scripts\Setup-LocalDB.ps1 first.'
}
$instances = & $localDb info
if ($LASTEXITCODE -ne 0) { throw 'Cannot list LocalDB instances for the current Windows user.' }
if ($instances -notcontains 'DataBaseLab') {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    throw "LocalDB instance DataBaseLab is not visible to Windows user $identity. In this same terminal, run: powershell.exe -NoProfile -File .\scripts\Initialize-LocalDB.ps1"
}
& $localDb start DataBaseLab | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Cannot start LocalDB instance DataBaseLab. Run scripts\Initialize-LocalDB.ps1 in this same terminal.' }
Add-Type -AssemblyName System.Data
$builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$builder['Data Source'] = '(localdb)\DataBaseLab'
$builder['Initial Catalog'] = $Database
$builder['Integrated Security'] = $true
$builder['Connect Timeout'] = 30
$connection = New-Object System.Data.SqlClient.SqlConnection $builder.ConnectionString
try {
    $connection.Open()
    # Supports standalone GO separators, not sqlcmd directives or GO repeat counts.
    foreach ($batch in [regex]::Split($sql, '(?im)^\s*GO\s*\r?$')) {
        if ([string]::IsNullOrWhiteSpace($batch)) { continue }
        $command = $connection.CreateCommand()
        $command.CommandText = $batch
        $command.CommandTimeout = 60
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
        $data = New-Object System.Data.DataSet
        try {
            [void]$adapter.Fill($data)
            foreach ($table in $data.Tables) { $table | Format-Table -AutoSize -Wrap }
        } finally {
            $adapter.Dispose()
            $data.Dispose()
            $command.Dispose()
        }
    }
} finally { $connection.Dispose() }
