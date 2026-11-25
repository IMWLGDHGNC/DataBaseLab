-- Run from a dedicated sample database, with both lab sessions closed or cleaned up.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() NOT LIKE N'DataBaseLab[_]Week6[_]Week10%'
    THROW 51930,'Use a dedicated Week10 sample database.',1;

IF SCHEMA_ID(N'week13_lab') IS NULL EXEC(N'CREATE SCHEMA week13_lab AUTHORIZATION dbo;');
IF OBJECT_ID(N'week13_lab.Stock',N'U') IS NULL
    CREATE TABLE week13_lab.Stock(
        ProductID char(1) NOT NULL PRIMARY KEY CLUSTERED,
        Qty int NOT NULL CHECK(Qty>=0)
    );
IF OBJECT_ID(N'week13_lab.Document',N'U') IS NULL
    CREATE TABLE week13_lab.Document(
        DocumentID varchar(10) NOT NULL PRIMARY KEY,
        Status varchar(10) NOT NULL
    );

BEGIN TRANSACTION;
DELETE FROM week13_lab.Stock;
DELETE FROM week13_lab.Document;
INSERT week13_lab.Stock VALUES ('P',10),('Q',8);
INSERT week13_lab.Document VALUES ('ORDER','Pending'),('RECEIPT','Approved');
COMMIT;
