param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^DataBaseLab_Week6_(?:Fix|Review|Test)[A-Za-z0-9]+$')]
    [string]$Database
)
# Only run against a dedicated, successfully migrated Week6 sample database.
# All intentional mutations are restored in finally; existing databases stay intact.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Data
$root=Split-Path $PSScriptRoot -Parent
$regression=Get-Content -LiteralPath (Join-Path $root 'sql/week6/regression.sql') -Raw -Encoding UTF8
$builder=[System.Data.SqlClient.SqlConnectionStringBuilder]::new()
$builder['Data Source']='(localdb)\DataBaseLab'
$builder['Initial Catalog']=$Database
$builder['Integrated Security']=$true
$connection=[System.Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
function Execute-Sql([string]$sql) {
    $command=$connection.CreateCommand()
    $command.CommandText=$sql
    $command.CommandTimeout=60
    $adapter=[System.Data.SqlClient.SqlDataAdapter]::new($command)
    $data=[System.Data.DataSet]::new()
    try { [void]$adapter.Fill($data); return ,$data }
    catch { $data.Dispose(); throw }
    finally { $adapter.Dispose(); $command.Dispose() }
}
function Execute-Statement([string]$sql) {
    $data=Execute-Sql $sql
    $data.Dispose()
}
function Get-Definition([string]$sql) {
    $data=Execute-Sql $sql
    try { return [string]$data.Tables[0].Rows[0][0] } finally { $data.Dispose() }
}
function Get-ViewDdl([string]$name) {
    $definition=Get-Definition "SELECT OBJECT_DEFINITION(OBJECT_ID(N'dbo.$name'));"
    if(-not $definition) { throw "Missing source view: $name" }
    return [regex]::Replace($definition,'(?i)^\s*CREATE(?:\s+OR\s+ALTER)?\s+VIEW','CREATE OR ALTER VIEW')
}
function Get-DataHashes {
    $sql=@'
CREATE TABLE #DataHashes(TableName nvarchar(260),DataHash varchar(64));
DECLARE @Schema sysname,@Table sysname,@Keys nvarchar(max),@Sql nvarchar(max);
DECLARE data_tables CURSOR LOCAL FAST_FORWARD FOR
SELECT s.name,t.name FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
WHERE s.name IN (N'dbo',N'week6_baseline',N'customer_security') AND t.is_ms_shipped=0;
OPEN data_tables;
FETCH NEXT FROM data_tables INTO @Schema,@Table;
WHILE @@FETCH_STATUS=0
BEGIN
    SELECT @Keys=STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(c.name)),N',') WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.columns c WHERE c.object_id=OBJECT_ID(QUOTENAME(@Schema)+N'.'+QUOTENAME(@Table));
    SET @Sql=N'INSERT #DataHashes SELECT @Name,CONVERT(varchar(64),HASHBYTES(''SHA2_256'',CONVERT(nvarchar(max),
        (SELECT * FROM '+QUOTENAME(@Schema)+N'.'+QUOTENAME(@Table)+N' ORDER BY '+@Keys+N' FOR XML PATH(''row''),ROOT(''rows''),TYPE))),2);';
    EXEC sys.sp_executesql @Sql,N'@Name nvarchar(260)',@Name=@Table;
    FETCH NEXT FROM data_tables INTO @Schema,@Table;
END;
CLOSE data_tables;
DEALLOCATE data_tables;
SELECT TableName,DataHash FROM #DataHashes ORDER BY TableName;
DROP TABLE #DataHashes;
'@
    $data=Execute-Sql $sql
    try { return (@($data.Tables[0].Rows | ForEach-Object { "$($_.TableName):$($_.DataHash)" }) -join '|') }
    finally { $data.Dispose() }
}
$evidence=[ordered]@{ Database=$Database; Cases=@(); Comparison=@(); BeforeExpectedActual=@(); WriteAndRoleCases=@(); Final=@() }
try {
    $connection.Open()
    Execute-Statement $regression
    $hashBefore=Get-DataHashes
    $check=Get-Definition "SELECT definition FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.InventoryMovement') AND name=N'CK_InventoryMovement_Rule1';"
    if(-not $check) { throw 'Missing movement CHECK definition.' }
    $restoreCheck="ALTER TABLE dbo.InventoryMovement WITH CHECK ADD CONSTRAINT CK_InventoryMovement_Rule1 CHECK $check;"
    $salesView=Get-ViewDdl 'vw_ProductSales'
    $inventoryView=Get-ViewDdl 'vw_InventoryStatus'
    $orderView=Get-ViewDdl 'vw_OrderDetail'
    $weakCheck=$check.Replace('<>(0)','>=(0)')
    $badInventoryView=$inventoryView.Replace('THEN 0','THEN 1')
    $badOrderView=$orderView.Replace('i.Quantity, i.DealUnitPrice','i.Quantity+1 AS Quantity, i.DealUnitPrice')
    if($weakCheck -eq $check -or $badInventoryView -eq $inventoryView -or $badOrderView -eq $orderView) {
        throw 'Expected source definitions did not match the mutation templates.'
    }
    $cases=@(
        @{Name='missing_movement_check';Error=51727;Change='ALTER TABLE dbo.InventoryMovement DROP CONSTRAINT CK_InventoryMovement_Rule1;';Restore=$restoreCheck},
        @{Name='disabled_movement_check';Error=51727;Change='ALTER TABLE dbo.InventoryMovement NOCHECK CONSTRAINT CK_InventoryMovement_Rule1;';Restore='ALTER TABLE dbo.InventoryMovement WITH CHECK CHECK CONSTRAINT CK_InventoryMovement_Rule1;'},
        @{Name='untrusted_movement_check';Error=51727;Change='ALTER TABLE dbo.InventoryMovement NOCHECK CONSTRAINT CK_InventoryMovement_Rule1; ALTER TABLE dbo.InventoryMovement CHECK CONSTRAINT CK_InventoryMovement_Rule1;';Restore='ALTER TABLE dbo.InventoryMovement WITH CHECK CHECK CONSTRAINT CK_InventoryMovement_Rule1;'},
        @{Name='zero_adjustment_allowed';Error=51733;Change="ALTER TABLE dbo.InventoryMovement DROP CONSTRAINT CK_InventoryMovement_Rule1; ALTER TABLE dbo.InventoryMovement WITH CHECK ADD CONSTRAINT CK_InventoryMovement_Rule1 CHECK $weakCheck;";Restore="ALTER TABLE dbo.InventoryMovement DROP CONSTRAINT CK_InventoryMovement_Rule1; $restoreCheck"},
        @{Name='sales_view_all_zero';Error=51731;Change='CREATE OR ALTER VIEW dbo.vw_ProductSales AS SELECT ProductID,ProductName,CONVERT(int,0) AS SoldQty,CONVERT(decimal(12,2),0) AS SalesAmount FROM dbo.Product;';Restore=$salesView},
        @{Name='pending_detail_same_total';Error=51731;Change="UPDATE dbo.SalesOrderItem SET Quantity=1,DealUnitPrice=11.00 WHERE SalesItemID='SI03'; UPDATE dbo.InventoryReservation SET ReservedQty=1 WHERE ReservationID='R03';";Restore="UPDATE dbo.SalesOrderItem SET Quantity=2,DealUnitPrice=5.50 WHERE SalesItemID='SI03'; UPDATE dbo.InventoryReservation SET ReservedQty=2 WHERE ReservationID='R03';"},
        @{Name='inventory_view_wrong_available';Error=51731;Change=$badInventoryView;Restore=$inventoryView},
        @{Name='order_view_wrong_quantity';Error=51731;Change=$badOrderView;Restore=$orderView},
        @{Name='missing_business_snapshot';Error=51729;Change='DROP TABLE week6_baseline.ProductSales;';Restore='SELECT * INTO week6_baseline.ProductSales FROM dbo.vw_ProductSales;'}
    )
    foreach($case in $cases) {
        $actual=0
        try {
            Execute-Statement $case.Change
            try { Execute-Statement $regression }
            catch {
                $exception=$_.Exception
                while($exception -and $exception -isnot [System.Data.SqlClient.SqlException]) { $exception=$exception.InnerException }
                if(-not $exception) { throw }
                $actual=$exception.Number
            }
        } finally {
            Execute-Statement 'IF XACT_STATE()<>0 ROLLBACK TRANSACTION;'
            Execute-Statement $case.Restore
            # Assertions may leave temporary tables, so use a fresh session next time.
            $connection.Close(); $connection.Open()
        }
        if($actual -ne $case.Error) { throw "Mutation $($case.Name): expected $($case.Error), got $actual." }
        $evidence.Cases+= [ordered]@{CaseName=$case.Name;ExpectedError=$case.Error;ActualError=$actual;Result='PASS'}
        Write-Output "REJECTION_PASS $($case.Name): $actual"
    }
    if((Get-DataHashes) -ne $hashBefore) { throw 'Data or saved baseline changed after mutation restoration.' }
    $data=Execute-Sql $regression
    try {
        foreach($table in $data.Tables) {
            foreach($row in $table.Rows) {
                $item=[ordered]@{}
                foreach($column in $table.Columns) { $item[$column.ColumnName]= if($row[$column] -is [DBNull]) { $null } else { $row[$column] } }
                if($table.Columns.Contains('BeforeValue')) { $evidence.BeforeExpectedActual+=$item }
                elseif($table.Columns.Contains('RemovedOrChangedRows')) { $evidence.Comparison+=$item }
                elseif($table.Columns.Contains('CaseName')) { $evidence.WriteAndRoleCases+=$item }
                elseif($table.Columns.Contains('Result') -and $row.Result -eq 'W6_REGRESSION_PASS') { $evidence.Final+=$item }
            }
        }
    } finally { $data.Dispose() }
    if($evidence.Final.Count -ne 1) { throw 'Final restored regression did not report PASS.' }
    $evidence['DataAndBaselineRestored']=$true
    $resultDir=Join-Path $root 'output/week6'
    [void][IO.Directory]::CreateDirectory($resultDir)
    $json=ConvertTo-Json -InputObject $evidence -Depth 8
    [IO.File]::WriteAllText((Join-Path $resultDir ("validation-$Database.json")),$json,[Text.UTF8Encoding]::new($false))
    Write-Output 'VALIDATOR_REGRESSION_PASS: 9 mutations rejected; data and baseline restored; final regression passed.'
} finally { $connection.Dispose() }
