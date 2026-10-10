param(
    [ValidatePattern('^DataBaseLab_Week6(?:_[A-Za-z0-9]+)?$')]
    [ValidateLength(1,64)]
    [string]$Database = ('DataBaseLab_Week6_' + (Get-Date -Format 'yyyyMMddHHmmss'))
)
$ErrorActionPreference = 'Stop'
$invoke = Join-Path $PSScriptRoot 'Invoke-LabSql.ps1'
$week3 = Join-Path $PSScriptRoot '..\sql\week3'
$week4 = Join-Path $PSScriptRoot '..\sql\week4'
$week5 = Join-Path $PSScriptRoot '..\sql\week5'
$week6 = Join-Path $PSScriptRoot '..\sql\week6'
# Transcripts include the Windows login and machine details. Keep originals in
# the ignored output directory; only a reviewed, sanitized copy belongs in result/.
$resultDir = Join-Path $PSScriptRoot '..\output\week6'
[IO.Directory]::CreateDirectory($resultDir) | Out-Null
$logFile = Join-Path $resultDir ($Database + '.txt')
$temporarySql = Join-Path ([IO.Path]::GetTempPath()) ('week6-create-' + [guid]::NewGuid().ToString('N') + '.sql')
$transcriptStarted = $false
try {
    Start-Transcript -Path $logFile -Force | Out-Null
    $transcriptStarted = $true
    Write-Output "Building an isolated v0.1 baseline in $Database; existing databases are never dropped."
    $createSql = "IF DB_ID(N'$Database') IS NOT NULL THROW 51900, 'Staging database already exists; choose a new database name.', 1;`r`n" + (Get-Content -LiteralPath (Join-Path $week3 '00-create-database.sql') -Raw -Encoding UTF8).Replace('DataBaseLab_Week3', $Database)
    [IO.File]::WriteAllText($temporarySql, $createSql, [Text.UTF8Encoding]::new($false))
    & $invoke -Database master -InputFile $temporarySql
    foreach ($step in @(
        (Join-Path $week3 '01-schema.sql'),
        (Join-Path $week3 '02-seed.sql'),
        (Join-Path $week3 '04-verify.sql'),
        (Join-Path $week3 '03-crud.sql'),
        (Join-Path $week3 '04-verify.sql'),
        (Join-Path $week4 'constraint.sql'),
        (Join-Path $week3 '05-constraint-tests.sql'),
        (Join-Path $week4 'query.sql'),
        (Join-Path $week4 'view.sql'),
        (Join-Path $week4 'role.sql'),
        (Join-Path $week5 'verify-er.sql'),
        (Join-Path $week3 '04-verify.sql')
    )) {
        Write-Output "Executing $([IO.Path]::GetFileName($step)) in $Database"
        & $invoke -Database $Database -InputFile $step
    }
    Write-Output 'Executing migration.sql after the reviewed Week 5 v0.1 baseline'
    & $invoke -Database $Database -InputFile (Join-Path $week6 'migration.sql')
    Write-Output 'Executing role.sql after migration'
    & $invoke -Database $Database -InputFile (Join-Path $week4 'role.sql')
    Write-Output 'Executing regression.sql after migration'
    & $invoke -Database $Database -InputFile (Join-Path $week6 'regression.sql')
    Write-Output "WEEK6_PASS: $Database"
} catch {
    Write-Error "Week 6 run failed. The staging database was not automatically dropped: $_"
    throw
} finally {
    if ($transcriptStarted) { Stop-Transcript | Out-Null }
    if (Test-Path -LiteralPath $temporarySql) { Remove-Item -LiteralPath $temporarySql }
}
