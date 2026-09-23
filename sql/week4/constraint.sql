-- Week 3 created the PK, FK, UNIQUE, CHECK, DEFAULT, and NOT NULL baseline.
-- Add a rule for resolved exceptions, then test both acceptance and rejection.
SET NOCOUNT ON;
ALTER TABLE dbo.OrderException WITH CHECK ADD CONSTRAINT CK_OrderException_ResolutionNote
CHECK (HandlingStatus<>N'已解决' OR
       (HandlingNote IS NOT NULL AND LEN(LTRIM(RTRIM(HandlingNote)))>0));

IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name='CK_OrderException_ResolutionNote'
             AND (is_disabled=1 OR is_not_trusted=1))
    THROW 51420,'New CHECK is disabled or untrusted.',1;

CREATE TABLE #ConstraintResults (CaseName varchar(50),ExpectedError int,ActualError int);
-- Positive case: valid resolution, rolled back so the seed remains intact.
BEGIN TRANSACTION;
UPDATE dbo.OrderException SET HandlingStatus=N'已解决',HandlingNote=N'已核实并处理'
WHERE ExceptionID='EX00';
IF @@ROWCOUNT<>1 THROW 51421,'Positive constraint case missed its target.',1;
ROLLBACK TRANSACTION;
INSERT #ConstraintResults VALUES('valid_resolution',0,0);

DECLARE @Actual int=0;
BEGIN TRY
    UPDATE dbo.OrderException SET HandlingStatus=N'已解决',HandlingNote=NULL
    WHERE ExceptionID='EX00';
END TRY
BEGIN CATCH
    SET @Actual=ERROR_NUMBER();
END CATCH;
INSERT #ConstraintResults VALUES('missing_resolution_note',547,@Actual);

SET @Actual=0;
BEGIN TRY
    UPDATE dbo.Product SET CategoryID='MISSING' WHERE ProductID='S00';
END TRY
BEGIN CATCH
    SET @Actual=ERROR_NUMBER();
END CATCH;
INSERT #ConstraintResults VALUES('missing_category_fk',547,@Actual);

SET @Actual=0;
BEGIN TRY
    INSERT dbo.ProductCategory(CategoryID,CategoryName) VALUES('NEWCAT',N'饮品');
END TRY
BEGIN CATCH
    SET @Actual=ERROR_NUMBER();
END CATCH;
INSERT #ConstraintResults VALUES('duplicate_category_name',2627,@Actual);

SET @Actual=0;
BEGIN TRY
    UPDATE dbo.Product SET ProductName=NULL WHERE ProductID='S00';
END TRY
BEGIN CATCH
    SET @Actual=ERROR_NUMBER();
END CATCH;
INSERT #ConstraintResults VALUES('required_product_name',515,@Actual);

-- DEFAULT is a database property, checked via a temporary transaction.
BEGIN TRANSACTION;
INSERT dbo.Product(ProductID,CategoryID,ProductName,Brand,Specification,SaleUnit,CurrentPrice)
VALUES('W4P','CAT00',N'默认值测试',N'测试',N'10g',N'包',1.00);
IF NOT EXISTS(SELECT 1 FROM dbo.Product
              WHERE ProductID='W4P' AND SaleStatus=N'在售' AND ReorderLevel=0)
    THROW 51422,'Defaults were not applied.',1;
ROLLBACK TRANSACTION;
INSERT #ConstraintResults VALUES('product_defaults',0,0);

SELECT *,CASE WHEN ExpectedError=ActualError THEN 'PASS' ELSE 'FAIL' END AS Result
FROM #ConstraintResults ORDER BY CaseName;
IF EXISTS(SELECT 1 FROM #ConstraintResults WHERE ExpectedError<>ActualError)
    THROW 51423,'Constraint case mismatch.',1;
SELECT 'CONSTRAINT_PASS' AS Result,COUNT(*) AS CaseCount FROM #ConstraintResults;
DROP TABLE #ConstraintResults;
