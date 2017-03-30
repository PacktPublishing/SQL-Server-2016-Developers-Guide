--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide				--------
---- Chapter 12 - In-Memory OLTP Improvements in SQL Server 2016 -----
--------------------------------------------------------------------

----------------------------------------------------
--Listing 1: Create an In-Memory OLTP Database
----------------------------------------------------
USE master;
GO
CREATE DATABASE InMemoryTest
    ON 
    PRIMARY(NAME = [InMemoryTest_disk], 
			FILENAME = 'C:\temp\InMemoryTest_disk.mdf', size=100MB), 
    FILEGROUP [InMemoryTest_inmem] CONTAINS MEMORY_OPTIMIZED_DATA
			(NAME = [InMemoryTest_inmem], 
			FILENAME = 'C:\temp\InMemoryTest_inmem')
	LOG ON (name = [InMemoryTest_log], Filename='c:\temp\InMemoryTest_log.ldf', size=100MB)
	COLLATE Latin1_General_100_BIN2;
GO 

----------------------------------------------------
--Listing 2: Creating our first memory-optimized table
----------------------------------------------------
USE InMemoryTest;
GO 
CREATE TABLE dbo.InMemoryTable
(
	UserId INT NOT NULL,
	UserName VARCHAR(20) COLLATE Latin1_General_CI_AI NOT NULL ,
	LoginTime DATETIME2 NOT NULL,
	LoginCount INT NOT NULL,
	CONSTRAINT PK_UserId  PRIMARY KEY NONCLUSTERED (UserId),
	INDEX HSH_UserName HASH (UserName) WITH (BUCKET_COUNT=10000)
	
) WITH (MEMORY_OPTIMIZED = ON, DURABILITY=SCHEMA_AND_DATA);
GO

-- Create one test row
INSERT INTO dbo.InMemoryTable
        ( UserId, UserName , LoginTime, LoginCount )
VALUES ( 1, 'Mickey Mouse', '2016-01-01', 1 );
GO

----------------------------------------------------
--Listing 3: Add a column our memory-optimized table
----------------------------------------------------
USE InMemoryTest;
GO 
ALTER TABLE dbo.InMemoryTable ADD NewColumn INT NULL;
GO

----------------------------------------------------
--Listing 4: Drop a column from our memory-optimized table
----------------------------------------------------
USE InMemoryTest;
GO 
ALTER TABLE dbo.InMemoryTable DROP COLUMN NewColumn;
GO

----------------------------------------------------
--Listing 5: add an index our memory-optimized table
----------------------------------------------------
USE InMemoryTest;
GO
ALTER TABLE dbo.InMemoryTable ADD INDEX HSH_LoginTime NONCLUSTERED HASH (LoginTime) WITH (BUCKET_COUNT = 250);
GO

----------------------------------------------------
--Listing 6: drop and alter an index our memory-optimized table
----------------------------------------------------
USE InMemoryTest;
GO 
ALTER TABLE dbo.InMemoryTable ALTER INDEX HSH_LoginTime REBUILD WITH (BUCKET_COUNT=10000);
GO

USE InMemoryTest;
GO 
ALTER TABLE dbo.InMemoryTable DROP INDEX HSH_LoginTime;
GO

----------------------------------------------------
--Listing 7: Add multiple columns and an index to our memory-optimized table
----------------------------------------------------
USE InMemoryTest;
GO 
ALTER TABLE dbo.InMemoryTable 
ADD ANewColumn INT NULL,
	AnotherColumn TINYINT NULL,
	INDEX NCL_ANewColumn NONCLUSTERED HASH (ANewColumn) WITH (BUCKET_COUNT = 250);
GO

----------------------------------------------------
--Listing 8: Create and Alter a natively compilied stored procedure
----------------------------------------------------
USE InMemoryTest;
GO
CREATE PROCEDURE dbo.InMemoryInsertOptimized
    @UserId INT,
    @UserName VARCHAR(255),
    @LoginTime DATETIME2,
    @LoginCount INT
WITH NATIVE_COMPILATION, SCHEMABINDING
AS
BEGIN ATOMIC WITH
(
	TRANSACTION ISOLATION LEVEL = SNAPSHOT,
	LANGUAGE = N'English'
)
	RETURN 0;
END;
GO
ALTER PROCEDURE dbo.InMemoryInsertOptimized
    @UserId INT,
    @UserName VARCHAR(255),
    @LoginTime DATETIME2,
    @LoginCount INT
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS
BEGIN ATOMIC WITH
(
	TRANSACTION ISOLATION LEVEL = SNAPSHOT,
	LANGUAGE = N'English'
)
	-- Add an Insert
	INSERT dbo.InMemoryTable
	(UserId, UserName, LoginTime, LoginCount)
    VALUES
    (@UserId, @UserName, @LoginTime, @LoginCount);
	RETURN 0;
END;
GO

----------------------------------------------------
--Listing 9: Clean up test index and columns and
--			 alter an index our memory-optimized table to a terrible value
----------------------------------------------------
USE InMemoryTest;
GO
ALTER TABLE dbo.InMemoryTable DROP INDEX NCL_ANewColumn;
GO
ALTER TABLE dbo.InMemoryTable DROP COLUMN ANewColumn;
GO
ALTER TABLE dbo.InMemoryTable DROP COLUMN AnotherColumn;
GO
ALTER TABLE dbo.InMemoryTable ADD INDEX HSH_LoginTime NONCLUSTERED HASH (LoginTime) WITH (BUCKET_COUNT=2);
GO

----------------------------------------------------
--Listing 10: List the indexes belonging to InMemoryTable
----------------------------------------------------
USE InMemoryTest;
GO 
SELECT OBJECT_NAME(i.object_id) AS [table_name],
    COALESCE(i.name,'--HEAP--') AS [index_name],
    i.index_id,
    i.type,
    i.type_desc
FROM sys.indexes AS i
WHERE i.object_id = OBJECT_ID('InMemoryTable');
GO

----------------------------------------------------
--Listing 11: List the durability information belonging to InMemoryTable
----------------------------------------------------
USE InMemoryTest;
GO 
SELECT COALESCE(i.name,'--HEAP--') AS [index_name],
    i.index_id,
    i.type,
	t.is_memory_optimized,
	t.durability,
	t.durability_desc
FROM sys.tables t
    INNER JOIN sys.indexes AS i
        ON i.object_id = t.object_id
WHERE t.name = 'InMemoryTable';
GO

----------------------------------------------------
--Listing 12: List the information specific to hash indexes
----------------------------------------------------
USE InMemoryTest;
GO 
SELECT hi.name AS [index_name],
	hi.index_id,
	hi.type,
	hi.bucket_count
FROM sys.hash_indexes AS hi;
GO

----------------------------------------------------
--Listing 13: List the index statistics for hash indexes
----------------------------------------------------
USE InMemoryTest;
GO 
SELECT COALESCE(i.name, '--HEAP--') AS [index_name],
    i.index_id,
    i.type,
    ddxhis.total_bucket_count AS [total_buckets],
    ddxhis.empty_bucket_count AS [empty_buckets],
    ddxhis.avg_chain_length,
    ddxhis.max_chain_length
FROM sys.indexes AS i
    LEFT JOIN sys.dm_db_xtp_hash_index_stats AS ddxhis
        ON ddxhis.index_id = i.index_id
           AND ddxhis.object_id = i.object_id
WHERE i.object_id = OBJECT_ID('InMemoryTable');
GO

----------------------------------------------------
--Listing 14: Insert some rows to change index statistics for hash indexes
----------------------------------------------------
USE InMemoryTest;
GO 
INSERT INTO dbo.InMemoryTable
        ( UserId, UserName , LoginTime, LoginCount )
VALUES
		(2, 'Donald Duck'    , '2016-01-02', 1),
		(3, 'Steve Jobs'     , '2016-01-03', 1),
		(4, 'Steve Ballmer'  , '2016-01-04', 1),
		(5, 'Bill Gates'     , '2016-01-05', 1),
		(6, 'Ted Codd'       , '2016-01-06', 1),
		(7, 'Brian Kernighan', '2016-01-07', 1),
		(8, 'Dennis Ritchie' , '2016-01-08', 1);
GO 
SELECT COALESCE(i.name, '--HEAP--') AS [index_name],
    i.index_id,
    i.type,
    ddxhis.total_bucket_count AS [total_buckets],
    ddxhis.empty_bucket_count AS [empty_buckets],
    ddxhis.avg_chain_length,
    ddxhis.max_chain_length
FROM sys.indexes AS i
    LEFT JOIN sys.dm_db_xtp_hash_index_stats AS ddxhis
        ON ddxhis.index_id = i.index_id
           AND ddxhis.object_id = i.object_id
WHERE i.object_id = OBJECT_ID('InMemoryTable');
GO

----------------------------------------------------
--Listing 15: Investigate space usage of memory-optimized indexes
----------------------------------------------------
USE InMemoryTest;
GO 
SELECT COALESCE(i.name, '--HEAP--') AS [index_name],
    i.index_id,
    i.type,
    c.allocated_bytes,
    c.used_bytes
FROM sys.dm_db_xtp_memory_consumers c
    JOIN sys.memory_optimized_tables_internal_attributes a
        ON a.object_id = c.object_id
           AND a.xtp_object_id = c.xtp_object_id
    LEFT JOIN sys.indexes i
        ON c.object_id = i.object_id
           AND c.index_id = i.index_id
WHERE c.object_id = OBJECT_ID('InMemoryTable')
      AND a.type = 1
ORDER BY i.index_id;
GO

----------------------------------------------------
--Listing 16: Investigate space usage change of hash indexes when bucket counts are changed
----------------------------------------------------
USE InMemoryTest;
GO 
ALTER TABLE dbo.InMemoryTable ALTER INDEX HSH_UserName REBUILD WITH (BUCKET_COUNT=8000);
GO
SELECT COALESCE(i.name, '--HEAP--') AS [index_name],
    i.index_id,
    i.type,
    c.allocated_bytes,
    c.used_bytes
FROM sys.dm_db_xtp_memory_consumers c
    JOIN sys.memory_optimized_tables_internal_attributes a
        ON a.object_id = c.object_id
           AND a.xtp_object_id = c.xtp_object_id
    LEFT JOIN sys.indexes i
        ON c.object_id = i.object_id
           AND c.index_id = i.index_id
WHERE c.object_id = OBJECT_ID('InMemoryTable')
      AND a.type = 1
ORDER BY i.index_id;
GO

----------------------------------------------------
--Listing 17: Add a LOB column to our memory-optimized table
----------------------------------------------------
USE InMemoryTest;
GO 
ALTER TABLE dbo.InMemoryTable Add NewColumnMax VARCHAR(MAX) NULL;
GO

----------------------------------------------------
--Listing 18: Investigate space usage change of adding the LOB column
----------------------------------------------------
USE InMemoryTest;
GO 
SELECT COALESCE(i.name, '--HEAP--') AS [index_name],
    c.allocated_bytes,
    c.used_bytes,
	c.memory_consumer_desc AS memory_consumer,
	a.type_desc
FROM sys.dm_db_xtp_memory_consumers c
    JOIN sys.memory_optimized_tables_internal_attributes a
        ON a.object_id = c.object_id
           AND a.xtp_object_id = c.xtp_object_id
    LEFT JOIN sys.indexes i
        ON c.object_id = i.object_id
           AND c.index_id = i.index_id
WHERE c.object_id = OBJECT_ID('InMemoryTable')
      AND i.index_id IS NULL;
GO

----------------------------------------------------
--Listing 19: Investigate space usage change of adding data to the the LOB column
----------------------------------------------------
USE InMemoryTest;
GO 
UPDATE dbo.InMemoryTable
SET NewColumnMax = UserName;
GO
SELECT COALESCE(i.name, '--HEAP--') AS [index_name],
    c.allocated_bytes,
    c.used_bytes,
	c.memory_consumer_desc AS memory_consumer,
	a.type_desc
FROM sys.dm_db_xtp_memory_consumers c
    JOIN sys.memory_optimized_tables_internal_attributes a
        ON a.object_id = c.object_id
           AND a.xtp_object_id = c.xtp_object_id
    LEFT JOIN sys.indexes i
        ON c.object_id = i.object_id
           AND c.index_id = i.index_id
WHERE c.object_id = OBJECT_ID('InMemoryTable')
      AND i.index_id IS NULL;
GO

----------------------------------------------------
--Listing 20: Investigate LOB internal storage behaviour
----------------------------------------------------
USE InMemoryTest;
GO
DROP TABLE IF EXISTS dbo.InMemoryTableMax;
DROP TABLE IF EXISTS dbo.InMemoryTableNotMax;
GO

CREATE TABLE dbo.InMemoryTableMax
(
	UserId INT NOT NULL IDENTITY (1,1),
	MaxCol1 VARCHAR(max) COLLATE Latin1_General_CI_AI NOT NULL ,
	MaxCol2 VARCHAR(max) COLLATE Latin1_General_CI_AI NOT NULL ,
	MaxCol3 VARCHAR(max) COLLATE Latin1_General_CI_AI NOT NULL ,
	MaxCol4 VARCHAR(max) COLLATE Latin1_General_CI_AI NOT NULL ,
	MaxCol5 VARCHAR(max) COLLATE Latin1_General_CI_AI NOT NULL ,
	CONSTRAINT PK_InMemoryTableMax  PRIMARY KEY NONCLUSTERED (UserId),

) WITH (MEMORY_OPTIMIZED = ON, DURABILITY=SCHEMA_AND_DATA);
GO

CREATE TABLE dbo.InMemoryTableNotMax
(
	UserId INT NOT NULL IDENTITY (1,1),
	Col1 VARCHAR(5) COLLATE Latin1_General_CI_AI NOT NULL ,
	Col2 VARCHAR(5) COLLATE Latin1_General_CI_AI NOT NULL ,
	Col3 VARCHAR(5) COLLATE Latin1_General_CI_AI NOT NULL ,
	Col4 VARCHAR(5) COLLATE Latin1_General_CI_AI NOT NULL ,
	Col5 VARCHAR(5) COLLATE Latin1_General_CI_AI NOT NULL ,
	CONSTRAINT PK_InMemoryTableNotMax  PRIMARY KEY NONCLUSTERED (UserId),

) WITH (MEMORY_OPTIMIZED = ON, DURABILITY=SCHEMA_AND_DATA);
GO

SELECT OBJECT_NAME(c.object_id) AS [table_name],
    c.allocated_bytes AS allocated,
    c.used_bytes AS used,
    c.memory_consumer_desc AS memory_consumer,
    a.type_desc
FROM sys.dm_db_xtp_memory_consumers c
    JOIN sys.memory_optimized_tables_internal_attributes a
        ON a.object_id = c.object_id
           AND a.xtp_object_id = c.xtp_object_id
    LEFT JOIN sys.indexes i
        ON c.object_id = i.object_id
           AND c.index_id = i.index_id
WHERE
(
    c.object_id = OBJECT_ID('InMemoryTableNotMax')
    OR c.object_id = OBJECT_ID('InMemoryTableMax')
)
AND i.index_id IS NULL;
GO

----------------------------------------------------
--Listing 21: Filling LOB columns and comparing execution times
----------------------------------------------------
SET NOCOUNT ON; 
GO
SET STATISTICS TIME ON;
GO

INSERT INTO dbo.InMemoryTableMax
        ( MaxCol1 ,
          MaxCol2 ,
          MaxCol3 ,
          MaxCol4 ,
          MaxCol5
        )
SELECT TOP 100000
    'Col1',
    'Col2',
    'Col3',
    'Col4',
    'Col5'
FROM sys.columns a
    CROSS JOIN sys.columns;
GO

INSERT INTO dbo.InMemoryTableNotMax
        ( Col1 ,
          Col2 ,
          Col3 ,
          Col4 ,
          Col5
        )
SELECT TOP 100000
    'Col1',
    'Col2',
    'Col3',
    'Col4',
    'Col5'
FROM sys.columns a
    CROSS JOIN sys.columns;
GO
SET STATISTICS TIME OFF;
GO

----------------------------------------------------
--Listing 22: Investigate space usage change after adding data to the the LOB column
----------------------------------------------------
USE InMemoryTest;
GO

SELECT OBJECT_NAME(c.object_id) AS [table_name],
    SUM(c.allocated_bytes) / 1024. AS allocated,
    SUM(c.used_bytes) / 1024. AS used
FROM sys.dm_db_xtp_memory_consumers c
    JOIN sys.memory_optimized_tables_internal_attributes a
        ON a.object_id = c.object_id
           AND a.xtp_object_id = c.xtp_object_id
    LEFT JOIN sys.indexes i
        ON c.object_id = i.object_id
           AND c.index_id = i.index_id
WHERE
(
    c.object_id = OBJECT_ID('InMemoryTableNotMax')
    OR c.object_id = OBJECT_ID('InMemoryTableMax')
)
AND i.index_id IS NULL
GROUP BY c.object_id;

----------------------------------------------------
--Listing 23: Cleanup
----------------------------------------------------
USE master
GO
ALTER DATABASE InMemoryTest SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
DROP DATABASE InMemoryTest
GO
