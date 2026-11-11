-- Apply once to a migrated v1.0 database; historical orders retain zero discount.
SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF COL_LENGTH('dbo.InventoryMovement','PurchaseItemID') IS NOT NULL
    THROW 51800, 'Apply the week6 v1.0 migration first.', 1;
IF COL_LENGTH('dbo.SalesOrder','DiscountRate') IS NOT NULL
    THROW 51800, 'Week10 migration already applied.', 1;
ALTER TABLE dbo.SalesOrder ADD
    DiscountRate decimal(5,4) NOT NULL CONSTRAINT DF_Order_DiscountRate DEFAULT(0),
    DiscountAmount decimal(10,2) NOT NULL CONSTRAINT DF_Order_DiscountAmount DEFAULT(0);
-- NULL means a legacy caller supplied an undiscounted DealUnitPrice. New Web
-- writes supply ListUnitPrice explicitly; sp_PriceOrder also snapshots legacy rows.
ALTER TABLE dbo.SalesOrderItem ADD ListUnitPrice decimal(10,2) NULL;
EXEC(N'UPDATE dbo.SalesOrderItem SET ListUnitPrice=DealUnitPrice;
ALTER TABLE dbo.SalesOrder ADD CONSTRAINT CK_Order_Discount CHECK
 (DiscountRate>=0 AND DiscountRate<1 AND DiscountAmount>=0);
ALTER TABLE dbo.SalesOrderItem ADD CONSTRAINT CK_Item_ListPrice CHECK
 (ListUnitPrice IS NULL OR ListUnitPrice>0);');
COMMIT;
PRINT 'WEEK10_MIGRATION_PASS';
