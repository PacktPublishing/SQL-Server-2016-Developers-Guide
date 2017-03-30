--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide				--------
---- Chapter 11 - Introducing SQL Server In-Memory OLTP -----
--------------------------------------------------------------------

----------------------------------------------------
-- Creating Memory-Optimized Tables and Indexes
----------------------------------------------------
USE master
GO
DROP DATABASE IF EXISTS InMemoryTest
GO
----------------------------------------------------
--Listing 1: Create an In-Memory OLTP Database
----------------------------------------------------

CREATE DATABASE InMemoryTest
    ON 
    PRIMARY(NAME = [InMemTest_disk], 
			FILENAME = 'C:\temp\InMemTest_disk.mdf', size=100MB), 
    FILEGROUP [InMemTest_inmem] CONTAINS MEMORY_OPTIMIZED_DATA
			(NAME = [InMemTest_inmem], 
			FILENAME = 'C:\temp\InMemTest_inmem')
	LOG ON (name = [InMemTest_log], Filename='c:\temp\InMemTest_log.ldf', size=100MB)
	COLLATE Latin1_General_100_BIN2; 

;

----------------------------------------------------
--Listing 2: Adding an In-Memory OLTP Filegroup to an existing database
----------------------------------------------------

ALTER DATABASE AdventureWorks2014 
 		ADD FILEGROUP InMemTest CONTAINS MEMORY_OPTIMIZED_DATA;
GO
ALTER DATABASE AdventureWorks2014
 		ADD FILE (NAME='InMemTest', FILENAME='c:\temp\InMemTest') 
    TO FILEGROUP InMemTest;
GO

----------------------------------------------------
--Listing 3: Creating our first memory-optimized table
----------------------------------------------------
USE InMemoryTest;
GO

CREATE TABLE dbo.InMemoryTable
    (UserId     int          NOT NULL,
     UserName   varchar(255) NOT NULL,
     LoginTime  datetime2    NOT NULL,
     LoginCount int          NOT NULL,
     CONSTRAINT PK_UserId PRIMARY KEY NONCLUSTERED (UserId),
     INDEX NCL_IDX HASH (UserName) WITH (BUCKET_COUNT = 10000))
WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_ONLY);
GO
----------------------------------------------------
--Listing 3: Querying a memory-optimized table
----------------------------------------------------

SELECT *
FROM dbo.InMemoryTable;
;

INSERT INTO dbo.InMemoryTable
        ( UserId ,
          UserName ,
          LoginTime ,
          LoginCount
        )
VALUES  ( 1 ,
          'John Smith' ,
          SYSDATETIME() ,
          1
        )
;
SELECT *
FROM dbo.InMemoryTable;
;

----------------------------------------------------
--Listing 4: Performance comparison: Create disk based table
----------------------------------------------------
USE InMemoryTest
GO 
CREATE TABLE DiskBasedTable
(
	UserId INT NOT NULL PRIMARY KEY NONCLUSTERED,
	UserName VARCHAR(255) NOT NULL,
	LoginTime DATETIME2 NOT NULL,
	LoginCount INT NOT NULL,

	INDEX NCL_IDX NONCLUSTERED (UserName)
)
GO
INSERT INTO dbo.DiskBasedTable
        ( UserId ,
          UserName ,
          LoginTime ,
          LoginCount
        )
VALUES  ( 1 ,
          'John Smith' ,
          SYSDATETIME() ,
          1
        )
;
SELECT *
FROM dbo.DiskBasedTable AS DBT;
;

----------------------------------------------------
--Listing 5: Performance comparison: Create DiskBasedInsert Procedure
----------------------------------------------------
USE InMemoryTest
GO
CREATE PROCEDURE dbo.DiskBasedInsert
    @UserId INT,
    @UserName VARCHAR(255),
    @LoginTime DATETIME2,
    @LoginCount INT
AS
BEGIN

    INSERT dbo.DiskBasedTable
    (UserId, UserName, LoginTime, LoginCount)
    VALUES
    (@UserId, @UserName, @LoginTime, @LoginCount);

END;
GO

----------------------------------------------------
--Listing 6: Performance comparison: disk-based vs memory-optimized
----------------------------------------------------
USE InMemoryTest
GO 
TRUNCATE TABLE dbo.DiskBasedTable
GO
SET NOCOUNT ON
GO
DECLARE @start DATETIME2;
SET @start = SYSDATETIME();

DECLARE @Counter int = 0,
		@_LoginTime DATETIME2 = SYSDATETIME(),
		@_UserName VARCHAR(255);
	WHILE @Counter < 50000
	BEGIN
		SET @_UserName = 'UserName ' + CAST(@Counter AS varchar(6))

		EXECUTE dbo.DiskBasedInsert 
			@UserId = @Counter,
			@UserName = @_UserName,
			@LoginTime = @_LoginTime, 
			@LoginCount = @Counter
			
		SET @Counter += 1;
	END;

SELECT DATEDIFF(ms, @start, SYSDATETIME()) AS 'insert into disk-based table (in ms)';
GO

----------------------------------------------------
--Listing 6: Performance comparison: disk-based vs memory-optimized
----------------------------------------------------
USE InMemoryTest
GO 
SET NOCOUNT ON
GO
CREATE PROCEDURE dbo.InMemoryInsert
    @UserId INT,
    @UserName VARCHAR(255),
    @LoginTime DATETIME2,
    @LoginCount INT
AS
BEGIN

    INSERT dbo.InMemoryTable
    (UserId, UserName, LoginTime, LoginCount)
    VALUES
    (@UserId, @UserName, @LoginTime, @LoginCount);

END;
GO


USE InMemoryTest
GO 
DELETE FROM dbo.InMemoryTable
GO


DECLARE @start DATETIME2;
SET @start = SYSDATETIME();

DECLARE @Counter int = 0,
		@_LoginTime DATETIME2 = SYSDATETIME(),
		@_UserName VARCHAR(255);
	WHILE @Counter < 50000
	BEGIN
		SET @_UserName = 'UserName ' + CAST(@Counter AS varchar(6))

		EXECUTE dbo.InMemoryInsert 
			@UserId = @Counter,
			@UserName = @_UserName,
			@LoginTime = @_LoginTime, 
			@LoginCount = @Counter
			
		SET @Counter += 1;
	END;

SELECT DATEDIFF(ms, @start, SYSDATETIME()) AS 'insert into disk-based table (in ms)';
GO

----------------------------------------------------
--Listing 6: Performance comparison: Natively Compiled Insert
----------------------------------------------------
USE InMemoryTest
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

	INSERT dbo.InMemoryTable
	(UserId, UserName, LoginTime, LoginCount)
    VALUES
    (@UserId, @UserName, @LoginTime, @LoginCount);
	RETURN 0;
END;
GO

USE InMemoryTest
GO 
DELETE FROM dbo.InMemoryTable
GO

DECLARE @start DATETIME2;
SET @start = SYSDATETIME();

DECLARE @Counter int = 0,
		@_LoginTime DATETIME2 = SYSDATETIME(),
		@_UserName VARCHAR(255);
	WHILE @Counter < 50000
	BEGIN
		SET @_UserName = 'UserName ' + CAST(@Counter AS varchar(6))

		EXECUTE dbo.InMemoryInsertOptimized 
			@UserId = @Counter,
			@UserName = @_UserName,
			@LoginTime = @_LoginTime, 
			@LoginCount = @Counter
			
		SET @Counter += 1;
	END;

SELECT DATEDIFF(ms, @start, SYSDATETIME()) AS 'insert into memory-optimized table (in ms)';
GO

----------------------------------------------------
--Listing 7: Performance comparison: Fully Natively Compiled
----------------------------------------------------
USE InMemoryTest
GO
CREATE PROCEDURE dbo.FullyNativeInMemoryInsertOptimized
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
AS
BEGIN ATOMIC WITH
(
	TRANSACTION ISOLATION LEVEL = SNAPSHOT,
	LANGUAGE = N'English'
)

	DECLARE @Counter int = 0,
	@_LoginTime DATETIME2 = SYSDATETIME(),
	@_UserName VARCHAR(255)
	;
	WHILE @Counter < 50000
	BEGIN
			SET  @_UserName = 'UserName ' + CAST(@Counter AS varchar(6))

			INSERT INTO dbo.InMemoryTable
			        
			(UserId, UserName, LoginTime, LoginCount)
			VALUES
			(@Counter, @_UserName, @_LoginTime, @Counter);

		SET @Counter += 1;
	END;
	RETURN 0;
END;
GO

USE InMemoryTest
GO 
DELETE FROM dbo.InMemoryTable
GO


DECLARE @start DATETIME2;
SET @start = SYSDATETIME();

EXEC dbo.FullyNativeInMemoryInsertOptimized

SELECT DATEDIFF(ms, @start, SYSDATETIME()) AS 'insert into memory-optimized table (in ms)';
GO

----------------------------------------------------
--Listing 8: dm_db_xtp_index_stats
----------------------------------------------------
USE InMemoryTest
GO
SELECT i.name AS 'index_name',
    s.rows_returned,
    s.rows_expired,
    s.rows_expired_removed
FROM sys.dm_db_xtp_index_stats s
    JOIN sys.indexes i
        ON s.object_id = i.object_id
           AND s.index_id = i.index_id
WHERE OBJECT_ID('InMemoryTable') = s.object_id;
GO

----------------------------------------------------
--Listing 9: In-Memory OLTP Extended Events
----------------------------------------------------
USE InMemoryTest
GO
SELECT p.name,
    o.name,
    o.description
FROM sys.dm_xe_objects o
    JOIN sys.dm_xe_packages p
        ON o.package_guid = p.guid
WHERE p.name = 'XtpEngine';
GO

----------------------------------------------------
--Listing 10: In-Memory OLTP Perfmon Counters
----------------------------------------------------
USE InMemoryTest
GO
SELECT object_name,
    counter_name
FROM sys.dm_os_performance_counters
WHERE object_name LIKE '%XTP%';
GO

----------------------------------------------------
--Listing 11: Cleanup
----------------------------------------------------
USE master
GO
ALTER DATABASE InMemoryTest SET SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
DROP DATABASE InMemoryTest
GO
