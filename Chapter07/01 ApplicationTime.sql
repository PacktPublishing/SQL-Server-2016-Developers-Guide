--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide
--------	  Chapter 07 - Temporal Tables
--------            Application Time
--------------------------------------------------------------------


---------------------------------------------------------------
-- Demo table with application time
---------------------------------------------------------------

-- Creating a demo table
USE tempdb;
GO
SELECT OrderLineID AS id,
 StockItemID * (OrderLineID % 5 + 1) AS b,
 LastEditedBy + StockItemID * (OrderLineID % 5 + 1) AS e
INTO dbo.Intervals
FROM WideWorldImporters.Sales.OrderLines;
-- 231412 rows
GO
ALTER TABLE dbo.Intervals ADD CONSTRAINT PK_Intervals PRIMARY KEY(id);
CREATE INDEX idx_b ON dbo.Intervals(b) INCLUDE(e);
CREATE INDEX idx_e ON dbo.Intervals(e) INCLUDE(b);
GO

-- Checking the data
SELECT MIN(b), MAX(e)
FROM dbo.Intervals;
-- 1, 1155
GO

-- Date numbers table
CREATE TABLE dbo.DateNums
 (n INT NOT NULL PRIMARY KEY,
  d DATE NOT NULL);
GO
DECLARE @i AS INT = 1, 
 @d AS DATE = '20140701';
WHILE @i <= 1200
BEGIN
INSERT INTO dbo.DateNums
 (n, d)
SELECT @i, @d;
SET @i += 1;
SET @d = DATEADD(day,1,@d);
END;
GO

-- Giving intervals the context
SELECT i.id,
 i.b, d1.d AS dateB,
 i.e, d2.d AS dateE
FROM dbo.Intervals AS i
 INNER JOIN dbo.DateNums AS d1
  ON i.b = d1.n
 INNER JOIN dbo.DateNums AS d2
  ON i.e = d2.n
ORDER BY i.id;
GO

---------------------------------------------------------------
-- Optimizing a query for overlapping intervals
---------------------------------------------------------------

-- Intervals at the beginning or the end of the timeline 
-- Fast query
SET STATISTICS IO ON;
DECLARE @b AS INT = 10,
 @e AS INT = 30;
SELECT id, b, e
FROM dbo.Intervals
WHERE b <= @e
  AND e >= @b
OPTION (RECOMPILE);
GO
-- 36 logical reads

-- Intervals in the middle of the timeline 
-- Slow query
DECLARE @b AS INT = 570,
 @e AS INT = 590;
SELECT id, b, e
FROM dbo.Intervals
WHERE b <= @e
  AND e >= @b
OPTION (RECOMPILE);
GO
-- 111 logical reads

-- Intervals in the middle of the timeline 
-- Enhanced query
DECLARE @b AS INT = 570,
 @e AS INT = 590;
DECLARE @max AS INT = 20;
SELECT id, b, e
FROM dbo.Intervals
WHERE b <= @e AND b >= @b - @max
  AND e >= @b AND e <= @e + @max
OPTION (RECOMPILE);
-- 20 logical reads
GO

---------------------------------------------------------------
-- Clean up
---------------------------------------------------------------

DROP TABLE dbo.DateNums;
DROP TABLE dbo.Intervals;
GO
