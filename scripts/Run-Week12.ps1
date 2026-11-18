param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^DataBaseLab_Week6_Week10[0-9]+$')]
    [string]$Database
)
$ErrorActionPreference = 'Stop'
# The completion procedure keeps its original entry point and source file.
$files = @('week10/procedure.sql','week12/recursive_query.sql','week12/restock_transaction.sql','week12/permissions.sql')
foreach ($file in $files) {
    & (Join-Path $PSScriptRoot 'Invoke-LabSql.ps1') -Database $Database -InputFile (Join-Path $PSScriptRoot "../sql/$file")
}
Write-Output "WEEK12_INSTALL_PASS: $Database"
