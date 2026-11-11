-- Reinstallable on a Week10 database. Audit rows have no business foreign keys:
-- deleting an unreferenced inventory batch must not erase its history.
SET NOCOUNT ON;
IF COL_LENGTH('dbo.SalesOrder','DiscountRate') IS NULL
    THROW 51800,'Install week10 before week11.',1;
IF OBJECT_ID('dbo.InventoryAudit','U') IS NULL
BEGIN
    CREATE TABLE dbo.InventoryAudit(
        AuditID bigint IDENTITY PRIMARY KEY,
        BatchID varchar(12) NOT NULL,
        ProductID varchar(12) NOT NULL,
        BeforeQty int NULL,
        AfterQty int NULL,
        QuantityDelta bigint NOT NULL,
        BeforeStatus nvarchar(10) NULL,
        AfterStatus nvarchar(10) NULL,
        OperationType varchar(6) NOT NULL CHECK(OperationType IN('INSERT','UPDATE','DELETE')),
        OperatorID varchar(12) NULL,
        ActorType varchar(8) NOT NULL CHECK(ActorType IN('EMPLOYEE','SQL')),
        OccurredAt datetime2(7) NOT NULL
    );
END;
GO
CREATE OR ALTER TRIGGER dbo.tr_InventoryAudit ON dbo.InventoryBatch
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    IF ROWCOUNT_BIG()=0 RETURN;
    SET NOCOUNT ON;
    -- A batch identity/source is historical data, not an editable attribute.
    IF EXISTS(SELECT 1 FROM deleted) AND EXISTS(SELECT 1 FROM inserted)
        AND (UPDATE(BatchID) OR UPDATE(PurchaseItemID))
        THROW 51811,'Inventory batch identity and purchase source are immutable.',1;
    IF EXISTS(SELECT 1 FROM inserted b WHERE b.OnHandQty<
        COALESCE((SELECT SUM(CONVERT(bigint,ReservedQty)) FROM dbo.InventoryReservation
            WHERE BatchID=b.BatchID AND ReservationStatus=N'有效'),0))
        THROW 51811,'Inventory cannot be below active reservations.',1;
    INSERT dbo.InventoryAudit(BatchID,ProductID,BeforeQty,AfterQty,QuantityDelta,
        BeforeStatus,AfterStatus,OperationType,OperatorID,ActorType,OccurredAt)
    SELECT COALESCE(i.BatchID,d.BatchID),p.ProductID,d.OnHandQty,i.OnHandQty,
        CONVERT(bigint,COALESCE(i.OnHandQty,0))-COALESCE(d.OnHandQty,0),
        d.BatchStatus,i.BatchStatus,
        CASE WHEN d.BatchID IS NULL THEN 'INSERT' WHEN i.BatchID IS NULL THEN 'DELETE' ELSE 'UPDATE' END,
        CONVERT(varchar(12),SESSION_CONTEXT(N'OperatorID')),
        CASE WHEN SESSION_CONTEXT(N'OperatorID') IS NULL THEN 'SQL' ELSE 'EMPLOYEE' END,SYSDATETIME()
    FROM inserted i FULL JOIN deleted d ON d.BatchID=i.BatchID
    JOIN dbo.PurchaseOrderItem p ON p.PurchaseItemID=COALESCE(i.PurchaseItemID,d.PurchaseItemID)
    WHERE i.BatchID IS NULL OR d.BatchID IS NULL OR i.OnHandQty<>d.OnHandQty
        OR i.BatchStatus<>d.BatchStatus OR i.ExpiryDate<>d.ExpiryDate
        OR i.ProductionDate<>d.ProductionDate OR i.SupplierBatchNo<>d.SupplierBatchNo
        OR i.ReceivedAt<>d.ReceivedAt;
END;
GO
CREATE OR ALTER TRIGGER dbo.tr_OrderCompletion ON dbo.SalesOrder
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    IF ROWCOUNT_BIG()=0 RETURN;
    SET NOCOUNT ON;
    -- Completed financial/status snapshots are immutable; no-op writes to the
    -- completion status are also rejected as repeated completion attempts.
    IF EXISTS(SELECT 1 FROM deleted WHERE OrderStatus=N'已完成')
        AND (UPDATE(OrderStatus) OR UPDATE(CompletedAt) OR UPDATE(TotalAmount)
            OR UPDATE(DiscountRate) OR UPDATE(DiscountAmount)
            OR NOT EXISTS(SELECT 1 FROM inserted))
        THROW 51812,'Completed orders cannot be completed again, reversed or deleted.',1;
    IF NOT EXISTS(SELECT 1 FROM inserted WHERE OrderStatus=N'已完成') RETURN;
    IF EXISTS(SELECT 1 FROM inserted i LEFT JOIN deleted d ON d.SalesOrderID=i.SalesOrderID
        WHERE i.OrderStatus=N'已完成' AND (d.SalesOrderID IS NULL OR d.OrderStatus<>N'待出库'))
        THROW 51812,'Completion must transition from awaiting shipment.',1;
    IF EXISTS(SELECT 1 FROM inserted o WHERE o.OrderStatus=N'已完成' AND
        (NOT EXISTS(SELECT 1 FROM dbo.SalesOrderItem WHERE SalesOrderID=o.SalesOrderID)
         OR o.TotalAmount<>(SELECT SUM(CONVERT(decimal(18,2),Quantity)*DealUnitPrice)
            FROM dbo.SalesOrderItem WHERE SalesOrderID=o.SalesOrderID)
         OR NOT EXISTS(SELECT 1 FROM dbo.PaymentRecord WHERE SalesOrderID=o.SalesOrderID
            AND PaymentStatus=N'成功' AND Amount=o.TotalAmount)
         OR o.DiscountAmount<>(SELECT SUM(CONVERT(decimal(18,2),Quantity)*
                (COALESCE(ListUnitPrice,DealUnitPrice)-DealUnitPrice))
            FROM dbo.SalesOrderItem WHERE SalesOrderID=o.SalesOrderID)))
        THROW 51812,'Completion requires consistent items, discount and successful payment.',1;
    IF EXISTS(SELECT 1 FROM inserted o JOIN dbo.SalesOrderItem i ON i.SalesOrderID=o.SalesOrderID
        LEFT JOIN dbo.Product p ON p.ProductID=i.ProductID
        OUTER APPLY(SELECT SUM(CONVERT(bigint,ReservedQty)) Qty FROM dbo.InventoryReservation
            WHERE SalesItemID=i.SalesItemID AND ReservationStatus=N'已转出库') shipped
        OUTER APPLY(SELECT -SUM(CONVERT(bigint,QuantityDelta)) Qty FROM dbo.InventoryMovement
            WHERE SalesItemID=i.SalesItemID AND MovementType=N'销售出库') movement
        WHERE o.OrderStatus=N'已完成' AND (p.ProductID IS NULL OR i.Quantity<=0 OR i.DealUnitPrice<=0
            OR i.DealUnitPrice<>COALESCE(i.ListUnitPrice,i.DealUnitPrice)
                -dbo.fn_DiscountAmount(COALESCE(i.ListUnitPrice,i.DealUnitPrice),o.DiscountRate)
            OR COALESCE(shipped.Qty,0)<>i.Quantity OR COALESCE(movement.Qty,0)<>i.Quantity
            OR EXISTS(SELECT 1 FROM dbo.InventoryReservation WHERE SalesItemID=i.SalesItemID AND ReservationStatus=N'有效')))
        THROW 51812,'Completion requires correct product, quantity, price and shipment.',1;
    IF EXISTS(SELECT 1 FROM inserted o JOIN dbo.SalesOrderItem i ON i.SalesOrderID=o.SalesOrderID
        JOIN dbo.InventoryReservation r ON r.SalesItemID=i.SalesItemID AND r.ReservationStatus=N'已转出库'
        JOIN dbo.InventoryBatch b ON b.BatchID=r.BatchID
        JOIN dbo.PurchaseOrderItem p ON p.PurchaseItemID=b.PurchaseItemID
        WHERE o.OrderStatus=N'已完成' AND (p.ProductID<>i.ProductID OR b.BatchStatus<>N'合格'
            OR b.ExpiryDate<=CONVERT(date,o.CompletedAt)
            OR b.OnHandQty<COALESCE((SELECT SUM(CONVERT(bigint,ReservedQty)) FROM dbo.InventoryReservation
                WHERE BatchID=b.BatchID AND ReservationStatus=N'有效'),0)
            OR b.OnHandQty<>COALESCE((SELECT SUM(CONVERT(bigint,QuantityDelta))
                FROM dbo.InventoryMovement WHERE BatchID=b.BatchID),0)
            OR (SELECT SUM(CONVERT(bigint,ReservedQty)) FROM dbo.InventoryReservation
                WHERE SalesItemID=i.SalesItemID AND BatchID=r.BatchID AND ReservationStatus=N'已转出库')
                <>COALESCE((SELECT -SUM(CONVERT(bigint,QuantityDelta)) FROM dbo.InventoryMovement
                    WHERE BatchID=r.BatchID AND SalesItemID=i.SalesItemID AND MovementType=N'销售出库'),0)))
        THROW 51812,'Completion inventory and shipment source are inconsistent.',1;
END;
GO
IF DATABASE_PRINCIPAL_ID(N'app_web_staff') IS NOT NULL
    GRANT SELECT ON dbo.InventoryAudit TO app_web_staff;
IF DATABASE_PRINCIPAL_ID(N'app_web_manager') IS NOT NULL
    GRANT SELECT ON dbo.InventoryAudit TO app_web_manager;
PRINT 'WEEK11_TRIGGERS_PASS';
