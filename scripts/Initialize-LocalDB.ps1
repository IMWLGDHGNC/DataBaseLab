# Run as the Windows user who will use the database.
$ErrorActionPreference = 'Stop'
$localDb = Join-Path $env:ProgramFiles 'Microsoft SQL Server\160\Tools\Binn\SqlLocalDB.exe'
if (-not (Test-Path -LiteralPath $localDb)) { throw 'Install SQL Server 2022 LocalDB first with Setup-LocalDB.ps1.' }
$instances = & $localDb info
if ($LASTEXITCODE -ne 0) { throw 'Cannot list LocalDB instances.' }
if ($instances -notcontains 'DataBaseLab') {
    & $localDb create DataBaseLab 16.0
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create LocalDB instance.' }
}
& $localDb start DataBaseLab
if ($LASTEXITCODE -ne 0) { throw 'Cannot start LocalDB instance.' }
& (Join-Path $PSScriptRoot 'Invoke-LabSql.ps1') -Database master -InputFile (Join-Path $PSScriptRoot '..\sql\00-verify-environment.sql')
