-- Keep existing categories as roots until a parent is assigned.
IF COL_LENGTH(N'dbo.ProductCategory',N'ParentCategoryID') IS NULL
    ALTER TABLE dbo.ProductCategory ADD ParentCategoryID varchar(12) NULL,
        CONSTRAINT FK_ProductCategory_Parent FOREIGN KEY(ParentCategoryID) REFERENCES dbo.ProductCategory(CategoryID),
        CONSTRAINT CK_ProductCategory_NotSelfParent CHECK(ParentCategoryID<>CategoryID);
GO

CREATE OR ALTER PROCEDURE dbo.sp_CategoryDescendants @CategoryID varchar(12)
AS
BEGIN
    SET NOCOUNT ON;
    -- IDs may contain '/', so match visited IDs using delimited hex tokens.
    ;WITH CategoryTree AS (
        SELECT CategoryID,ParentCategoryID,0 AS Depth,
            CONVERT(varchar(max),'/' + CategoryID) AS CategoryPath,
            CONVERT(varchar(max),'|' + CONVERT(varchar(24),CONVERT(varbinary(12),CategoryID),2) + '|') AS Visited
        FROM dbo.ProductCategory WHERE CategoryID=@CategoryID
        UNION ALL
        SELECT c.CategoryID,c.ParentCategoryID,t.Depth+1,
            CONVERT(varchar(max),t.CategoryPath + '/' + c.CategoryID),
            CONVERT(varchar(max),t.Visited + CONVERT(varchar(24),CONVERT(varbinary(12),c.CategoryID),2) + '|')
        FROM dbo.ProductCategory c
        JOIN CategoryTree t ON c.ParentCategoryID=t.CategoryID
        WHERE CHARINDEX('|' + CONVERT(varchar(24),CONVERT(varbinary(12),c.CategoryID),2) + '|',t.Visited)=0
    )
    SELECT CategoryID,ParentCategoryID,Depth,CategoryPath
    FROM CategoryTree WHERE Depth>0
    ORDER BY Depth,CategoryPath,CategoryID
    OPTION(MAXRECURSION 100);
END;
GO

-- After running test_data.sql in an isolated copy:
-- EXEC dbo.sp_CategoryDescendants 'W12ROOT';   -- W12A, W12B, W12LEAF (depth 1,1,2)
-- EXEC dbo.sp_CategoryDescendants 'W12A';     -- W12LEAF (depth 1)
-- EXEC dbo.sp_CategoryDescendants 'W12LEAF';  -- 0 rows
-- EXEC dbo.sp_CategoryDescendants 'W12NONE';  -- 0 rows
