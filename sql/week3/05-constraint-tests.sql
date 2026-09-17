-- Each deliberately invalid operation is isolated and rolled back.
SET NOCOUNT ON;
SET XACT_ABORT OFF;
CREATE TABLE #Cases(Name nvarchar(80),ExpectedError int,Statement nvarchar(max));
CREATE TABLE #Results(Name nvarchar(80),ExpectedError int,ActualError int,Result varchar(8));
INSERT #Cases VALUES
(N'negative_price',547,N'UPDATE dbo.Product SET CurrentPrice=-1 WHERE ProductID=''S00'';'),
(N'missing_category',547,N'UPDATE dbo.Product SET CategoryID=''MISSING'' WHERE ProductID=''S00'';'),
(N'duplicate_candidate_key',2627,N'INSERT dbo.ProductCategory VALUES(''TEST_CAT'',N''辣味零食'',NULL);'),
(N'null_required_name',515,N'UPDATE dbo.Product SET ProductName=NULL WHERE ProductID=''S00'';'),
(N'negative_stock',547,N'UPDATE dbo.InventoryBatch SET OnHandQty=-1 WHERE BatchID=''B00'';'),
(N'invalid_batch_dates',547,N'UPDATE dbo.InventoryBatch SET ExpiryDate=ProductionDate WHERE BatchID=''B00'';'),
(N'completed_without_time',547,N'UPDATE dbo.SalesOrder SET OrderStatus=N''已完成'' WHERE SalesOrderID=''ST02'';'),
(N'duplicate_successful_payment',2601,N'INSERT dbo.PaymentRecord VALUES(''TEST_PAY'',''ST00'',''TEST-TXN'',48,N''成功'',''20260916 10:06:00'');'),
(N'zero_points',547,N'UPDATE dbo.PointsMovement SET PointsDelta=0,BasedAmount=0.50 WHERE PointsMovementID=''PM00'';'),
(N'wrong_points_customer',547,N'UPDATE dbo.PointsMovement SET CustomerID=''C01'' WHERE PointsMovementID=''PM00'';'),
(N'wrong_purchase_same_product',547,N'INSERT dbo.PurchaseOrderItem VALUES(''TEST_PDI'',''PO01'',''S01'',1,2.20); INSERT dbo.InventoryMovement VALUES(''TEST_IM'',''B00'',N''采购入库'',1,''TEST_PDI'',NULL,N''错误采购来源测试'',''P00'',''20260916 09:00:00'');'),
(N'delete_referenced_product',547,N'DELETE dbo.Product WHERE ProductID=''S01'';');
DECLARE @Name nvarchar(80),@Expected int,@Statement nvarchar(max),@Actual int;
DECLARE tests CURSOR LOCAL FAST_FORWARD FOR SELECT Name,ExpectedError,Statement FROM #Cases ORDER BY Name;
OPEN tests;
FETCH NEXT FROM tests INTO @Name,@Expected,@Statement;
WHILE @@FETCH_STATUS=0
BEGIN
 SET @Actual=0;
 BEGIN TRANSACTION;
 BEGIN TRY
  EXEC sys.sp_executesql @Statement;
 END TRY
 BEGIN CATCH
  SET @Actual=ERROR_NUMBER();
 END CATCH;
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 INSERT #Results VALUES(@Name,@Expected,@Actual,CASE WHEN @Actual=@Expected THEN 'PASS' ELSE 'FAIL' END);
 FETCH NEXT FROM tests INTO @Name,@Expected,@Statement;
END;
CLOSE tests;
DEALLOCATE tests;
SELECT * FROM #Results ORDER BY Name;
IF EXISTS(SELECT 1 FROM #Results WHERE Result='FAIL') THROW 51300, 'A constraint test did not reject data as expected.', 1;
SELECT 'CONSTRAINT_TESTS_PASS' AS Result, COUNT(*) AS TestCount FROM #Results;
DROP TABLE #Cases;
DROP TABLE #Results;
SET XACT_ABORT ON;
