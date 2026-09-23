param(
    [ValidatePattern('^DataBaseLab_Week4(?:_[A-Za-z0-9]+)?$')]
    [ValidateLength(1,64)]
    [string]$Database = 'DataBaseLab_Week4'
)
$ErrorActionPreference = 'Stop'
$invoke = Join-Path $PSScriptRoot 'Invoke-LabSql.ps1'
$week3 = Join-Path $PSScriptRoot '..\sql\week3'
$week4 = Join-Path $PSScriptRoot '..\sql\week4'
$temporarySql = Join-Path ([IO.Path]::GetTempPath()) ('week4-create-' + [guid]::NewGuid().ToString('N') + '.sql')
try {
    # Reuse the reviewed Week 3 DDL and exact seed; only the validated database name changes.
    $createSql = (Get-Content -LiteralPath (Join-Path $week3 '00-create-database.sql') -Raw -Encoding UTF8).Replace('DataBaseLab_Week3', $Database)
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
        (Join-Path $week3 '04-verify.sql')
    )) {
        Write-Output "Executing $([IO.Path]::GetFileName($step)) in $Database"
        & $invoke -Database $Database -InputFile $step
    }
    Write-Output "WEEK4_PASS: $Database"
} finally {
    if (Test-Path -LiteralPath $temporarySql) { Remove-Item -LiteralPath $temporarySql }
}
