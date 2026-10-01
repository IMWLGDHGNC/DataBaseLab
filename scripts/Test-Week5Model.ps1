param(
    [string]$Database = 'DataBaseLab_Week4',
    [string]$DiagramDirectory,
    [switch]$SourceOnly,
    [switch]$UpdateCatalog
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$schema = Get-Content -LiteralPath (Join-Path $root 'sql/week3/01-schema.sql') -Raw -Encoding UTF8
$verifyPath = Join-Path $root 'sql/week5/verify-er.sql'
$columns = @(); $keys = @(); $foreignKeys = @()
function Get-Names([string]$value) {
    @([regex]::Matches($value, '\[(\w+)\]') | ForEach-Object { $_.Groups[1].Value })
}
function Sql-Literal([string]$value) { "N'" + $value.Replace("'", "''") + "'" }
function Assert-Same($expected, $actual, [string]$description) {
    $difference = @(Compare-Object -ReferenceObject @($expected | Sort-Object) -DifferenceObject @($actual | Sort-Object))
    if ($difference.Count) { throw "$description differs: $($difference | Out-String)" }
}
foreach ($table in [regex]::Matches($schema, '(?s)CREATE TABLE dbo\.\[(\w+)\] \((.*?)\r?\n\);')) {
    $name = $table.Groups[1].Value; $body = $table.Groups[2].Value
    foreach ($column in [regex]::Matches($body, '(?m)^    \[(\w+)\] ([A-Z0-9]+(?:\([\d,]+\))?) (NOT NULL|NULL)')) {
        $columns += [pscustomobject]@{ Table=$name; Column=$column.Groups[1].Value; Type=$column.Groups[2].Value; Nullable=[int]($column.Groups[3].Value -eq 'NULL') }
    }
    foreach ($key in [regex]::Matches($body, 'CONSTRAINT \[(\w+)\] (PRIMARY KEY|UNIQUE|FOREIGN KEY) \((.*?)\)(?: REFERENCES dbo\.\[(\w+)\] \((.*?)\))?')) {
        $childColumns = @(Get-Names $key.Groups[3].Value)
        $parentColumns = @(Get-Names $key.Groups[5].Value)
        for ($i=0; $i -lt $childColumns.Count; $i++) {
            if ($key.Groups[2].Value -eq 'FOREIGN KEY') {
                $foreignKeys += [pscustomobject]@{ Name=$key.Groups[1].Value; Child=$name; Column=$childColumns[$i]; Parent=$key.Groups[4].Value; ParentColumn=$parentColumns[$i]; Position=$i+1 }
            } else {
                $keys += [pscustomobject]@{ Name=$key.Groups[1].Value; Table=$name; Kind=$(if ($key.Groups[2].Value -eq 'PRIMARY KEY') {'PK'} else {'UQ'}); Column=$childColumns[$i]; Position=$i+1 }
            }
        }
    }
}
foreach ($fk in [regex]::Matches($schema, 'ALTER TABLE dbo\.(\w+) ADD CONSTRAINT (\w+) FOREIGN KEY \(([^)]+)\) REFERENCES dbo\.(\w+)\(([^)]+)\);')) {
    $childColumns = $fk.Groups[3].Value.Split(','); $parentColumns = $fk.Groups[5].Value.Split(',')
    for ($i=0; $i -lt $childColumns.Count; $i++) {
        $foreignKeys += [pscustomobject]@{ Name=$fk.Groups[2].Value; Child=$fk.Groups[1].Value; Column=$childColumns[$i].Trim(); Parent=$fk.Groups[4].Value; ParentColumn=$parentColumns[$i].Trim(); Position=$i+1 }
    }
}
if ($columns.Count -ne 107 -or @($keys | Where-Object Kind -eq 'PK').Count -ne 15 -or $foreignKeys.Count -ne 27) {
    throw 'DDL parser did not cover the reviewed 15-table model. Review the parser before updating the catalog.'
}

# A committed catalog makes direct execution of verify-er.sql reject drift too.
# Updating it is explicit; normal validation never rewrites the expected model.
$parts = @('-- BEGIN GENERATED MODEL CATALOG',
 'CREATE TABLE #ExpectedColumns(TableName sysname COLLATE DATABASE_DEFAULT, ColumnName sysname COLLATE DATABASE_DEFAULT, SqlType varchar(40) COLLATE DATABASE_DEFAULT, Nullable bit);',
 'INSERT #ExpectedColumns VALUES')
$parts += (($columns | ForEach-Object { '(' + (Sql-Literal $_.Table) + ',' + (Sql-Literal $_.Column) + ',' + (Sql-Literal $_.Type) + ',' + $_.Nullable + ')' }) -join ",`n") + ';'
$parts += @('CREATE TABLE #ExpectedKeys(KeyName sysname COLLATE DATABASE_DEFAULT, TableName sysname COLLATE DATABASE_DEFAULT, Kind char(2) COLLATE DATABASE_DEFAULT, ColumnName sysname COLLATE DATABASE_DEFAULT, Position int);','INSERT #ExpectedKeys VALUES')
$parts += (($keys | ForEach-Object { '(' + (Sql-Literal $_.Name) + ',' + (Sql-Literal $_.Table) + ',' + (Sql-Literal $_.Kind) + ',' + (Sql-Literal $_.Column) + ',' + $_.Position + ')' }) -join ",`n") + ';'
$parts += @('CREATE TABLE #ExpectedForeignKeys(KeyName sysname COLLATE DATABASE_DEFAULT, ChildTable sysname COLLATE DATABASE_DEFAULT, ChildColumn sysname COLLATE DATABASE_DEFAULT, ParentTable sysname COLLATE DATABASE_DEFAULT, ParentColumn sysname COLLATE DATABASE_DEFAULT, Position int);','INSERT #ExpectedForeignKeys VALUES')
$parts += (($foreignKeys | ForEach-Object { '(' + (Sql-Literal $_.Name) + ',' + (Sql-Literal $_.Child) + ',' + (Sql-Literal $_.Column) + ',' + (Sql-Literal $_.Parent) + ',' + (Sql-Literal $_.ParentColumn) + ',' + $_.Position + ')' }) -join ",`n") + ';'
$parts += '-- END GENERATED MODEL CATALOG'
$catalog = $parts -join "`n"
$verify = (Get-Content -LiteralPath $verifyPath -Raw -Encoding UTF8).Replace("`r`n", "`n")
$blockPattern = '(?s)-- BEGIN GENERATED MODEL CATALOG.*?-- END GENERATED MODEL CATALOG'
if (-not [regex]::IsMatch($verify,$blockPattern)) { throw 'Expected catalog markers are missing.' }
if ($UpdateCatalog) {
    $verify = [regex]::Replace($verify,$blockPattern,[System.Text.RegularExpressions.MatchEvaluator]{ param($m) $catalog })
    [IO.File]::WriteAllText($verifyPath,$verify,[Text.UTF8Encoding]::new($false))
} elseif ([regex]::Match($verify,$blockPattern).Value -cne $catalog) {
    throw 'Committed SQL catalog differs from DDL. Review model changes, then explicitly use -UpdateCatalog.'
}

# Compare each diagram's attributes and PK/FK/single-column UK markers to DDL.
if (-not $DiagramDirectory) { $DiagramDirectory = Join-Path $root 'docs/week5' }
$diagrams = @(Get-ChildItem -LiteralPath $DiagramDirectory -Filter '*.mmd')
Assert-Same @('er-purchase.mmd','er-sales.mmd','er-stock.mmd','er-v0.1.mmd') @($diagrams.Name) 'Diagram file set'
foreach ($diagram in $diagrams) {
    $source = Get-Content -LiteralPath $diagram.FullName -Raw -Encoding UTF8
    $seen = @(); $entities = @()
    foreach ($entity in [regex]::Matches($source,'(?ms)^    (\w+) \{\r?\n(.*?)^    \}')) {
        $name=$entity.Groups[1].Value; $entities += $name
        foreach ($attribute in [regex]::Matches($entity.Groups[2].Value,'(?m)^        (\S+) (\w+)(.*?) "(NULL|NOT_NULL);')) {
            $col=$attribute.Groups[2].Value
            $seen += "$name|$col|$($attribute.Groups[1].Value.Replace('_',','))|$([int]($attribute.Groups[4].Value -eq 'NULL'))"
            $expectedMarks=@()
            if (@($keys | Where-Object { $_.Table -eq $name -and $_.Column -eq $col -and $_.Kind -eq 'PK' }).Count) { $expectedMarks += 'PK' }
            if (@($foreignKeys | Where-Object { $_.Child -eq $name -and $_.Column -eq $col }).Count) { $expectedMarks += 'FK' }
            foreach ($key in @($keys | Where-Object { $_.Table -eq $name -and $_.Column -eq $col -and $_.Kind -eq 'UQ' })) {
                if (@($keys | Where-Object Name -eq $key.Name).Count -eq 1) { $expectedMarks += 'UK' }
            }
            $actualMarks=@($attribute.Groups[3].Value.Trim().Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            # Joining also handles attributes with no key markers.
            if ((($expectedMarks | Sort-Object) -join ',') -cne (($actualMarks | Sort-Object) -join ',')) { throw "Key markers differ: $($diagram.Name) $name.$col" }
        }
    }
    $expectedColumns=@($columns | Where-Object { $_.Table -in $entities } | ForEach-Object { "$($_.Table)|$($_.Column)|$($_.Type)|$($_.Nullable)" })
    Assert-Same $expectedColumns $seen "$($diagram.Name) attributes"
    if ($diagram.Name -eq 'er-v0.1.mmd') { Assert-Same @($columns.Table | Select-Object -Unique) $entities 'Full diagram entities' }
    if ($diagram.Name -in @('er-v0.1.mmd','er-stock.mmd')) {
        if ($source -notmatch 'SalesOrderItem \|\|\.\.\|\{ InventoryReservation') { throw 'Historical reservations must have business minimum one.' }
    }
    Write-Output "DIAGRAM_PASS $($diagram.Name): $($seen.Count) attributes"
}
Write-Output 'MODEL_SOURCE_PASS: DDL, committed catalog and diagram attribute/key definitions agree.'
if (-not $SourceOnly) {
    & (Join-Path $PSScriptRoot 'Invoke-LabSql.ps1') -Database $Database -InputFile $verifyPath
    Write-Output "MODEL_DATABASE_PASS: $Database"
}
