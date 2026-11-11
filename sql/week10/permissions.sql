-- Apply after week7 principals exist. Ownership chaining permits these narrow
-- operations without giving callers UPDATE access to discount snapshots.
IF DATABASE_PRINCIPAL_ID(N'app_web_customer') IS NULL CREATE ROLE app_web_customer;
IF DATABASE_PRINCIPAL_ID(N'app_web_staff') IS NULL CREATE ROLE app_web_staff;
IF DATABASE_PRINCIPAL_ID(N'app_web_manager') IS NULL CREATE ROLE app_web_manager;
GRANT EXECUTE ON dbo.sp_PriceOrder TO app_web_customer;
GRANT EXECUTE ON dbo.sp_AdjustInventory TO app_web_staff,app_web_manager;
GRANT EXECUTE ON dbo.sp_CompleteOrder TO app_web_staff,app_web_manager;
GRANT EXECUTE ON dbo.sp_SalesStatistics TO app_web_staff,app_web_manager;
GRANT EXECUTE ON dbo.sp_SelectReplenishment TO app_web_staff,app_web_manager;
GRANT SELECT ON dbo.fn_SalesSummary TO app_web_staff,app_web_manager;
GRANT UPDATE (ListUnitPrice) ON dbo.SalesOrderItem TO app_web_customer;
REVOKE UPDATE (OnHandQty) ON dbo.InventoryBatch FROM app_web_staff,app_web_manager;
REVOKE UPDATE (OrderStatus,CompletedAt) ON dbo.SalesOrder FROM app_web_staff,app_web_manager;
REVOKE UPDATE (PointsBalance) ON dbo.Customer FROM app_web_staff,app_web_manager;
REVOKE INSERT ON dbo.PointsMovement FROM app_web_staff,app_web_manager;
-- Existing insert grants cover the new ListUnitPrice column.
PRINT 'WEEK10_PERMISSIONS_PASS';
