-- Week7 application principals. The deploy tool replaces the three identifier
-- placeholders with randomly named SQL logins; no password is stored here.
SET NOCOUNT ON;
IF DATABASE_PRINCIPAL_ID(N'app_web_customer') IS NULL CREATE ROLE app_web_customer;
IF DATABASE_PRINCIPAL_ID(N'app_web_staff') IS NULL CREATE ROLE app_web_staff;
IF DATABASE_PRINCIPAL_ID(N'app_web_manager') IS NULL CREATE ROLE app_web_manager;

CREATE USER [%CUSTOMER_LOGIN%] FOR LOGIN [%CUSTOMER_LOGIN%];
CREATE USER [%STAFF_LOGIN%] FOR LOGIN [%STAFF_LOGIN%];
CREATE USER [%MANAGER_LOGIN%] FOR LOGIN [%MANAGER_LOGIN%];
ALTER ROLE app_web_customer ADD MEMBER [%CUSTOMER_LOGIN%];
ALTER ROLE app_web_staff ADD MEMBER [%STAFF_LOGIN%];
ALTER ROLE app_web_manager ADD MEMBER [%MANAGER_LOGIN%];

-- The API's customer login is restricted to the tables needed by its service
-- transactions. Row ownership is also checked on every API request.
GRANT SELECT ON dbo.Product TO app_web_customer;
GRANT SELECT ON dbo.ProductCategory TO app_web_customer;
GRANT SELECT ON dbo.PurchaseOrderItem TO app_web_customer;
GRANT SELECT ON dbo.InventoryBatch TO app_web_customer;
GRANT SELECT ON dbo.InventoryReservation TO app_web_customer;
GRANT SELECT ON dbo.SalesOrder TO app_web_customer;
GRANT SELECT ON dbo.SalesOrderItem TO app_web_customer;
GRANT SELECT ON dbo.Customer TO app_web_customer;
GRANT SELECT ON dbo.PaymentRecord TO app_web_customer;
GRANT INSERT ON dbo.SalesOrder TO app_web_customer;
GRANT INSERT ON dbo.SalesOrderItem TO app_web_customer;
GRANT INSERT ON dbo.InventoryReservation TO app_web_customer;
GRANT INSERT ON dbo.PaymentRecord TO app_web_customer;
GRANT UPDATE (RecipientName,RecipientPhone,ShippingAddress,TotalAmount,OrderStatus)
    ON dbo.SalesOrder TO app_web_customer;
GRANT UPDATE (Quantity) ON dbo.SalesOrderItem TO app_web_customer;
GRANT UPDATE (ReservationStatus,EndedAt) ON dbo.InventoryReservation TO app_web_customer;
GRANT DELETE ON dbo.SalesOrderItem TO app_web_customer;
GRANT DELETE ON dbo.InventoryReservation TO app_web_customer;

GRANT SELECT ON dbo.Product TO app_web_staff,app_web_manager;
GRANT SELECT ON dbo.ProductCategory TO app_web_staff,app_web_manager;
GRANT SELECT ON dbo.PurchaseOrderItem TO app_web_staff,app_web_manager;
GRANT SELECT ON dbo.InventoryBatch TO app_web_staff,app_web_manager;
GRANT SELECT ON dbo.InventoryReservation TO app_web_staff,app_web_manager;
GRANT SELECT ON dbo.SalesOrder TO app_web_staff,app_web_manager;
GRANT SELECT ON dbo.SalesOrderItem TO app_web_staff,app_web_manager;
GRANT SELECT ON dbo.PaymentRecord TO app_web_staff,app_web_manager;
GRANT SELECT ON dbo.Customer TO app_web_staff,app_web_manager;
GRANT SELECT ON dbo.PointsMovement TO app_web_staff,app_web_manager;
GRANT SELECT ON dbo.InventoryMovement TO app_web_staff,app_web_manager;
GRANT UPDATE (OnHandQty) ON dbo.InventoryBatch TO app_web_staff,app_web_manager;
GRANT UPDATE (ReservationStatus,EndedAt) ON dbo.InventoryReservation TO app_web_staff,app_web_manager;
GRANT UPDATE (OrderStatus,CompletedAt) ON dbo.SalesOrder TO app_web_staff,app_web_manager;
GRANT UPDATE (PointsBalance) ON dbo.Customer TO app_web_staff,app_web_manager;
GRANT INSERT ON dbo.InventoryMovement TO app_web_staff,app_web_manager;
GRANT INSERT ON dbo.PointsMovement TO app_web_staff,app_web_manager;

GRANT INSERT ON dbo.Product TO app_web_manager;
GRANT UPDATE (CurrentPrice,SaleStatus,ReorderLevel) ON dbo.Product TO app_web_manager;
GRANT DELETE ON dbo.Product TO app_web_manager;

IF EXISTS (SELECT 1 FROM sys.database_role_members rm
           JOIN sys.database_principals p ON p.principal_id=rm.member_principal_id
           JOIN sys.database_principals r ON r.principal_id=rm.role_principal_id
           WHERE p.name IN (N'%CUSTOMER_LOGIN%',N'%STAFF_LOGIN%',N'%MANAGER_LOGIN%')
             AND r.name IN (N'db_owner',N'db_datareader',N'db_datawriter'))
    THROW 51700, 'Application principals must not have broad database roles.', 1;
PRINT 'WEEK7_PERMISSIONS_PASS';
