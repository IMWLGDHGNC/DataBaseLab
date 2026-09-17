param(
    [ValidatePattern('^DataBaseLab_Week3(?:_[A-Za-z0-9]+)?$')]
    [ValidateLength(1,64)]
    [string]$Database = 'DataBaseLab_Week3'
)
$ErrorActionPreference = 'Stop'
$sqlDir = Join-Path $PSScriptRoot '..\sql\week3'
$invoke = Join-Path $PSScriptRoot 'Invoke-LabSql.ps1'
# A generated file is needed only for the validated database identifier.
# Existing databases are never dropped; schema creation rejects nonempty ones.
$temporarySql = Join-Path ([IO.Path]::GetTempPath()) ('week3-create-' + [guid]::NewGuid().ToString('N') + '.sql')
try {
    $createSql = (Get-Content -LiteralPath (Join-Path $sqlDir '00-create-database.sql') -Raw -Encoding UTF8).Replace('DataBaseLab_Week3', $Database)
    [IO.File]::WriteAllText($temporarySql, $createSql, [Text.UTF8Encoding]::new($false))
    & $invoke -Database master -InputFile $temporarySql
    foreach ($file in @('01-schema.sql','02-seed.sql','04-verify.sql','03-crud.sql','04-verify.sql','05-constraint-tests.sql')) {
        Write-Output "Executing $file in $Database"
        & $invoke -Database $Database -InputFile (Join-Path $sqlDir $file)
    }
    Write-Output "WEEK3_PASS: $Database"
} finally {
    if (Test-Path -LiteralPath $temporarySql) { Remove-Item -LiteralPath $temporarySql }
}
