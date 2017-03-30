---------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide    --------
------      Chapter 10 -  Columnstore Indexes     -------
---------------------------------------------------------

----------------------------------------------------
-- Section 1: Analytical Queries in SQL Server
----------------------------------------------------

-- Configure SQL Server to enable external scripts
USE WideWorldImportersDW;
GO

-- Bitmap filtered hash join
-- Show the execution plan
SELECT cu.[Customer Key] AS CustomerKey, cu.Customer,
  ci.[City Key] AS CityKey, ci.City, 
  ci.[State Province] AS StateProvince, ci.[Sales Territory] AS SalesTeritory,
  d.Date, d.[Calendar Month Label] AS CalendarMonth, 
  d.[Calendar Year] AS CalendarYear,
  s.[Stock Item Key] AS StockItemKey, s.[Stock Item] AS Product, s.Color,
  e.[Employee Key] AS EmployeeKey, e.Employee,
  f.Quantity, f.[Total Excluding Tax] AS TotalAmount, f.Profit
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS cu
    ON f.[Customer Key] = cu.[Customer Key]
  INNER JOIN Dimension.City AS ci
    ON f.[City Key] = ci.[City Key]
  INNER JOIN Dimension.[Stock Item] AS s
    ON f.[Stock Item Key] = s.[Stock Item Key]
  INNER JOIN Dimension.Employee AS e
    ON f.[Salesperson Key] = e.[Employee Key]
  INNER JOIN Dimension.Date AS d
    ON f.[Delivery Date Key] = d.Date;
-- 227981 rows


/*
 Clustered index
*/

-- Creating a heap
SELECT 1 * 1000000 + f.[Sale Key] AS SaleKey,
  cu.[Customer Key] AS CustomerKey, cu.Customer,
  ci.[City Key] AS CityKey, ci.City, 
  f.[Delivery Date Key] AS DateKey,
  s.[Stock Item Key] AS StockItemKey, s.[Stock Item] AS Product, 
  f.Quantity, f.[Total Excluding Tax] AS TotalAmount, f.Profit
INTO dbo.FactTest
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS cu
    ON f.[Customer Key] = cu.[Customer Key]
  INNER JOIN Dimension.City AS ci
    ON f.[City Key] = ci.[City Key]
  INNER JOIN Dimension.[Stock Item] AS s
    ON f.[Stock Item Key] = s.[Stock Item Key]
  INNER JOIN Dimension.Date AS d
    ON f.[Delivery Date Key] = d.Date;
GO

-- Range query
-- Show execution plan and statistics IO
SET STATISTICS IO ON;
-- All rows
SELECT *
FROM dbo.FactTest;
-- Date range
SELECT *
FROM dbo.FactTest
WHERE DateKey BETWEEN '20130201' AND '20130331';
-- Table scan in both cases - 5,893 reads
SET STATISTICS IO OFF;
GO

-- Clustered index
CREATE CLUSTERED INDEX CL_FactTest_DateKey
 ON dbo.FactTest(DateKey);
GO

-- Range query
-- Show execution plan and statistics IO
SET STATISTICS IO ON;
-- All rows
SELECT *
FROM dbo.FactTest;
-- Full scan - 6,088 reads
-- Date range
SELECT *
FROM dbo.FactTest
WHERE DateKey BETWEEN '20130201' AND '20130331';
-- Partial scan - 253 reads
SET STATISTICS IO OFF;
GO

/*
 Filtered index
*/

-- Selective customer
SELECT CustomerKey, COUNT(*)
FROM dbo.FactTest
GROUP BY CustomerKey
ORDER BY COUNT(*);
-- Customer 378 has only 242 rows


-- Show execution plan and statistics IO
SET STATISTICS IO ON;
-- All rows
SELECT *
FROM dbo.FactTest;
-- Customer 378 only
SELECT *
FROM dbo.FactTest
WHERE CustomerKey = 378;
-- Full scan in both cases - 6,088 reads
SET STATISTICS IO OFF;
GO

-- Add a filetered index
CREATE INDEX NCLF_FactTest_C378
 ON dbo.FactTest(CustomerKey)
 WHERE CustomerKey = 378;
GO

-- Repeat the queries
SET STATISTICS IO ON;
-- All rows
SELECT *
FROM dbo.FactTest;
-- Full scan - 6,088 reads
-- Customer 378 only
SELECT *
FROM dbo.FactTest
WHERE CustomerKey = 378;
-- Index seek & key lookup - 752 reads
SET STATISTICS IO OFF;
GO

-- Clean up
DROP INDEX NCLF_FactTest_C378
 ON dbo.FactTest;
GO

/*
 Indexed view
*/

SET STATISTICS IO ON;
-- Query with aggregates
SELECT StockItemKey, 
 SUM(TotalAmount) AS Sales,
 COUNT_BIG(*) AS NumberOfRows
FROM dbo.FactTest
GROUP BY StockItemKey;
-- Full scan - 6,682 reads
SET STATISTICS IO OFF;
GO

-- Create a view
CREATE VIEW dbo.SalesByProduct
WITH SCHEMABINDING AS
SELECT StockItemKey, 
 SUM(TotalAmount) AS Sales,
 COUNT_BIG(*) AS NumberOfRows
FROM dbo.FactTest
GROUP BY StockItemKey;
GO

-- Index the view
CREATE UNIQUE CLUSTERED INDEX CLU_SalesByProduct
 ON dbo.SalesByProduct (StockItemKey);
GO

SET STATISTICS IO ON;
-- Query with aggregates
SELECT StockItemKey, 
 SUM(TotalAmount) AS Sales,
 COUNT_BIG(*) AS NumberOfRows
FROM dbo.FactTest
GROUP BY StockItemKey;
-- Indexed view scan - 4 reads
SET STATISTICS IO OFF;
GO

-- Clean up
DROP VIEW dbo.SalesByProduct;
GO
-- Also turn off execution plan

/*
 Data compression
*/

-- Space used by the FactTest table
EXEC sys.sp_spaceused N'dbo.FactTest', @updateusage = N'TRUE';
GO
-- 49,288 KB reserved

-- Compress using row compression
ALTER TABLE dbo.FactTest 
 REBUILD WITH (DATA_COMPRESSION = ROW);
-- Re-check the space used by the InternetSales table
EXEC sys.sp_spaceused N'dbo.FactTest', @updateusage = N'TRUE';
GO
-- 25,864 KB reserved

-- Compress using page compression
ALTER TABLE dbo.FactTest 
 REBUILD WITH (DATA_COMPRESSION = PAGE);
-- Re-check the space used by the InternetSales table
EXEC sys.sp_spaceused N'dbo.FactTest', @updateusage = N'TRUE';
GO
-- 19,016 KB reserved

-- Clean up
ALTER TABLE dbo.FactTest 
 REBUILD WITH (DATA_COMPRESSION = NONE);
GO

/*
 Running totals
*/

-- Query with a self join
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
WITH SalesCTE AS
(
SELECT [Sale Key] AS SaleKey, Profit
FROM Fact.Sale
WHERE [Sale Key] <= 12000
)
SELECT S1.SaleKey,
 MIN(S1.Profit) AS CurrentProfit, 
 SUM(S2.Profit) AS RunningTotal
FROM SalesCTE AS S1
 INNER JOIN SalesCTE AS S2
  ON S1.SaleKey >= S2.SaleKey
GROUP BY S1.SaleKey
ORDER BY S1.SaleKey;
-- Execution time ~ 12s
-- CPU time ~ 72s
-- Worktable 817,584 reads
-- Sale 3,012 reads
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

-- Query with a window function
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
WITH SalesCTE AS
(
SELECT [Sale Key] AS SaleKey, Profit
FROM Fact.Sale
WHERE [Sale Key] <= 12000
)
SELECT SaleKey,
 Profit AS CurrentProfit, 
 SUM(Profit) 
   OVER(ORDER BY SaleKey
        ROWS BETWEEN UNBOUNDED PRECEDING
                 AND CURRENT ROW) AS RunningTotal
FROM SalesCTE
ORDER BY SaleKey;
-- Execution time ~ 0.14s
-- CPU time ~ 0.06s
-- Worktable 0 reads
-- Sale 331 reads
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO


----------------------------------------------------
-- Section 2: Batch Processing
----------------------------------------------------

-- Insert data into FactTest
DECLARE @i AS INT = 1;
WHILE @i < 10
BEGIN
SET @i += 1;
INSERT INTO dbo.FactTest
(SaleKey, CustomerKey, 
 Customer, CityKey, City,
 DateKey, StockItemKey,
 Product, Quantity,
 TotalAmount, Profit)
SELECT @i * 1000000 + f.[Sale Key] AS SaleKey,
  cu.[Customer Key] AS CustomerKey, cu.Customer,
  ci.[City Key] AS CityKey, ci.City, 
  f.[Delivery Date Key] AS DateKey,
  s.[Stock Item Key] AS StockItemKey, s.[Stock Item] AS Product, 
  f.Quantity, f.[Total Excluding Tax] AS TotalAmount, f.Profit
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS cu
    ON f.[Customer Key] = cu.[Customer Key]
  INNER JOIN Dimension.City AS ci
    ON f.[City Key] = ci.[City Key]
  INNER JOIN Dimension.[Stock Item] AS s
    ON f.[Stock Item Key] = s.[Stock Item Key]
  INNER JOIN Dimension.Date AS d
    ON f.[Delivery Date Key] = d.Date;
END;
GO
-- ~25S

-- Check the number of rows in the dbo.FactInternetSales table
SELECT COUNT(*), COUNT(*) / 10
FROM dbo.FactTest;
GO

-- Check the space used by the FactTest table
EXEC sys.sp_spaceused N'dbo.FactTest',
 @updateusage = N'TRUE';
-- 502,216 KB reserved
GO

-- Enforcing batch mode
-- Show execution plan
-- Simple query
SELECT f.StockItemKey,
 SUM(f.TotalAmount) AS Sales
FROM dbo.FactTest AS f
WHERE f.StockItemKey < 30
GROUP BY f.StockItemKey
ORDER BY f.StockItemKey;
-- Only row mode operators
GO

-- Create an empty NCCI
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_FactTest
ON dbo.FactTest
(SaleKey, CustomerKey, 
 Customer, CityKey, City,
 DateKey, StockItemKey,
 Product, Quantity,
 TotalAmount, Profit)
WHERE SaleKey = 0;
GO

-- Show execution plan
-- Simple query
SELECT f.StockItemKey,
 SUM(f.TotalAmount) AS Sales
FROM dbo.FactTest AS f
WHERE f.StockItemKey < 30
GROUP BY f.StockItemKey
ORDER BY f.StockItemKey;
-- Row and batch mode operators
GO


----------------------------------------------------
-- Section 3: Nonclusteres Columnstore Indexes
----------------------------------------------------

-- Drop the empty NCCI
DROP INDEX NCCI_FactTest
ON dbo.FactTest; 
GO

-- Checking the space used
EXEC sys.sp_spaceused N'dbo.FactTest', @updateusage = N'TRUE';
GO


-- Show execution plan
-- Set statistics on
SET STATISTICS IO ON;

-- Simple query
SELECT f.StockItemKey,
 SUM(f.TotalAmount) AS Sales
FROM dbo.FactTest AS f
WHERE f.StockItemKey < 30
GROUP BY f.StockItemKey
ORDER BY f.StockItemKey;
-- Full scan - 63,601
-- Only row mode operators

-- Complex query
SELECT f.SaleKey,
  f.CustomerKey, f.Customer, cu.[Buying Group],
  f.CityKey, f.City, ci.Country,
  f.DateKey, d.[Calendar Year],
  f.StockItemKey, f.Product, 
  f.Quantity, f.TotalAmount, f.Profit
FROM dbo.FactTest AS f
  INNER JOIN Dimension.Customer AS cu
    ON f.CustomerKey = cu.[Customer Key]
  INNER JOIN Dimension.City AS ci
    ON f.CityKey = ci.[City Key]
  INNER JOIN Dimension.[Stock Item] AS s
    ON f.StockItemKey = s.[Stock Item Key]
  INNER JOIN Dimension.Date AS d
    ON f.DateKey = d.Date;
-- Full scan - 62,575
-- Only row mode operators
-- No parallelism

-- Point query
SELECT CustomerKey, Profit
FROM dbo.FactTest
WHERE CustomerKey = 378;
-- Full scan - 63,623
-- Only row mode operators

SET STATISTICS IO OFF;
GO

-- Re-create the NCCI on full data
CREATE NONCLUSTERED COLUMNSTORE INDEX NCCI_FactTest
ON dbo.FactTest
(SaleKey, CustomerKey, 
 Customer, CityKey, City,
 DateKey, StockItemKey,
 Product, Quantity,
 TotalAmount, Profit);
GO

-- Re-check the space used by the FactTest table
EXEC sys.sp_spaceused N'dbo.FactTest',
 @updateusage = N'TRUE';
-- 529,808 KB reserved, 29,440 KB index size
GO

-- Queries that ignore NCCI
-- Show execution plan
-- Set statistics on
SET STATISTICS IO ON;

-- Simple query
SELECT f.StockItemKey,
 SUM(f.TotalAmount) AS Sales
FROM dbo.FactTest AS f
WHERE f.StockItemKey < 30
GROUP BY f.StockItemKey
ORDER BY f.StockItemKey
OPTION (ignore_nonclustered_columnstore_index);
-- Full scan - 63,601
-- Row mode operators only

-- Complex query
SELECT f.SaleKey,
  f.CustomerKey, f.Customer, cu.[Buying Group],
  f.CityKey, f.City, ci.Country,
  f.DateKey, d.[Calendar Year],
  f.StockItemKey, f.Product, 
  f.Quantity, f.TotalAmount, f.Profit
FROM dbo.FactTest AS f
  INNER JOIN Dimension.Customer AS cu
    ON f.CustomerKey = cu.[Customer Key]
  INNER JOIN Dimension.City AS ci
    ON f.CityKey = ci.[City Key]
  INNER JOIN Dimension.[Stock Item] AS s
    ON f.StockItemKey = s.[Stock Item Key]
  INNER JOIN Dimension.Date AS d
    ON f.DateKey = d.Date
OPTION (ignore_nonclustered_columnstore_index);
-- Full scan - 62,575
-- Row mode operators only
-- No parallelism

-- Point query
SELECT CustomerKey, Profit
FROM dbo.FactTest
WHERE CustomerKey = 378
OPTION (ignore_nonclustered_columnstore_index);
-- Full scan - 63,601
-- Only row mode operators

SET STATISTICS IO OFF;
GO

-- Queries that use NCCI
-- Show execution plan
-- Set statistics on
SET STATISTICS IO ON;

-- Simple query
SELECT f.StockItemKey,
 SUM(f.TotalAmount) AS Sales
FROM dbo.FactTest AS f
WHERE f.StockItemKey < 30
GROUP BY f.StockItemKey
ORDER BY f.StockItemKey;
-- Columnstore index scan - lob logical reads 2,001, segment reads 4
-- Row and batch mode operators 

-- How many segments?
SELECT ROW_NUMBER() OVER (ORDER BY s.column_id, s.segment_id) AS rn,
 COL_NAME(p.object_id, s.column_id) AS column_name,
 S.segment_id, s.row_count, 
 s.min_data_id, s.max_data_id,
 s.on_disk_size
FROM sys.column_store_segments AS s   
INNER JOIN sys.partitions AS p   
    ON s.hobt_id = p.hobt_id   
INNER JOIN sys.indexes AS i   
    ON p.object_id = i.object_id  
WHERE i.name = N'NCCI_FactTest'
ORDER BY s.column_id, s.segment_id; 
-- 48
 
-- Complex query
SELECT f.SaleKey,
  f.CustomerKey, f.Customer, cu.[Buying Group],
  f.CityKey, f.City, ci.Country,
  f.DateKey, d.[Calendar Year],
  f.StockItemKey, f.Product, 
  f.Quantity, f.TotalAmount, f.Profit
FROM dbo.FactTest AS f
  INNER JOIN Dimension.Customer AS cu
    ON f.CustomerKey = cu.[Customer Key]
  INNER JOIN Dimension.City AS ci
    ON f.CityKey = ci.[City Key]
  INNER JOIN Dimension.[Stock Item] AS s
    ON f.StockItemKey = s.[Stock Item Key]
  INNER JOIN Dimension.Date AS d
    ON f.DateKey = d.Date;
-- Columnstore index scan - lob logical reads 7,128, segment reads 4
-- Row and batch mode operators 
-- No parallelism

-- Point query
SELECT CustomerKey, Profit
FROM dbo.FactTest
WHERE CustomerKey = 378;
-- Columnstore index scan - lob logical reads 2,351, segment reads 4
-- Row and batch mode operators 

SET STATISTICS IO OFF;
GO

-- Complex query with a parallel plan
-- Set compatibility level to 2014
USE master;
GO
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 120;
GO
-- The complex query
USE WideWorldImportersDW;
SET STATISTICS IO ON;
SELECT f.SaleKey,
  f.CustomerKey, f.Customer, cu.[Buying Group],
  f.CityKey, f.City, ci.Country,
  f.DateKey, d.[Calendar Year],
  f.StockItemKey, f.Product, 
  f.Quantity, f.TotalAmount, f.Profit
FROM dbo.FactTest AS f
  INNER JOIN Dimension.Customer AS cu
    ON f.CustomerKey = cu.[Customer Key]
  INNER JOIN Dimension.City AS ci
    ON f.CityKey = ci.[City Key]
  INNER JOIN Dimension.[Stock Item] AS s
    ON f.StockItemKey = s.[Stock Item Key]
  INNER JOIN Dimension.Date AS d
    ON f.DateKey = d.Date;
-- Columnstore index scan - lob logical reads 7,128, segment reads 4
-- Row and batch mode operators 
-- Parallelism

SET STATISTICS IO OFF;
GO

-- Set compatibility level back to 2016
USE master;
GO
ALTER DATABASE WideWorldImportersDW SET COMPATIBILITY_LEVEL = 130;
GO


----------------------------------------------------
-- Section 4: Clustered Columnstore Indexes
----------------------------------------------------

USE WideWorldImportersDW;
-- Drop the NCCI
DROP INDEX NCCI_FactTest
  ON dbo.FactTest;
-- Drop the CI
DROP INDEX CL_FactTest_DateKey
  ON dbo.FactTest;
GO

-- Create a CCI
CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactTest
  ON dbo.FactTest;
GO

-- Re-check the space used by the FactTest table
EXEC sys.sp_spaceused N'dbo.FactTest',
 @updateusage = N'TRUE';
-- 24,008 KB reserved, 0 KB index size (data only)
GO

-- How many segments?
SELECT ROW_NUMBER() OVER (ORDER BY s.column_id, s.segment_id) AS rn,
 COL_NAME(p.object_id, s.column_id) AS column_name,
 S.segment_id, s.row_count, 
 s.min_data_id, s.max_data_id,
 s.on_disk_size
FROM sys.column_store_segments AS s   
INNER JOIN sys.partitions AS p   
    ON s.hobt_id = p.hobt_id   
INNER JOIN sys.indexes AS i   
    ON p.object_id = i.object_id  
WHERE i.name = N'CCI_FactTest'
ORDER BY s.column_id, s.segment_id;  
-- 44

-- Queries that use CCI
-- Show execution plan
-- Set statistics on
SET STATISTICS IO ON;

-- Simple query
SELECT f.StockItemKey,
 SUM(f.TotalAmount) AS Sales
FROM dbo.FactTest AS f
WHERE f.StockItemKey < 30
GROUP BY f.StockItemKey
ORDER BY f.StockItemKey;
-- Columnstore index scan - lob logical reads 82, segment reads 4
-- Row and batch mode operators 

-- Complex query
SELECT f.SaleKey,
  f.CustomerKey, f.Customer, cu.[Buying Group],
  f.CityKey, f.City, ci.Country,
  f.DateKey, d.[Calendar Year],
  f.StockItemKey, f.Product, 
  f.Quantity, f.TotalAmount, f.Profit
FROM dbo.FactTest AS f
  INNER JOIN Dimension.Customer AS cu
    ON f.CustomerKey = cu.[Customer Key]
  INNER JOIN Dimension.City AS ci
    ON f.CityKey = ci.[City Key]
  INNER JOIN Dimension.[Stock Item] AS s
    ON f.StockItemKey = s.[Stock Item Key]
  INNER JOIN Dimension.Date AS d
    ON f.DateKey = d.Date;
-- Columnstore index scan - lob logical reads 6,101, segment reads 4
-- Row and batch mode operators 
-- No parallelism

-- Point query
SELECT CustomerKey, Profit
FROM dbo.FactTest
WHERE CustomerKey = 378;
-- Columnstore index scan - lob logical reads 484, segment reads 4
-- Row and batch mode operators 

SET STATISTICS IO OFF;
GO

-- Archive compression
ALTER INDEX CCI_FactTest
 ON dbo.FactTest
 REBUILD WITH (DATA_COMPRESSION = COLUMNSTORE_ARCHIVE);
GO

-- Re-check the space used by the FactTest table
EXEC sys.sp_spaceused N'dbo.FactTest',
 @updateusage = N'TRUE';
-- 19,528 KB reserved, 0 KB index size (data only)
GO

-- Queries that use CCI
-- Show execution plan
-- Set statistics on
SET STATISTICS IO ON;

-- Simple query
SELECT f.StockItemKey,
 SUM(f.TotalAmount) AS Sales
FROM dbo.FactTest AS f
WHERE f.StockItemKey < 30
GROUP BY f.StockItemKey
ORDER BY f.StockItemKey;
-- Columnstore index scan - lob logical reads 23, segment reads 4
-- Row and batch mode operators 

-- Complex query
SELECT f.SaleKey,
  f.CustomerKey, f.Customer, cu.[Buying Group],
  f.CityKey, f.City, ci.Country,
  f.DateKey, d.[Calendar Year],
  f.StockItemKey, f.Product, 
  f.Quantity, f.TotalAmount, f.Profit
FROM dbo.FactTest AS f
  INNER JOIN Dimension.Customer AS cu
    ON f.CustomerKey = cu.[Customer Key]
  INNER JOIN Dimension.City AS ci
    ON f.CityKey = ci.[City Key]
  INNER JOIN Dimension.[Stock Item] AS s
    ON f.StockItemKey = s.[Stock Item Key]
  INNER JOIN Dimension.Date AS d
    ON f.DateKey = d.Date;
-- Columnstore index scan - lob logical reads 4,820, segment reads 4
-- Row and batch mode operators 
-- No parallelism

-- Point query
SELECT CustomerKey, Profit
FROM dbo.FactTest
WHERE CustomerKey = 378;
-- Columnstore index scan - lob logical reads 410, segment reads 4
-- Row and batch mode operators 

SET STATISTICS IO OFF;
GO

-- Add a NCI with included column
CREATE NONCLUSTERED INDEX NCI_FactTest_CustomerKey
 ON dbo.FactTest(CustomerKey)
 INCLUDE(Profit);
GO

-- Re-check the space used by the FactTest table
EXEC sys.sp_spaceused N'dbo.FactTest',
 @updateusage = N'TRUE';
-- 90,064 KB reserved, 70,192 KB index size
GO

-- Queries that use CCI and NCI
-- Show execution plan
-- Set statistics on
SET STATISTICS IO ON;

-- Simple query
SELECT f.StockItemKey,
 SUM(f.TotalAmount) AS Sales
FROM dbo.FactTest AS f
WHERE f.StockItemKey < 30
GROUP BY f.StockItemKey
ORDER BY f.StockItemKey;
-- Columnstore index scan - lob logical reads 23, segment reads 4
-- Row and batch mode operators 

-- Complex query
SELECT f.SaleKey,
  f.CustomerKey, f.Customer, cu.[Buying Group],
  f.CityKey, f.City, ci.Country,
  f.DateKey, d.[Calendar Year],
  f.StockItemKey, f.Product, 
  f.Quantity, f.TotalAmount, f.Profit
FROM dbo.FactTest AS f
  INNER JOIN Dimension.Customer AS cu
    ON f.CustomerKey = cu.[Customer Key]
  INNER JOIN Dimension.City AS ci
    ON f.CityKey = ci.[City Key]
  INNER JOIN Dimension.[Stock Item] AS s
    ON f.StockItemKey = s.[Stock Item Key]
  INNER JOIN Dimension.Date AS d
    ON f.DateKey = d.Date;
-- Columnstore index scan - lob logical reads 4,763, segment reads 4
-- Row and batch mode operators 
-- No parallelism

-- Point query
SELECT CustomerKey, Profit
FROM dbo.FactTest
WHERE CustomerKey = 378;
-- Index seek - logical reads 13
-- Row mode operators only

SET STATISTICS IO OFF;
GO

-- Drop the NCI index
DROP INDEX NCI_FactTest_CustomerKey
 ON dbo.FactTest;
GO

-- Check the status of the row segments
SELECT OBJECT_NAME(object_id) AS table_name,
 row_group_id, state, state_desc,
 total_rows, deleted_rows
FROM sys.dm_db_column_store_row_group_physical_stats
WHERE object_id = OBJECT_ID(N'dbo.FactTest')
ORDER BY row_group_id;
GO
-- All row groups compressed

-- Enforcing uniqueness
ALTER TABLE dbo.FactTest
 ADD CONSTRAINT U_SaleKey UNIQUE (SaleKey);
GO

-- Try to insert the same 75,993 rows into FactTest
INSERT INTO dbo.FactTest
(SaleKey, CustomerKey, 
 Customer, CityKey, City,
 DateKey, StockItemKey,
 Product, Quantity,
 TotalAmount, Profit)
SELECT 10 * 1000000 + f.[Sale Key] AS SaleKey,
  cu.[Customer Key] AS CustomerKey, cu.Customer,
  ci.[City Key] AS CityKey, ci.City, 
  f.[Delivery Date Key] AS DateKey,
  s.[Stock Item Key] AS StockItemKey, s.[Stock Item] AS Product, 
  f.Quantity, f.[Total Excluding Tax] AS TotalAmount, f.Profit
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS cu
    ON f.[Customer Key] = cu.[Customer Key]
  INNER JOIN Dimension.City AS ci
    ON f.[City Key] = ci.[City Key]
  INNER JOIN Dimension.[Stock Item] AS s
    ON f.[Stock Item Key] = s.[Stock Item Key]
  INNER JOIN Dimension.Date AS d
    ON f.[Delivery Date Key] = d.Date
WHERE f.[Sale Key] % 3 = 0;
GO
-- Error 2627

-- Check the status of the row segments
SELECT OBJECT_NAME(object_id) AS table_name,
 row_group_id, state, state_desc,
 total_rows, deleted_rows
FROM sys.dm_db_column_store_row_group_physical_stats
WHERE object_id = OBJECT_ID(N'dbo.FactTest')
ORDER BY row_group_id;
GO
-- A new open row group was added

-- Rebuild the index
ALTER INDEX CCI_FactTest
 ON dbo.FactTest
 REBUILD WITH (DATA_COMPRESSION = COLUMNSTORE);
GO

-- Check the status of the row segments
SELECT OBJECT_NAME(object_id) AS table_name,
 row_group_id, state, state_desc,
 total_rows, deleted_rows
FROM sys.dm_db_column_store_row_group_physical_stats
WHERE object_id = OBJECT_ID(N'dbo.FactTest')
ORDER BY row_group_id;
GO
-- Only four compressed row groups

-- Drop the constraint
ALTER TABLE dbo.FactTest
 DROP CONSTRAINT U_SaleKey;
GO


-- Insert 113,990 rows into FactTest
INSERT INTO dbo.FactTest
(SaleKey, CustomerKey, 
 Customer, CityKey, City,
 DateKey, StockItemKey,
 Product, Quantity,
 TotalAmount, Profit)
SELECT 11 * 1000000 + f.[Sale Key] AS SaleKey,
  cu.[Customer Key] AS CustomerKey, cu.Customer,
  ci.[City Key] AS CityKey, ci.City, 
  f.[Delivery Date Key] AS DateKey,
  s.[Stock Item Key] AS StockItemKey, s.[Stock Item] AS Product, 
  f.Quantity, f.[Total Excluding Tax] AS TotalAmount, f.Profit
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS cu
    ON f.[Customer Key] = cu.[Customer Key]
  INNER JOIN Dimension.City AS ci
    ON f.[City Key] = ci.[City Key]
  INNER JOIN Dimension.[Stock Item] AS s
    ON f.[Stock Item Key] = s.[Stock Item Key]
  INNER JOIN Dimension.Date AS d
    ON f.[Delivery Date Key] = d.Date
WHERE f.[Sale Key] % 2 = 0;
GO

-- Check the status of the row segments
SELECT OBJECT_NAME(object_id) AS table_name,
 row_group_id, state, state_desc,
 total_rows, deleted_rows
FROM sys.dm_db_column_store_row_group_physical_stats
WHERE object_id = OBJECT_ID(N'dbo.FactTest')
ORDER BY row_group_id;
GO
-- All row groups compressed - batch size is >= 102400

-- Insert 75,993 rows into FactTest
INSERT INTO dbo.FactTest
(SaleKey, CustomerKey, 
 Customer, CityKey, City,
 DateKey, StockItemKey,
 Product, Quantity,
 TotalAmount, Profit)
SELECT 12 * 1000000 + f.[Sale Key] AS SaleKey,
  cu.[Customer Key] AS CustomerKey, cu.Customer,
  ci.[City Key] AS CityKey, ci.City, 
  f.[Delivery Date Key] AS DateKey,
  s.[Stock Item Key] AS StockItemKey, s.[Stock Item] AS Product, 
  f.Quantity, f.[Total Excluding Tax] AS TotalAmount, f.Profit
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS cu
    ON f.[Customer Key] = cu.[Customer Key]
  INNER JOIN Dimension.City AS ci
    ON f.[City Key] = ci.[City Key]
  INNER JOIN Dimension.[Stock Item] AS s
    ON f.[Stock Item Key] = s.[Stock Item Key]
  INNER JOIN Dimension.Date AS d
    ON f.[Delivery Date Key] = d.Date
WHERE f.[Sale Key] % 3 = 0;
GO

-- Check the status of the row segments
SELECT OBJECT_NAME(object_id) AS table_name,
 row_group_id, state, state_desc,
 total_rows, deleted_rows
FROM sys.dm_db_column_store_row_group_physical_stats
WHERE object_id = OBJECT_ID(N'dbo.FactTest')
ORDER BY row_group_id;
GO
-- One row group open - batch size is < 102400

-- Rebuild the index
ALTER INDEX CCI_FactTest
 ON dbo.FactTest REBUILD;
GO

-- Check the status of the row segments
SELECT OBJECT_NAME(object_id) AS table_name,
 row_group_id, state, state_desc,
 total_rows, deleted_rows
FROM sys.dm_db_column_store_row_group_physical_stats
WHERE object_id = OBJECT_ID(N'dbo.FactTest')
ORDER BY row_group_id;
GO
-- All rowgroups compressed

-- Select rows from the trickle insert
SELECT *
FROM dbo.FactTest
WHERE SaleKey >= 12000000
ORDER BY SaleKey;
GO

-- Delete rows from the trickle insert
-- Show the execution plan
DELETE
FROM dbo.FactTest
WHERE SaleKey >= 12000000;
GO

-- Check the status of the row segments
SELECT OBJECT_NAME(object_id) AS table_name,
 row_group_id, state, state_desc,
 total_rows, deleted_rows
FROM sys.dm_db_column_store_row_group_physical_stats
WHERE object_id = OBJECT_ID(N'dbo.FactTest')
ORDER BY row_group_id;
GO
-- All rowgroups compressed

-- Select rows from the trickle insert
SELECT *
FROM dbo.FactTest
WHERE SaleKey >= 12000000
ORDER BY SaleKey;
-- This time, 0 rows is returned
GO

-- Clean up
USE WideWorldImportersDW;
GO
DROP TABLE dbo.FactTest;
GO
