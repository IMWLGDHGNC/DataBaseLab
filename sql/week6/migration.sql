-- Week 6: migrate the reproducible Week 4 v0.1 sample database to v1.0.
-- Run only in the isolated DataBaseLab_Week6 staging database created by Run-Week6.ps1.
-- This migration changes metadata only; it must preserve all 15 business tables and 46 rows.
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'DataBaseLab_Week6' AND DB_NAME() NOT LIKE N'DataBaseLab[_]Week6[_]%'
    THROW 51600, 'Run this migration only in the isolated DataBaseLab_Week6 staging database.', 1;
IF OBJECT_ID(N'dbo.InventoryMovement', N'U') IS NULL
   OR COL_LENGTH(N'dbo.InventoryMovement', N'PurchaseItemID') IS NULL
    THROW 51601, 'Expected the un-migrated Week 4 v0.1 InventoryMovement shape.', 1;
IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'dbo') AND is_ms_shipped=0) <> 15
    THROW 51602, 'Expected exactly 15 dbo business tables before migration.', 1;
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE is_disabled=1 OR is_not_trusted=1)
   OR EXISTS (SELECT 1 FROM sys.check_constraints WHERE is_disabled=1 OR is_not_trusted=1)
    THROW 51614, 'Source constraints must be enabled and trusted before migration.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_InventoryMovement_PurchaseItemID' AND parent_object_id=OBJECT_ID(N'dbo.InventoryMovement'))
   OR NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name=N'FK_Movement_BatchPurchase' AND parent_object_id=OBJECT_ID(N'dbo.InventoryMovement'))
   OR NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name=N'CK_InventoryMovement_Rule1' AND parent_object_id=OBJECT_ID(N'dbo.InventoryMovement'))
   OR NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name=N'UQ_InventoryBatch_2' AND parent_object_id=OBJECT_ID(N'dbo.InventoryBatch'))
    THROW 51603, 'Expected v0.1 source and composite integrity constraints are missing.', 1;

DECLARE @RowsBefore bigint;
DECLARE @MovementRowsBefore bigint;
SELECT @RowsBefore =
    (SELECT COUNT_BIG(*) FROM dbo.ProductCategory) +
    (SELECT COUNT_BIG(*) FROM dbo.Product) +
    (SELECT COUNT_BIG(*) FROM dbo.Supplier) +
    (SELECT COUNT_BIG(*) FROM dbo.Employee) +
    (SELECT COUNT_BIG(*) FROM dbo.Customer) +
    (SELECT COUNT_BIG(*) FROM dbo.PurchaseOrder) +
    (SELECT COUNT_BIG(*) FROM dbo.PurchaseOrderItem) +
    (SELECT COUNT_BIG(*) FROM dbo.InventoryBatch) +
    (SELECT COUNT_BIG(*) FROM dbo.SalesOrder) +
    (SELECT COUNT_BIG(*) FROM dbo.SalesOrderItem) +
    (SELECT COUNT_BIG(*) FROM dbo.InventoryReservation) +
    (SELECT COUNT_BIG(*) FROM dbo.InventoryMovement) +
    (SELECT COUNT_BIG(*) FROM dbo.PaymentRecord) +
    (SELECT COUNT_BIG(*) FROM dbo.PointsMovement) +
    (SELECT COUNT_BIG(*) FROM dbo.OrderException);
SELECT @MovementRowsBefore=COUNT_BIG(*) FROM dbo.InventoryMovement;
IF @RowsBefore <> 46
    THROW 51604, 'Expected 46 v0.1 business rows; stop and inspect the staging database.', 1;

-- The composite FK already enforces this conditional dependency for inbound rows.
-- Check it explicitly before removing the duplicated source column and its constraints.
IF EXISTS (
    SELECT 1
    FROM dbo.InventoryMovement AS m
    LEFT JOIN dbo.InventoryBatch AS b ON b.BatchID=m.BatchID
    WHERE (m.MovementType=N'采购入库' AND
              (m.PurchaseItemID IS NULL OR b.BatchID IS NULL OR m.PurchaseItemID<>b.PurchaseItemID))
       OR (m.MovementType<>N'采购入库' AND m.PurchaseItemID IS NOT NULL)
)
    THROW 51605, 'Movement purchase source does not match its batch; no automatic repair was attempted.', 1;

-- Snapshot consistency checks protect intentional cross-table balance caches.
IF EXISTS (
    SELECT 1 FROM dbo.InventoryBatch AS b
    OUTER APPLY (SELECT SUM(m.QuantityDelta) AS NetQty FROM dbo.InventoryMovement AS m WHERE m.BatchID=b.BatchID) AS x
    WHERE b.OnHandQty<>COALESCE(x.NetQty,0)
)
    THROW 51606, 'Inventory balance differs from movement history.', 1;
IF EXISTS (
    SELECT 1 FROM dbo.SalesOrder AS o
    OUTER APPLY (SELECT SUM(i.Quantity*i.DealUnitPrice) AS Amount FROM dbo.SalesOrderItem AS i WHERE i.SalesOrderID=o.SalesOrderID) AS x
    WHERE x.Amount IS NULL OR o.TotalAmount<>x.Amount
)
    THROW 51607, 'Sales order total differs from its detail rows.', 1;
IF EXISTS (
    SELECT 1 FROM dbo.Customer AS c
    OUTER APPLY (SELECT SUM(p.PointsDelta) AS Balance FROM dbo.PointsMovement AS p WHERE p.CustomerID=c.CustomerID) AS x
    WHERE c.PointsBalance<>COALESCE(x.Balance,0)
)
    THROW 51608, 'Customer points balance differs from movement history.', 1;

-- Keep the complete movement facts and their recoverable purchase source in
-- this session. The two-way EXCEPT below checks actual row mapping after DDL,
-- not only aggregate counts.
SELECT m.MovementID,m.BatchID,m.MovementType,m.QuantityDelta,
       b.PurchaseItemID AS SourcePurchaseItemID,m.SalesItemID,
       m.Reason,m.OperatorID,m.OccurredAt
INTO #Week6MovementBefore
FROM dbo.InventoryMovement AS m
JOIN dbo.InventoryBatch AS b ON b.BatchID=m.BatchID;
IF (SELECT COUNT_BIG(*) FROM #Week6MovementBefore)<>@MovementRowsBefore
    THROW 51615, 'Movement snapshot is incomplete.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Remove the direct and composite references to the duplicated purchase source.
    ALTER TABLE dbo.InventoryMovement DROP CONSTRAINT FK_Movement_BatchPurchase;
    ALTER TABLE dbo.InventoryMovement DROP CONSTRAINT FK_InventoryMovement_PurchaseItemID;
    ALTER TABLE dbo.InventoryMovement DROP CONSTRAINT CK_InventoryMovement_Rule1;
    ALTER TABLE dbo.InventoryBatch DROP CONSTRAINT UQ_InventoryBatch_2;
    ALTER TABLE dbo.InventoryMovement DROP COLUMN PurchaseItemID;

    -- Retain the original movement type / signed quantity / sales source rules.
    ALTER TABLE dbo.InventoryMovement WITH CHECK ADD CONSTRAINT CK_InventoryMovement_Rule1
    CHECK (
        (MovementType=N'采购入库' AND QuantityDelta>0 AND SalesItemID IS NULL) OR
        (MovementType=N'销售出库' AND QuantityDelta<0 AND SalesItemID IS NOT NULL) OR
        (MovementType=N'盘点调整' AND QuantityDelta<>0 AND SalesItemID IS NULL) OR
        (MovementType=N'报损' AND QuantityDelta<0 AND SalesItemID IS NULL)
    );

    -- The former composite FK also prevented a referenced batch's purchase
    -- source from being rewritten while an inbound movement existed. Preserve
    -- that history rule after the duplicated movement column is removed.
    EXEC sys.sp_executesql N'
        CREATE OR ALTER TRIGGER dbo.TR_InventoryBatch_PurchaseSourceImmutable
        ON dbo.InventoryBatch AFTER UPDATE AS
        BEGIN
            SET NOCOUNT ON;
            IF UPDATE(PurchaseItemID) AND EXISTS (
                SELECT 1 FROM inserted AS i
                JOIN deleted AS d ON d.BatchID=i.BatchID
                WHERE i.PurchaseItemID<>d.PurchaseItemID
                  AND EXISTS (SELECT 1 FROM dbo.InventoryMovement AS m WHERE m.BatchID=i.BatchID)
            )
                THROW 51620, ''A batch with movement history cannot change its purchase source.'', 1;
        END';

    IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name=N'CK_InventoryMovement_Rule1' AND (is_disabled=1 OR is_not_trusted=1))
        THROW 51609, 'Replacement movement CHECK is disabled or untrusted.', 1;
    IF NOT EXISTS (SELECT 1 FROM sys.triggers WHERE name=N'TR_InventoryBatch_PurchaseSourceImmutable' AND parent_id=OBJECT_ID(N'dbo.InventoryBatch') AND is_disabled=0)
        THROW 51617, 'Purchase source immutability trigger is missing or disabled.', 1;
    IF COL_LENGTH(N'dbo.InventoryMovement', N'PurchaseItemID') IS NOT NULL
        THROW 51610, 'Duplicated purchase source column still exists.', 1;
    IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id=SCHEMA_ID(N'dbo') AND is_ms_shipped=0) <> 15
        THROW 51611, 'Business table count changed during migration.', 1;
    IF (SELECT
          (SELECT COUNT_BIG(*) FROM dbo.ProductCategory) +
          (SELECT COUNT_BIG(*) FROM dbo.Product) +
          (SELECT COUNT_BIG(*) FROM dbo.Supplier) +
          (SELECT COUNT_BIG(*) FROM dbo.Employee) +
          (SELECT COUNT_BIG(*) FROM dbo.Customer) +
          (SELECT COUNT_BIG(*) FROM dbo.PurchaseOrder) +
          (SELECT COUNT_BIG(*) FROM dbo.PurchaseOrderItem) +
          (SELECT COUNT_BIG(*) FROM dbo.InventoryBatch) +
          (SELECT COUNT_BIG(*) FROM dbo.SalesOrder) +
          (SELECT COUNT_BIG(*) FROM dbo.SalesOrderItem) +
          (SELECT COUNT_BIG(*) FROM dbo.InventoryReservation) +
          (SELECT COUNT_BIG(*) FROM dbo.InventoryMovement) +
          (SELECT COUNT_BIG(*) FROM dbo.PaymentRecord) +
          (SELECT COUNT_BIG(*) FROM dbo.PointsMovement) +
          (SELECT COUNT_BIG(*) FROM dbo.OrderException)) <> @RowsBefore
        THROW 51612, 'Business row count changed during metadata migration.', 1;
    IF (SELECT COUNT_BIG(*) FROM dbo.InventoryMovement) <> @MovementRowsBefore
        THROW 51613, 'Inventory movement rows changed during metadata migration.', 1;
    IF EXISTS (
        SELECT MovementID,BatchID,MovementType,QuantityDelta,SourcePurchaseItemID,
               SalesItemID,Reason,OperatorID,OccurredAt FROM #Week6MovementBefore
        EXCEPT
        SELECT m.MovementID,m.BatchID,m.MovementType,m.QuantityDelta,b.PurchaseItemID,
               m.SalesItemID,m.Reason,m.OperatorID,m.OccurredAt
        FROM dbo.InventoryMovement AS m
        JOIN dbo.InventoryBatch AS b ON b.BatchID=m.BatchID
    ) OR EXISTS (
        SELECT m.MovementID,m.BatchID,m.MovementType,m.QuantityDelta,b.PurchaseItemID,
               m.SalesItemID,m.Reason,m.OperatorID,m.OccurredAt
        FROM dbo.InventoryMovement AS m
        JOIN dbo.InventoryBatch AS b ON b.BatchID=m.BatchID
        EXCEPT
        SELECT MovementID,BatchID,MovementType,QuantityDelta,SourcePurchaseItemID,
               SalesItemID,Reason,OperatorID,OccurredAt FROM #Week6MovementBefore
    )
        THROW 51616, 'Movement facts or recovered purchase source changed.', 1;

    COMMIT TRANSACTION;
    SELECT N'W6_MIGRATION_PASS' AS Result, DB_NAME() AS DatabaseName,
           15 AS BusinessTableCount, @RowsBefore AS BusinessRowCount,
           @MovementRowsBefore AS InventoryMovementRows,
           N'InventoryMovement.PurchaseItemID removed; movement facts and source mappings match the snapshot; historical batch source is immutable' AS ChangeSummary;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
