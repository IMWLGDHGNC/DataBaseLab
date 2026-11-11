param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^DataBaseLab_Week6_Week10[0-9]+$')]
    [string]$Database
)
$ErrorActionPreference = 'Stop'
# Run-Week10 first, then add triggers without recreating the sample database.
& (Join-Path $PSScriptRoot 'Invoke-LabSql.ps1') -Database $Database -InputFile (Join-Path $PSScriptRoot '../sql/week11/trigger.sql')
& (Join-Path $PSScriptRoot 'Invoke-LabSql.ps1') -Database $Database -InputFile (Join-Path $PSScriptRoot '../sql/week11/window_query.sql')
Write-Output "WEEK11_INSTALL_PASS: $Database"
