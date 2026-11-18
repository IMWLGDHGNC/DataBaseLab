-- The installer runs after the earlier Web role grants.
GRANT EXECUTE ON dbo.sp_ReceivePurchase TO app_web_staff,app_web_manager;
REVOKE INSERT ON dbo.InventoryBatch FROM app_web_staff,app_web_manager;
REVOKE INSERT ON dbo.InventoryMovement FROM app_web_staff,app_web_manager;
REVOKE UPDATE (ReceivedBy,ReceivedAt,OrderStatus) ON dbo.PurchaseOrder FROM app_web_staff,app_web_manager;
