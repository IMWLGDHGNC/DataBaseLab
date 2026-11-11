param(
    [ValidatePattern('^DataBaseLab_Week6_Week10[0-9]+$')]
    [string]$Database = ('DataBaseLab_Week6_Week10' + (Get-Date -Format 'yyyyMMddHHmmss'))
)
$ErrorActionPreference = 'Stop'
# Retain the v1.0 migration baseline and existing databases for comparison.
& (Join-Path $PSScriptRoot 'Run-Week6.ps1') -Database $Database
foreach ($file in @('migration.sql','function.sql','procedure.sql','permissions.sql')) {
    & (Join-Path $PSScriptRoot 'Invoke-LabSql.ps1') -Database $Database -InputFile (Join-Path $PSScriptRoot "../sql/week10/$file")
}
Write-Output "WEEK10_INSTALL_PASS: $Database"
