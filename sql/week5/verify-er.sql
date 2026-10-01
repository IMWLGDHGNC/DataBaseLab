-- Week 5: inspect the v0.1 model and demonstrate its boundaries.
-- Run after Run-Week4.ps1 in a dedicated reproduction database.
-- No schema change. Every write probe is rolled back, including on failure.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 THROW 51500, 'Run Week5 verification outside an existing transaction.', 1;
-- ER totals describe dbo business entities. The customer access binding is an
-- optional technical table in older v0.1 databases and present after the upgrade.
DECLARE @SecurityTableCount int=CASE
    WHEN OBJECT_ID(N'customer_security.CustomerPrincipal',N'U') IS NULL THEN 0 ELSE 1 END;
IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'dbo') AND is_ms_shipped=0)<>15
 OR (SELECT COUNT(*) FROM sys.columns c JOIN sys.tables t ON t.object_id=c.object_id WHERE t.schema_id=SCHEMA_ID(N'dbo') AND t.is_ms_shipped=0)<>107
 OR (SELECT COUNT(*) FROM sys.foreign_keys WHERE schema_id=SCHEMA_ID(N'dbo'))<>25
 OR (SELECT COUNT(*) FROM sys.key_constraints WHERE schema_id=SCHEMA_ID(N'dbo') AND type='PK')<>15
 OR (SELECT COUNT(*) FROM sys.views WHERE schema_id=SCHEMA_ID(N'dbo') AND is_ms_shipped=0)<>3
 OR (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped=0)<>15+@SecurityTableCount
 OR (SELECT COUNT(*) FROM sys.columns c JOIN sys.tables t ON t.object_id=c.object_id WHERE t.is_ms_shipped=0)<>107+2*@SecurityTableCount
 OR (SELECT COUNT(*) FROM sys.foreign_keys)<>25+@SecurityTableCount
 OR (SELECT COUNT(*) FROM sys.key_constraints WHERE type='PK')<>15+@SecurityTableCount
 OR (SELECT COUNT(*) FROM sys.views WHERE is_ms_shipped=0)<>3
    THROW 51501, 'Unexpected v0.1 catalog totals.', 1;
IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE is_disabled=1 OR is_not_trusted=1)
 OR EXISTS(SELECT 1 FROM sys.check_constraints WHERE is_disabled=1 OR is_not_trusted=1)
 OR NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE name='CK_OrderException_ResolutionNote')
    THROW 51502, 'Constraints are missing, disabled or untrusted.', 1;

-- BEGIN GENERATED MODEL CATALOG
CREATE TABLE #ExpectedColumns(TableName sysname COLLATE DATABASE_DEFAULT, ColumnName sysname COLLATE DATABASE_DEFAULT, SqlType varchar(40) COLLATE DATABASE_DEFAULT, Nullable bit);
INSERT #ExpectedColumns VALUES
(N'ProductCategory',N'CategoryID',N'VARCHAR(12)',0),
(N'ProductCategory',N'CategoryName',N'NVARCHAR(40)',0),
(N'ProductCategory',N'Description',N'NVARCHAR(200)',1),
(N'Product',N'ProductID',N'VARCHAR(12)',0),
(N'Product',N'CategoryID',N'VARCHAR(12)',0),
(N'Product',N'ProductName',N'NVARCHAR(100)',0),
(N'Product',N'Brand',N'NVARCHAR(60)',0),
(N'Product',N'Specification',N'NVARCHAR(60)',0),
(N'Product',N'SaleUnit',N'NVARCHAR(10)',0),
(N'Product',N'CurrentPrice',N'DECIMAL(10,2)',0),
(N'Product',N'SaleStatus',N'NVARCHAR(10)',0),
(N'Product',N'ReorderLevel',N'INT',0),
(N'Supplier',N'SupplierID',N'VARCHAR(12)',0),
(N'Supplier',N'SupplierName',N'NVARCHAR(100)',0),
(N'Supplier',N'ContactName',N'NVARCHAR(40)',1),
(N'Supplier',N'ContactPhone',N'VARCHAR(20)',1),
(N'Supplier',N'CooperationStatus',N'NVARCHAR(10)',0),
(N'Employee',N'EmployeeID',N'VARCHAR(12)',0),
(N'Employee',N'EmployeeName',N'NVARCHAR(40)',0),
(N'Employee',N'Position',N'NVARCHAR(20)',0),
(N'Employee',N'HireDate',N'DATE',0),
(N'Employee',N'MonthlySalary',N'DECIMAL(10,2)',0),
(N'Employee',N'ContactPhone',N'VARCHAR(20)',1),
(N'Employee',N'ActiveStatus',N'NVARCHAR(10)',0),
(N'Customer',N'CustomerID',N'VARCHAR(12)',0),
(N'Customer',N'AccountName',N'NVARCHAR(40)',0),
(N'Customer',N'CustomerName',N'NVARCHAR(40)',0),
(N'Customer',N'ContactPhone',N'VARCHAR(20)',1),
(N'Customer',N'IsMember',N'BIT',0),
(N'Customer',N'JoinedAt',N'DATETIME2(0)',1),
(N'Customer',N'PointsBalance',N'INT',0),
(N'Customer',N'ActiveStatus',N'NVARCHAR(10)',0),
(N'PurchaseOrder',N'PurchaseOrderID',N'VARCHAR(12)',0),
(N'PurchaseOrder',N'SupplierID',N'VARCHAR(12)',0),
(N'PurchaseOrder',N'CreatedBy',N'VARCHAR(12)',0),
(N'PurchaseOrder',N'CreatedAt',N'DATETIME2(0)',0),
(N'PurchaseOrder',N'ApprovedBy',N'VARCHAR(12)',1),
(N'PurchaseOrder',N'ApprovedAt',N'DATETIME2(0)',1),
(N'PurchaseOrder',N'ReceivedBy',N'VARCHAR(12)',1),
(N'PurchaseOrder',N'ReceivedAt',N'DATETIME2(0)',1),
(N'PurchaseOrder',N'OrderStatus',N'NVARCHAR(10)',0),
(N'PurchaseOrder',N'RejectionReason',N'NVARCHAR(200)',1),
(N'PurchaseOrderItem',N'PurchaseItemID',N'VARCHAR(12)',0),
(N'PurchaseOrderItem',N'PurchaseOrderID',N'VARCHAR(12)',0),
(N'PurchaseOrderItem',N'ProductID',N'VARCHAR(12)',0),
(N'PurchaseOrderItem',N'OrderedQty',N'INT',0),
(N'PurchaseOrderItem',N'UnitCost',N'DECIMAL(10,2)',0),
(N'InventoryBatch',N'BatchID',N'VARCHAR(12)',0),
(N'InventoryBatch',N'PurchaseItemID',N'VARCHAR(12)',0),
(N'InventoryBatch',N'SupplierBatchNo',N'VARCHAR(40)',0),
(N'InventoryBatch',N'ProductionDate',N'DATE',0),
(N'InventoryBatch',N'ExpiryDate',N'DATE',0),
(N'InventoryBatch',N'ReceivedAt',N'DATETIME2(0)',0),
(N'InventoryBatch',N'OnHandQty',N'INT',0),
(N'InventoryBatch',N'BatchStatus',N'NVARCHAR(10)',0),
(N'SalesOrder',N'SalesOrderID',N'VARCHAR(12)',0),
(N'SalesOrder',N'CustomerID',N'VARCHAR(12)',0),
(N'SalesOrder',N'CreatedAt',N'DATETIME2(0)',0),
(N'SalesOrder',N'OrderStatus',N'NVARCHAR(10)',0),
(N'SalesOrder',N'CompletedAt',N'DATETIME2(0)',1),
(N'SalesOrder',N'RecipientName',N'NVARCHAR(40)',0),
(N'SalesOrder',N'RecipientPhone',N'VARCHAR(20)',0),
(N'SalesOrder',N'ShippingAddress',N'NVARCHAR(200)',0),
(N'SalesOrder',N'TotalAmount',N'DECIMAL(10,2)',0),
(N'SalesOrderItem',N'SalesItemID',N'VARCHAR(12)',0),
(N'SalesOrderItem',N'SalesOrderID',N'VARCHAR(12)',0),
(N'SalesOrderItem',N'ProductID',N'VARCHAR(12)',0),
(N'SalesOrderItem',N'Quantity',N'INT',0),
(N'SalesOrderItem',N'DealUnitPrice',N'DECIMAL(10,2)',0),
(N'InventoryReservation',N'ReservationID',N'VARCHAR(12)',0),
(N'InventoryReservation',N'SalesItemID',N'VARCHAR(12)',0),
(N'InventoryReservation',N'BatchID',N'VARCHAR(12)',0),
(N'InventoryReservation',N'ReservedQty',N'INT',0),
(N'InventoryReservation',N'ReservationStatus',N'NVARCHAR(10)',0),
(N'InventoryReservation',N'ReservedAt',N'DATETIME2(0)',0),
(N'InventoryReservation',N'EndedAt',N'DATETIME2(0)',1),
(N'InventoryMovement',N'MovementID',N'VARCHAR(12)',0),
(N'InventoryMovement',N'BatchID',N'VARCHAR(12)',0),
(N'InventoryMovement',N'MovementType',N'NVARCHAR(10)',0),
(N'InventoryMovement',N'QuantityDelta',N'INT',0),
(N'InventoryMovement',N'PurchaseItemID',N'VARCHAR(12)',1),
(N'InventoryMovement',N'SalesItemID',N'VARCHAR(12)',1),
(N'InventoryMovement',N'Reason',N'NVARCHAR(200)',0),
(N'InventoryMovement',N'OperatorID',N'VARCHAR(12)',0),
(N'InventoryMovement',N'OccurredAt',N'DATETIME2(0)',0),
(N'PaymentRecord',N'PaymentID',N'VARCHAR(12)',0),
(N'PaymentRecord',N'SalesOrderID',N'VARCHAR(12)',0),
(N'PaymentRecord',N'MockTransactionNo',N'VARCHAR(40)',0),
(N'PaymentRecord',N'Amount',N'DECIMAL(10,2)',0),
(N'PaymentRecord',N'PaymentStatus',N'NVARCHAR(10)',0),
(N'PaymentRecord',N'ResultAt',N'DATETIME2(0)',0),
(N'PointsMovement',N'PointsMovementID',N'VARCHAR(12)',0),
(N'PointsMovement',N'CustomerID',N'VARCHAR(12)',0),
(N'PointsMovement',N'SalesOrderID',N'VARCHAR(12)',0),
(N'PointsMovement',N'PointsDelta',N'INT',0),
(N'PointsMovement',N'BasedAmount',N'DECIMAL(10,2)',0),
(N'PointsMovement',N'Reason',N'NVARCHAR(20)',0),
(N'PointsMovement',N'OccurredAt',N'DATETIME2(0)',0),
(N'OrderException',N'ExceptionID',N'VARCHAR(12)',0),
(N'OrderException',N'SalesOrderID',N'VARCHAR(12)',0),
(N'OrderException',N'BatchID',N'VARCHAR(12)',1),
(N'OrderException',N'ReasonCode',N'NVARCHAR(20)',0),
(N'OrderException',N'Description',N'NVARCHAR(200)',0),
(N'OrderException',N'HandlingStatus',N'NVARCHAR(10)',0),
(N'OrderException',N'HandlingNote',N'NVARCHAR(200)',1),
(N'OrderException',N'HandledBy',N'VARCHAR(12)',0),
(N'OrderException',N'RecordedAt',N'DATETIME2(0)',0);
CREATE TABLE #ExpectedKeys(KeyName sysname COLLATE DATABASE_DEFAULT, TableName sysname COLLATE DATABASE_DEFAULT, Kind char(2) COLLATE DATABASE_DEFAULT, ColumnName sysname COLLATE DATABASE_DEFAULT, Position int);
INSERT #ExpectedKeys VALUES
(N'PK_ProductCategory',N'ProductCategory',N'PK',N'CategoryID',1),
(N'UQ_ProductCategory_1',N'ProductCategory',N'UQ',N'CategoryName',1),
(N'PK_Product',N'Product',N'PK',N'ProductID',1),
(N'UQ_Product_1',N'Product',N'UQ',N'Brand',1),
(N'UQ_Product_1',N'Product',N'UQ',N'ProductName',2),
(N'UQ_Product_1',N'Product',N'UQ',N'Specification',3),
(N'UQ_Product_1',N'Product',N'UQ',N'SaleUnit',4),
(N'PK_Supplier',N'Supplier',N'PK',N'SupplierID',1),
(N'PK_Employee',N'Employee',N'PK',N'EmployeeID',1),
(N'PK_Customer',N'Customer',N'PK',N'CustomerID',1),
(N'UQ_Customer_1',N'Customer',N'UQ',N'AccountName',1),
(N'PK_PurchaseOrder',N'PurchaseOrder',N'PK',N'PurchaseOrderID',1),
(N'PK_PurchaseOrderItem',N'PurchaseOrderItem',N'PK',N'PurchaseItemID',1),
(N'UQ_PurchaseOrderItem_1',N'PurchaseOrderItem',N'UQ',N'PurchaseOrderID',1),
(N'UQ_PurchaseOrderItem_1',N'PurchaseOrderItem',N'UQ',N'ProductID',2),
(N'PK_InventoryBatch',N'InventoryBatch',N'PK',N'BatchID',1),
(N'UQ_InventoryBatch_1',N'InventoryBatch',N'UQ',N'PurchaseItemID',1),
(N'UQ_InventoryBatch_1',N'InventoryBatch',N'UQ',N'SupplierBatchNo',2),
(N'UQ_InventoryBatch_2',N'InventoryBatch',N'UQ',N'BatchID',1),
(N'UQ_InventoryBatch_2',N'InventoryBatch',N'UQ',N'PurchaseItemID',2),
(N'PK_SalesOrder',N'SalesOrder',N'PK',N'SalesOrderID',1),
(N'UQ_SalesOrder_1',N'SalesOrder',N'UQ',N'SalesOrderID',1),
(N'UQ_SalesOrder_1',N'SalesOrder',N'UQ',N'CustomerID',2),
(N'PK_SalesOrderItem',N'SalesOrderItem',N'PK',N'SalesItemID',1),
(N'UQ_SalesOrderItem_1',N'SalesOrderItem',N'UQ',N'SalesOrderID',1),
(N'UQ_SalesOrderItem_1',N'SalesOrderItem',N'UQ',N'ProductID',2),
(N'PK_InventoryReservation',N'InventoryReservation',N'PK',N'ReservationID',1),
(N'PK_InventoryMovement',N'InventoryMovement',N'PK',N'MovementID',1),
(N'PK_PaymentRecord',N'PaymentRecord',N'PK',N'PaymentID',1),
(N'UQ_PaymentRecord_1',N'PaymentRecord',N'UQ',N'MockTransactionNo',1),
(N'PK_PointsMovement',N'PointsMovement',N'PK',N'PointsMovementID',1),
(N'UQ_PointsMovement_1',N'PointsMovement',N'UQ',N'SalesOrderID',1),
(N'PK_OrderException',N'OrderException',N'PK',N'ExceptionID',1);
CREATE TABLE #ExpectedForeignKeys(KeyName sysname COLLATE DATABASE_DEFAULT, ChildTable sysname COLLATE DATABASE_DEFAULT, ChildColumn sysname COLLATE DATABASE_DEFAULT, ParentTable sysname COLLATE DATABASE_DEFAULT, ParentColumn sysname COLLATE DATABASE_DEFAULT, Position int);
INSERT #ExpectedForeignKeys VALUES
(N'FK_Product_CategoryID',N'Product',N'CategoryID',N'ProductCategory',N'CategoryID',1),
(N'FK_PurchaseOrder_SupplierID',N'PurchaseOrder',N'SupplierID',N'Supplier',N'SupplierID',1),
(N'FK_PurchaseOrder_CreatedBy',N'PurchaseOrder',N'CreatedBy',N'Employee',N'EmployeeID',1),
(N'FK_PurchaseOrder_ApprovedBy',N'PurchaseOrder',N'ApprovedBy',N'Employee',N'EmployeeID',1),
(N'FK_PurchaseOrder_ReceivedBy',N'PurchaseOrder',N'ReceivedBy',N'Employee',N'EmployeeID',1),
(N'FK_PurchaseOrderItem_PurchaseOrderID',N'PurchaseOrderItem',N'PurchaseOrderID',N'PurchaseOrder',N'PurchaseOrderID',1),
(N'FK_PurchaseOrderItem_ProductID',N'PurchaseOrderItem',N'ProductID',N'Product',N'ProductID',1),
(N'FK_InventoryBatch_PurchaseItemID',N'InventoryBatch',N'PurchaseItemID',N'PurchaseOrderItem',N'PurchaseItemID',1),
(N'FK_SalesOrder_CustomerID',N'SalesOrder',N'CustomerID',N'Customer',N'CustomerID',1),
(N'FK_SalesOrderItem_SalesOrderID',N'SalesOrderItem',N'SalesOrderID',N'SalesOrder',N'SalesOrderID',1),
(N'FK_SalesOrderItem_ProductID',N'SalesOrderItem',N'ProductID',N'Product',N'ProductID',1),
(N'FK_InventoryReservation_SalesItemID',N'InventoryReservation',N'SalesItemID',N'SalesOrderItem',N'SalesItemID',1),
(N'FK_InventoryReservation_BatchID',N'InventoryReservation',N'BatchID',N'InventoryBatch',N'BatchID',1),
(N'FK_InventoryMovement_BatchID',N'InventoryMovement',N'BatchID',N'InventoryBatch',N'BatchID',1),
(N'FK_InventoryMovement_PurchaseItemID',N'InventoryMovement',N'PurchaseItemID',N'PurchaseOrderItem',N'PurchaseItemID',1),
(N'FK_InventoryMovement_SalesItemID',N'InventoryMovement',N'SalesItemID',N'SalesOrderItem',N'SalesItemID',1),
(N'FK_InventoryMovement_OperatorID',N'InventoryMovement',N'OperatorID',N'Employee',N'EmployeeID',1),
(N'FK_PaymentRecord_SalesOrderID',N'PaymentRecord',N'SalesOrderID',N'SalesOrder',N'SalesOrderID',1),
(N'FK_PointsMovement_CustomerID',N'PointsMovement',N'CustomerID',N'Customer',N'CustomerID',1),
(N'FK_PointsMovement_SalesOrderID',N'PointsMovement',N'SalesOrderID',N'SalesOrder',N'SalesOrderID',1),
(N'FK_OrderException_SalesOrderID',N'OrderException',N'SalesOrderID',N'SalesOrder',N'SalesOrderID',1),
(N'FK_OrderException_BatchID',N'OrderException',N'BatchID',N'InventoryBatch',N'BatchID',1),
(N'FK_OrderException_HandledBy',N'OrderException',N'HandledBy',N'Employee',N'EmployeeID',1),
(N'FK_Movement_BatchPurchase',N'InventoryMovement',N'BatchID',N'InventoryBatch',N'BatchID',1),
(N'FK_Movement_BatchPurchase',N'InventoryMovement',N'PurchaseItemID',N'InventoryBatch',N'PurchaseItemID',2),
(N'FK_Points_OrderCustomer',N'PointsMovement',N'SalesOrderID',N'SalesOrder',N'SalesOrderID',1),
(N'FK_Points_OrderCustomer',N'PointsMovement',N'CustomerID',N'SalesOrder',N'CustomerID',2);
-- END GENERATED MODEL CATALOG

SELECT t.name COLLATE DATABASE_DEFAULT TableName,c.name COLLATE DATABASE_DEFAULT ColumnName,
 CONVERT(varchar(40),UPPER(ty.name)+CASE
 WHEN ty.name IN ('varchar','nvarchar') THEN '('+CONVERT(varchar(10),c.max_length/CASE WHEN ty.name='nvarchar' THEN 2 ELSE 1 END)+')'
 WHEN ty.name='decimal' THEN '('+CONVERT(varchar(10),c.precision)+','+CONVERT(varchar(10),c.scale)+')'
 WHEN ty.name='datetime2' THEN '('+CONVERT(varchar(10),c.scale)+')' ELSE '' END) COLLATE DATABASE_DEFAULT SqlType,c.is_nullable Nullable
INTO #ActualColumns FROM sys.tables t JOIN sys.columns c ON c.object_id=t.object_id
JOIN sys.types ty ON ty.user_type_id=c.user_type_id
WHERE t.schema_id=SCHEMA_ID(N'dbo') AND t.is_ms_shipped=0;
IF EXISTS(SELECT * FROM #ExpectedColumns EXCEPT SELECT * FROM #ActualColumns)
 OR EXISTS(SELECT * FROM #ActualColumns EXCEPT SELECT * FROM #ExpectedColumns)
    THROW 51510, 'Model column name, type or nullability mismatch.', 1;

SELECT k.name COLLATE DATABASE_DEFAULT KeyName,t.name COLLATE DATABASE_DEFAULT TableName,k.type COLLATE DATABASE_DEFAULT Kind,c.name COLLATE DATABASE_DEFAULT ColumnName,CONVERT(int,ic.key_ordinal) Position
INTO #ActualKeys FROM sys.key_constraints k JOIN sys.tables t ON t.object_id=k.parent_object_id
JOIN sys.index_columns ic ON ic.object_id=t.object_id AND ic.index_id=k.unique_index_id AND ic.key_ordinal>0
JOIN sys.columns c ON c.object_id=t.object_id AND c.column_id=ic.column_id
WHERE t.schema_id=SCHEMA_ID(N'dbo');
IF EXISTS(SELECT * FROM #ExpectedKeys EXCEPT SELECT * FROM #ActualKeys)
 OR EXISTS(SELECT * FROM #ActualKeys EXCEPT SELECT * FROM #ExpectedKeys)
 OR EXISTS(SELECT 1 FROM sys.indexes WHERE object_id IN (SELECT object_id FROM sys.tables WHERE schema_id=SCHEMA_ID(N'dbo')) AND (is_primary_key=1 OR is_unique_constraint=1) AND is_disabled=1)
    THROW 51511, 'Model primary or candidate key mismatch.', 1;

SELECT fk.name COLLATE DATABASE_DEFAULT KeyName,OBJECT_NAME(fk.parent_object_id) COLLATE DATABASE_DEFAULT ChildTable,pc.name COLLATE DATABASE_DEFAULT ChildColumn,
 OBJECT_NAME(fk.referenced_object_id) COLLATE DATABASE_DEFAULT ParentTable,rc.name COLLATE DATABASE_DEFAULT ParentColumn,fkc.constraint_column_id Position
INTO #ActualForeignKeys FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id=fk.object_id
JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id
JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id
WHERE fk.schema_id=SCHEMA_ID(N'dbo');
IF EXISTS(SELECT * FROM #ExpectedForeignKeys EXCEPT SELECT * FROM #ActualForeignKeys)
 OR EXISTS(SELECT * FROM #ActualForeignKeys EXCEPT SELECT * FROM #ExpectedForeignKeys)
 OR EXISTS(SELECT 1 FROM sys.foreign_keys WHERE schema_id=SCHEMA_ID(N'dbo') AND
 (delete_referential_action<>0 OR update_referential_action<>0 OR OBJECT_SCHEMA_NAME(referenced_object_id)<>N'dbo'))
    THROW 51512, 'Model foreign key pairing or action mismatch.', 1;
DROP TABLE #ExpectedColumns,#ActualColumns,#ExpectedKeys,#ActualKeys,#ExpectedForeignKeys,#ActualForeignKeys;

IF (SELECT COUNT(*) FROM sys.indexes i JOIN sys.tables t ON t.object_id=i.object_id
 WHERE t.schema_id=SCHEMA_ID(N'dbo') AND i.is_unique=1 AND i.is_primary_key=0 AND i.is_unique_constraint=0)<>1
 OR NOT EXISTS(SELECT 1 FROM sys.indexes i
 WHERE i.object_id=OBJECT_ID(N'dbo.PaymentRecord') AND i.name=N'UX_Payment_OneSuccess'
 AND i.is_unique=1 AND i.has_filter=1 AND i.is_disabled=0
 AND REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(i.filter_definition,'[',''),']',''),'(',''),')',''),' ','')=N'PaymentStatus=N''成功'''
 AND (SELECT COUNT(*) FROM sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=1
 AND EXISTS(SELECT 1 FROM sys.index_columns ic JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
 WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND c.name=N'SalesOrderID'))
    THROW 51513, 'Successful-payment filtered unique index mismatch.', 1;

SELECT 'CATALOG_PASS' Result, DB_NAME() DatabaseName,
 (SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'dbo') AND is_ms_shipped=0) TableCount,
 (SELECT COUNT(*) FROM sys.columns c JOIN sys.tables t ON t.object_id=c.object_id WHERE t.schema_id=SCHEMA_ID(N'dbo') AND t.is_ms_shipped=0) AttributeCount,
 (SELECT COUNT(*) FROM sys.foreign_keys WHERE schema_id=SCHEMA_ID(N'dbo')) ForeignKeyCount,
 @SecurityTableCount SecurityTableCount;
SELECT t.name TableName,c.column_id,c.name ColumnName,ty.name SqlType,c.max_length,c.precision,c.scale,c.is_nullable
FROM sys.tables t JOIN sys.columns c ON c.object_id=t.object_id
JOIN sys.types ty ON ty.user_type_id=c.user_type_id
WHERE t.schema_id=SCHEMA_ID(N'dbo') AND t.is_ms_shipped=0 ORDER BY t.name,c.column_id;
SELECT fk.name ForeignKeyName,OBJECT_NAME(fk.parent_object_id) ChildTable,
 pc.name ChildColumn,OBJECT_NAME(fk.referenced_object_id) ParentTable,
 rc.name ParentColumn,fkc.constraint_column_id PairOrder,pc.is_nullable
FROM sys.foreign_keys fk JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id=fk.object_id
JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id
JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id
WHERE fk.schema_id=SCHEMA_ID(N'dbo')
ORDER BY fk.name,fkc.constraint_column_id;

-- Trace the three demonstration paths, retaining the non-member order.
SELECT o.SalesOrderID,c.CustomerID,c.IsMember,i.SalesItemID,p.ProductID,
 i.Quantity,i.DealUnitPrice,o.OrderStatus,o.TotalAmount,
 pm.PointsDelta
FROM dbo.SalesOrder o JOIN dbo.Customer c ON c.CustomerID=o.CustomerID
JOIN dbo.SalesOrderItem i ON i.SalesOrderID=o.SalesOrderID
JOIN dbo.Product p ON p.ProductID=i.ProductID
LEFT JOIN dbo.PointsMovement pm ON pm.SalesOrderID=o.SalesOrderID
ORDER BY o.SalesOrderID,i.SalesItemID;
SELECT b.BatchID,p.ProductID,po.PurchaseOrderID,po.SupplierID,b.OnHandQty,
 COALESCE(r.ReservedQty,0) ActiveReservedQty,v.AvailableQty
FROM dbo.InventoryBatch b JOIN dbo.PurchaseOrderItem pi ON pi.PurchaseItemID=b.PurchaseItemID
JOIN dbo.PurchaseOrder po ON po.PurchaseOrderID=pi.PurchaseOrderID
JOIN dbo.Product p ON p.ProductID=pi.ProductID
JOIN dbo.vw_InventoryStatus v ON v.BatchID=b.BatchID
OUTER APPLY(SELECT SUM(ReservedQty) ReservedQty FROM dbo.InventoryReservation r
 WHERE r.BatchID=b.BatchID AND r.ReservationStatus=N'有效') r
ORDER BY b.BatchID;

CREATE TABLE #ProbeResults(CaseName varchar(60), ExpectedError int, ActualError int);
DECLARE @Case int=1,@Actual int,@Expected int,@Name varchar(60);
WHILE @Case<=9
BEGIN
    SET @Actual=0;
    SET @Expected=CASE WHEN @Case=6 THEN 2627 WHEN @Case=7 THEN 2601 ELSE 0 END;
    SET @Name=CASE @Case
      WHEN 1 THEN 'Q01_empty_sales_order_accepted'
      WHEN 2 THEN 'Q01_empty_purchase_order_accepted'
      WHEN 3 THEN 'Q03_stock_balance_mismatch_accepted'
      WHEN 4 THEN 'Q04_cross_product_reservation_accepted'
      WHEN 5 THEN 'Q05_payment_amount_mismatch_accepted'
      WHEN 6 THEN 'Q02_duplicate_order_product_rejected'
      WHEN 7 THEN 'R31_second_successful_payment_rejected'
      WHEN 8 THEN 'R18_multiple_failed_payments_accepted'
      WHEN 9 THEN 'R12_repeat_reservation_event_accepted' END;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF @Case=1 INSERT dbo.SalesOrder(SalesOrderID,CustomerID,CreatedAt,RecipientName,RecipientPhone,ShippingAddress,TotalAmount)
          VALUES('W5EMPTY','C02','20260917',N'演示', '13800000000',N'演示地址',1);
        IF @Case=2 INSERT dbo.PurchaseOrder(PurchaseOrderID,SupplierID,CreatedBy,CreatedAt)
          VALUES('W5EMPTY','SUP00','P02','20260917');
        IF @Case=3 BEGIN
          UPDATE dbo.InventoryBatch SET OnHandQty=OnHandQty+1 WHERE BatchID='B00';
          IF @@ROWCOUNT<>1 THROW 51503, 'Stock probe missed row.', 1;
        END;
        IF @Case=4 INSERT dbo.InventoryReservation(ReservationID,SalesItemID,BatchID,ReservedQty,ReservedAt)
          VALUES('W5WRONG','SI00','B02',1,'20260917');
        IF @Case=5 BEGIN
          UPDATE dbo.PaymentRecord SET Amount=1 WHERE PaymentID='PAY02';
          IF @@ROWCOUNT<>1 THROW 51504, 'Payment probe missed row.', 1;
        END;
        IF @Case=6 INSERT dbo.SalesOrderItem(SalesItemID,SalesOrderID,ProductID,Quantity,DealUnitPrice)
          VALUES('W5DUP','ST00','S01',1,4.40);
        IF @Case=7 INSERT dbo.PaymentRecord(PaymentID,SalesOrderID,MockTransactionNo,Amount,PaymentStatus,ResultAt)
          VALUES('W5SUCCESS','ST02','W5-SUCCESS',11,N'成功','2026-09-17T17:06:00');
        IF @Case=8 INSERT dbo.PaymentRecord(PaymentID,SalesOrderID,MockTransactionNo,Amount,PaymentStatus,ResultAt)
          VALUES('W5FAIL1','ST02','W5-FAIL1',11,N'失败','2026-09-17T17:01:00'),
                ('W5FAIL2','ST02','W5-FAIL2',11,N'失败','2026-09-17T17:02:00');
        IF @Case=9 INSERT dbo.InventoryReservation(ReservationID,SalesItemID,BatchID,ReservedQty,ReservationStatus,ReservedAt,EndedAt)
          VALUES('W5REPEAT','SI03','B01',2,N'已释放','2026-09-17T16:59:00','2026-09-17T17:00:00');
        ROLLBACK TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @Actual=ERROR_NUMBER();
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    END CATCH;
    INSERT #ProbeResults VALUES(@Name,@Expected,@Actual);
    SET @Case+=1;
END;
SELECT *,CASE WHEN ExpectedError=ActualError THEN 'PASS' ELSE 'FAIL' END Result
FROM #ProbeResults ORDER BY CaseName;
IF EXISTS(SELECT 1 FROM #ProbeResults WHERE ExpectedError<>ActualError)
    THROW 51505, 'ER boundary probe did not match the documented v0.1 behavior.', 1;
SELECT 'ER_BOUNDARY_PASS' Result,COUNT(*) CaseCount FROM #ProbeResults;
DROP TABLE #ProbeResults;
SELECT 'WEEK5_ER_PASS' Result;
