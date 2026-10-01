param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^DataBaseLab_Week4_W5(?:Fix|Review|Test)[A-Za-z0-9]+$')]
    [string]$Database
)
# Run only in a dedicated Week5 test database created by Run-Week4.ps1.
# Deliberately corrupt one definition at a time and restore it in finally.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Data
$root=Split-Path $PSScriptRoot -Parent
$sql=Get-Content -LiteralPath (Join-Path $root 'sql/week5/verify-er.sql') -Raw -Encoding UTF8
$schema=Get-Content -LiteralPath (Join-Path $root 'sql/week3/01-schema.sql') -Raw -Encoding UTF8
$filteredIndex=[regex]::Match($schema,'CREATE UNIQUE INDEX UX_Payment_OneSuccess[^;]+;').Value
if (-not $filteredIndex) { throw 'Payment index DDL missing.' }
$builder=New-Object System.Data.SqlClient.SqlConnectionStringBuilder
$builder['Data Source']='(localdb)\DataBaseLab'
$builder['Initial Catalog']=$Database
$builder['Integrated Security']=$true
$connection=New-Object System.Data.SqlClient.SqlConnection $builder.ConnectionString
function Execute-Sql([string]$text) {
    $command=$connection.CreateCommand()
    try { $command.CommandText=$text; $command.CommandTimeout=60; [void]$command.ExecuteNonQuery() }
    finally { $command.Dispose() }
}
$cases=@(
    @{ Name='missing_candidate_key'; Error=51511;
       Change='ALTER TABLE dbo.ProductCategory DROP CONSTRAINT UQ_ProductCategory_1;';
       Restore='ALTER TABLE dbo.ProductCategory ADD CONSTRAINT UQ_ProductCategory_1 UNIQUE(CategoryName);' },
    @{ Name='wrong_column_type'; Error=51510;
       Change='ALTER TABLE dbo.ProductCategory ALTER COLUMN Description nvarchar(201) NULL;';
       Restore='ALTER TABLE dbo.ProductCategory ALTER COLUMN Description nvarchar(200) NULL;' },
    @{ Name='wrong_nullability'; Error=51510;
       Change='ALTER TABLE dbo.ProductCategory ALTER COLUMN Description nvarchar(200) NOT NULL;';
       Restore='ALTER TABLE dbo.ProductCategory ALTER COLUMN Description nvarchar(200) NULL;' },
    @{ Name='wrong_fk_pairing'; Error=51512;
       Change='ALTER TABLE dbo.PurchaseOrder DROP CONSTRAINT FK_PurchaseOrder_CreatedBy; ALTER TABLE dbo.PurchaseOrder ADD CONSTRAINT FK_PurchaseOrder_CreatedBy FOREIGN KEY(ReceivedBy) REFERENCES dbo.Employee(EmployeeID);';
       Restore='ALTER TABLE dbo.PurchaseOrder DROP CONSTRAINT FK_PurchaseOrder_CreatedBy; ALTER TABLE dbo.PurchaseOrder ADD CONSTRAINT FK_PurchaseOrder_CreatedBy FOREIGN KEY(CreatedBy) REFERENCES dbo.Employee(EmployeeID);' },
    @{ Name='missing_filtered_unique_index'; Error=51513;
       Change='DROP INDEX UX_Payment_OneSuccess ON dbo.PaymentRecord;'; Restore=$filteredIndex }
)
try {
    $connection.Open()
    Execute-Sql $sql
    foreach ($case in $cases) {
        $actual=0
        try {
            Execute-Sql $case.Change
            try { Execute-Sql $sql }
            catch {
                $exception=$_.Exception
                while ($exception -and $exception -isnot [System.Data.SqlClient.SqlException]) { $exception=$exception.InnerException }
                if (-not $exception) { throw }
                $actual=$exception.Number
            }
        } finally {
            Execute-Sql $case.Restore
            # Failed assertions can leave local temporary tables on this session.
            $connection.Close(); $connection.Open()
        }
        if ($actual -ne $case.Error) { throw "Mutation $($case.Name): expected $($case.Error), got $actual." }
        Write-Output "REJECTION_PASS $($case.Name): $actual"
    }
    Execute-Sql $sql
} finally { $connection.Dispose() }

$fixture=Join-Path ([IO.Path]::GetTempPath()) ('week5-diagrams-'+[guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $fixture)
$sourceDir=Join-Path $root 'docs/week5'
try {
    foreach ($case in @('missing_diagram_pk','wrong_history_cardinality')) {
        Get-ChildItem -LiteralPath $sourceDir -Filter '*.mmd' | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $fixture }
        $file=Join-Path $fixture 'er-v0.1.mmd'
        $text=Get-Content -LiteralPath $file -Raw -Encoding UTF8
        if ($case -eq 'missing_diagram_pk') { $text=$text.Replace('CategoryID PK','CategoryID') }
        else { $text=$text.Replace('SalesOrderItem ||..|{ InventoryReservation','SalesOrderItem ||..o{ InventoryReservation') }
        [IO.File]::WriteAllText($file,$text,[Text.UTF8Encoding]::new($false))
        $rejected=$false
        try { & (Join-Path $PSScriptRoot 'Test-Week5Model.ps1') -SourceOnly -DiagramDirectory $fixture | Out-Null }
        catch {
            if ($_.Exception.Message -notmatch 'Key markers differ|Historical reservations') { throw }
            $rejected=$true
        }
        if (-not $rejected) { throw "Source mutation was accepted: $case" }
        Write-Output "REJECTION_PASS $case"
    }
} finally {
    Get-ChildItem -LiteralPath $fixture -File | ForEach-Object { Remove-Item -LiteralPath $_.FullName }
    Remove-Item -LiteralPath $fixture
}
Write-Output 'VALIDATOR_REGRESSION_PASS: 5 database mutations and 2 diagram mutations rejected; definitions restored.'
