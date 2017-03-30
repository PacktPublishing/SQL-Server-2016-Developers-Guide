--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide
--------	Chapter 07 -  Temporal Tables
--------------------------------------------------------------------

----------------------------------
--Creating Temporal Tables
----------------------------------
USE WideWorldImporters;
CREATE TABLE dbo.Product
(
   ProductId INT NOT NULL CONSTRAINT PK_Product PRIMARY KEY,
   ProductName NVARCHAR(50) NOT NULL,
   Price MONEY NOT NULL,
   ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL,
   ValidTo DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL,
   PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON);
GO
--define the name for the history table
CREATE TABLE dbo.Product2
(
   ProductId INT NOT NULL CONSTRAINT PK_Product2 PRIMARY KEY,
   ProductName NVARCHAR(50) NOT NULL,
   Price MONEY NOT NULL,
   ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL,
   ValidTo DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL,
   PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.ProductHistory2));
GO

-- check the storage type
SELECT temporal_type_desc, p.data_compression_desc 
FROM sys.tables t
INNER JOIN sys.partitions p ON t.object_id = p.object_id
WHERE name = 'ProductHistory2';
/*Result:
temporal_type_desc    data_compression_desc
--------------------- ---------------------
HISTORY_TABLE         PAGE
*/

-- extracts the index name and the columns used in the index:
SELECT i.name, i.type_desc, c.name, ic.index_column_id
FROM sys.indexes i
INNER JOIN sys.index_columns ic on ic.object_id = i.object_id
INNER JOIN sys.columns c on c.object_id = i.object_id AND ic.column_id = c.column_id
WHERE OBJECT_NAME(i.object_id) = 'ProductHistory2';
/*Result:
name                  type_desc     name       		index_column_id 
--------------------- ------------- ----------- 	------------
ix_ProductHistory2    CLUSTERED     ValidFrom		1
ix_ProductHistory2    CLUSTERED     ValidTo			2

*/
 
--creates first a history table, then a temporal table and finally assigns the history table to it. 
USE WideWorldImporters;
ALTER TABLE dbo.Product SET (SYSTEM_VERSIONING = OFF);   
ALTER TABLE dbo.Product DROP PERIOD FOR SYSTEM_TIME;   
DROP TABLE IF EXISTS dbo.Product;
DROP TABLE IF EXISTS dbo.ProductHistory;
GO
CREATE TABLE dbo.ProductHistory
(
   ProductId INT NOT NULL,
   ProductName NVARCHAR(50) NOT NULL,
   Price MONEY NOT NULL,
   ValidFrom DATETIME2 NOT NULL,
   ValidTo DATETIME2 NOT NULL
);
CREATE CLUSTERED COLUMNSTORE INDEX IX_ProductHistory ON dbo.ProductHistory;
CREATE NONCLUSTERED INDEX IX_ProductHistory_NC ON dbo.ProductHistory(ProductId, ValidFrom, ValidTo);
GO
CREATE TABLE dbo.Product
(
   ProductId INT NOT NULL CONSTRAINT PK_Product PRIMARY KEY,
   ProductName NVARCHAR(50) NOT NULL,
   Price MONEY NOT NULL,
   ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL,
   ValidTo DATETIME2 GENERATED ALWAYS AS ROW END NOT NULL,
   PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.ProductHistory));
GO

------------------------------------------------
---Converting Non-Temporal to Temporal Tables
------------------------------------------------
USE AdventureWorks2016CTP3;
ALTER TABLE HumanResources.Department
ADD ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START HIDDEN NOT NULL CONSTRAINT DF_Validfrom DEFAULT SYSDATETIME(),
   ValidTo DATETIME2 GENERATED ALWAYS AS ROW END HIDDEN NOT NULL CONSTRAINT DF_ValidTo DEFAULT '99991231 23:59:59.9999999',
   PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo);
GO
ALTER TABLE HumanResources.Department SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = HumanResources.DepartmentHistory)); 
GO

------------------------------------------------------------------------------------------------
------ Migration Existing Temporal Solution to System-Versioned Tables
------------------------------------------------------------------------------------------------
USE WideWorldImporters;
CREATE TABLE dbo.ProductListPrice
(
	ProductID INT NOT NULL CONSTRAINT PK_ProductListPrice PRIMARY KEY,
	ListPrice MONEY NOT NULL,
);
INSERT INTO dbo.ProductListPrice(ProductID,ListPrice)
SELECT ProductID,ListPrice FROM AdventureWorks2016CTP3.Production.Product;
GO
CREATE TABLE dbo.ProductListPriceHistory
(
	ProductID INT NOT NULL,
	ListPrice MONEY NOT NULL,
	StartDate DATETIME NOT NULL,
	EndDate DATETIME   NULL,
	CONSTRAINT PK_ProductListPriceHistory PRIMARY KEY CLUSTERED 
	(
		ProductID ASC,
		StartDate ASC
	)
);
INSERT INTO dbo.ProductListPriceHistory(ProductID,ListPrice,StartDate,EndDate)
SELECT ProductID, ListPrice, StartDate, EndDate FROM AdventureWorks2016CTP3.Production.ProductListPriceHistory; 

--Consider the rows for the product with ID 707 in both tables:
SELECT * FROM dbo.ProductListPrice WHERE ProductID = 707;
SELECT * FROM dbo.ProductListPriceHistory WHERE ProductID = 707;
/*Result:
ProductID   ListPrice
----------- ---------------------
707         34,99

ProductID   ListPrice             StartDate               EndDate
----------- --------------------- ----------------------- -----------------------
707         33,6442               2011-05-31 00:00:00.000 2012-05-29 00:00:00.000
707         33,6442               2012-05-30 00:00:00.000 2013-05-29 00:00:00.000
707         34,99                 2013-05-30 00:00:00.000 NULL
*/

-- create the temporal infrastructure in the current table:
ALTER TABLE dbo.ProductListPrice
ADD StartDate DATETIME2 GENERATED ALWAYS AS ROW START HIDDEN NOT NULL CONSTRAINT DF_StartDate1 DEFAULT SYSDATETIME(),
   EndDate DATETIME2 GENERATED ALWAYS AS ROW END HIDDEN NOT NULL CONSTRAINT DF_EndDate1 DEFAULT '99991231 23:59:59.9999999',
   PERIOD FOR SYSTEM_TIME (StartDate, EndDate);
GO
--remove gaps
UPDATE dbo.ProductListPriceHistory SET EndDate = DATEADD(day,1,EndDate);
--update EndDate to StartDate of the actual record
UPDATE dbo.ProductListPriceHistory SET EndDate = (SELECT MAX(StartDate) FROM dbo.ProductListPrice) WHERE EndDate IS NULL;
--remove constraints
ALTER TABLE dbo.ProductListPriceHistory DROP CONSTRAINT PK_ProductListPriceHistory;
--change data type to DATETIME2
ALTER TABLE dbo.ProductListPriceHistory ALTER COLUMN StartDate DATETIME2 NOT NULL;
ALTER TABLE dbo.ProductListPriceHistory ALTER COLUMN EndDate DATETIME2 NOT NULL;

--Now both tables are ready for participating in the relation to act as a system-versioned temporal table in SQL Server 2016:
ALTER TABLE dbo.ProductListPrice SET (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.ProductListPriceHistory,  DATA_CONSISTENCY_CHECK = ON));

--update the price for the product with the ID 707 to 50 and then check the rows in both tables:
UPDATE dbo.ProductListPrice SET Price = 50 WHERE ProductID = 707;
SELECT * FROM dbo.ProductListPrice WHERE ProductID = 707;
SELECT * FROM dbo.ProductListPriceHistory WHERE ProductID = 707;
/*Result:

ProductID   ListPrice
----------- ---------------
707         50,00

ProductID   ListPrice      StartDate               	 EndDate
----------- -------------- ----------------------- 	 -----------------------
707         33,6442       2011-05-31 00:00:00.000 	 2012-05-29 00:00:00.000
707         33,6442       2012-05-30 00:00:00.000 	 2013-05-29 00:00:00.000
707         34,99         2013-05-30 00:00:00.000 	 2016-08-19 18:14:55.9287816
707         34,99         2016-08-19 18:14:55.9287816 2016-08-19 18:15:12.6947253

*/

----------------------------------
--Altering Temporal Tables
----------------------------------
ALTER TABLE dbo.Product ADD Color NVARCHAR(15);
--This action will be online (metadata operation) in the Enterprise Edition only. 
ALTER TABLE dbo.Product ADD Category SMALLINT NOT NULL CONSTRAINT DF_Category DEFAULT 1;
--This action will be offline opeation in all editions
ALTER TABLE dbo.Product ADD Description NVARCHAR(MAX) NOT NULL CONSTRAINT DF_ Description DEFAULT N'N/A';

--Adding, removing hidden attribute
ALTER TABLE dbo.Product ALTER COLUMN Valid_From ADD HIDDEN;
ALTER TABLE dbo.Product ALTER COLUMN Valid_From DROP HIDDEN;

--Adding SPARSE column
ALTER TABLE dbo.Product ADD Size NVARCHAR(5) SPARSE;
/*Result:
Msg 11418, Level 16, State 2, Line 20
Cannot alter table 'ProductHistory' because the table either contains sparse columns or a column set column which are incompatible with compression. 
*/
--Adding an identity column as follows
ALTER TABLE dbo.Product ADD ProductNumber INT IDENTITY (1,1);
/*Result:
Msg 13704, Level 16, State 1, Line 26
System-versioned table schema modification failed because history table 'WideWorldImporters.dbo.ProductHistory' has IDENTITY column specification. Consider dropping all IDENTITY column specifications and trying again.
*/

--If you need to add an identity column to a temporal table, you have to set its SYSTEM_VERSIONING attribute to false. 
--The following code demonstrates, how to add the identity column ProductNumber and the sparse column Size into the temporal table dbo.Product::
ALTER TABLE dbo.ProductHistory REBUILD PARTITION=ALL WITH (DATA_COMPRESSION=NONE); 
GO
BEGIN TRAN   
	ALTER TABLE dbo.Product SET (SYSTEM_VERSIONING = OFF);   
	ALTER TABLE dbo.Product ADD Size NVARCHAR(5) SPARSE;   
	ALTER TABLE dbo.ProductHistory ADD Size NVARCHAR(5) SPARSE;   
	ALTER TABLE dbo.Product ADD ProductNumber INT IDENTITY (1,1);   
	ALTER TABLE dbo.ProductHistory ADD ProductNumber INT NOT NULL DEFAULT 0;   
	ALTER TABLE dbo.Product SET(SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo. ProductHistory));   
COMMIT;   


----------------------------------
--Droping Temporal Tables
----------------------------------
ALTER TABLE dbo.Product SET (SYSTEM_VERSIONING = OFF);   
ALTER TABLE dbo.Product DROP PERIOD FOR SYSTEM_TIME;   

----------------------------------
--Data Manipulation
----------------------------------

--remove already created tables and create a temporal table again
USE WideWorldImporters;
ALTER TABLE dbo.Product SET (SYSTEM_VERSIONING = OFF);   
ALTER TABLE dbo.Product DROP PERIOD FOR SYSTEM_TIME;   
DROP TABLE IF EXISTS dbo.Product;
DROP TABLE IF EXISTS dbo.ProductHistory;
GO
CREATE TABLE dbo.Product
(
   ProductId INT NOT NULL CONSTRAINT PK_Product PRIMARY KEY,
   ProductName NVARCHAR(50) NOT NULL,
   Price MONEY NOT NULL,
   ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
   ValidTo DATETIME2 GENERATED ALWAYS AS ROW END HIDDEN NOT NULL,
   PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.ProductHistory));
GO

--insert a new row and check the tables
INSERT INTO dbo.Product(ProductId, ProductName, Price) VALUES(1, N'Fog', 150.00);
SELECT * FROM dbo.Product;
SELECT * FROM dbo.ProductHistory;

/*Result:
ProductId   ProductName                                        Price
----------- -------------------------------------------------- ---------------------
1           Fog                                                150,00

ProductId   ProductName                                        Price                 ValidFrom                   ValidTo
----------- -------------------------------------------------- --------------------- --------------------------- ---------------------------
*/

--update the price to 200
UPDATE dbo.Product SET Price = 200.00 WHERE ProductId = 1; 

SELECT * FROM dbo.Product;
SELECT * FROM dbo.ProductHistory;
/*Result:
ProductId   ProductName                                        Price
----------- -------------------------------------------------- ---------------------
1           Fog                                                200,00
ProductId   ProductName                                        Price                 ValidFrom                   ValidTo
----------- -------------------------------------------------- --------------------- --------------------------- ---------------------------
1           Fog                                                150,00                2016-08-20 11:28:06.8072636 2016-08-20 11:29:05.6520461
*/

--update the price to 180
UPDATE dbo.Product SET Price = 180.00 WHERE ProductId = 1; 
SELECT * FROM dbo.Product;
SELECT * FROM dbo.ProductHistory;
/*Result:
ProductId   ProductName                                        Price
----------- -------------------------------------------------- ---------------------
1           Fog                                                180,00
ProductId   ProductName                                        Price                 ValidFrom                   ValidTo
----------- -------------------------------------------------- --------------------- --------------------------- ---------------------------
1           Fog                                                150,00                2016-08-20 11:28:06.8072636 2016-08-20 11:29:05.6520461
1           Fog                                                200,00                2016-08-20 11:29:05.6520461 2016-08-20 11:29:42.8538668
*/
--update the price to 180
UPDATE dbo.Product SET Price = 180.00 WHERE ProductId = 1; 
SELECT * FROM dbo.Product;
SELECT * FROM dbo.ProductHistory;
/*Result:
ProductId   ProductName                                        Price
----------- -------------------------------------------------- ---------------------
1           Fog                                                180,00

ProductId   ProductName                                        Price                 ValidFrom                   ValidTo
----------- -------------------------------------------------- --------------------- --------------------------- ---------------------------
1           Fog                                                150,00                2016-08-20 11:28:06.8072636 2016-08-20 11:29:05.6520461
1           Fog                                                200,00                2016-08-20 11:29:05.6520461 2016-08-20 11:29:42.8538668
1           Fog                                                180,00                2016-08-20 11:29:42.8538668 2016-08-20 11:30:11.9324821
*/
DELETE FROM dbo.Product WHERE ProductId = 1;
SELECT * FROM dbo.Product;
SELECT * FROM dbo.ProductHistory;
/*Result:
ProductId   ProductName                                        Price
----------- -------------------------------------------------- ---------------------

ProductId   ProductName                                        Price                 ValidFrom                   ValidTo
----------- -------------------------------------------------- --------------------- --------------------------- ---------------------------
1           Fog                                                150,00                2016-08-20 11:28:06.8072636 2016-08-20 11:29:05.6520461
1           Fog                                                200,00                2016-08-20 11:29:05.6520461 2016-08-20 11:29:42.8538668
1           Fog                                                180,00                2016-08-20 11:29:42.8538668 2016-08-20 11:30:11.9324821
1           Fog                                                180,00                2016-08-20 11:30:11.9324821 2016-08-20 11:30:42.9330248
*/

----------------------------------------------
--Querying Temporal Data in SQL Server 2016
----------------------------------------------
USE WideWorldImporters;
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People WHERE ValidFrom <= '2016-03-20 08:00:00' AND ValidTo > '2016-03-20 08:00:00' 
UNION ALL
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People_Archive WHERE ValidFrom <= '2016-03-20 08:00:00' AND ValidTo > '2016-03-20 08:00:00';
--1.109 rows are returned

--The query is logically equivalent to this one:
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People FOR SYSTEM_TIME AS OF '2016-03-20 08:00:00';

--prove that both resultset are identical
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People WHERE ValidFrom <= '2016-03-20 08:00:00' AND ValidTo > '2016-03-20 08:00:00' 
UNION ALL
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People_Archive WHERE ValidFrom <= '2016-03-20 08:00:00' AND ValidTo > '2016-03-20 08:00:00' 
EXCEPT
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People FOR SYSTEM_TIME AS OF '2016-03-20 08:00:00';
/*Result:
no rows
*/  

SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People FOR SYSTEM_TIME AS OF '2016-03-20 08:00:00'
EXCEPT
(
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People WHERE ValidFrom <= '2016-03-20 08:00:00' AND ValidTo > '2016-03-20 08:00:00' 
UNION ALL
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People_Archive WHERE ValidFrom <= '2016-03-20 08:00:00' AND ValidTo > '2016-03-20 08:00:00'
);
/*Result:
no rows
*/

--A special case of a point-in-time query against a temporal table is a query where you specify the actual date as the point in time. 
--The following query returns actual data from the same temporal table:
DECLARE @Now AS DATETIME = CURRENT_TIMESTAMP;
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People FOR SYSTEM_TIME AS OF @Now;
--The query is logically equivalent to this one:
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People;
/*Result:
when you look at the execution plans for the execution of the first query both tables have been processed, 
while the non-temporal query had to retrieve data from the current table only
*/


--example using FROM/TO
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People FOR SYSTEM_TIME FROM '2016-03-20 08:00:00' TO '2016-05-31 23:14:00' WHERE PersonID = 7;
/*Result:
PersonID    FullName                                           OtherLanguages                                                                                                                                                                                                                                                   ValidFrom                   ValidTo
----------- -------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- --------------------------- ---------------------------
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2016-03-20 08:00:00.0000000 2016-05-31 23:13:00.0000000
7           Amy Trefl                                          ["Slovak","Spanish","Polish"]                                                                                                                                                                                                                                    2016-05-31 23:13:00.0000000 2016-05-31 23:14:00.0000000
*/

--example using BETWEEN
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People FOR SYSTEM_TIME BETWEEN '2016-03-20 08:00:01' AND '2016-05-31 23:14:00' WHERE PersonID = 7;
/*Result:
PersonID    FullName                                           OtherLanguages                                                                                                                                                                                                                                                   ValidFrom                   ValidTo
----------- -------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- --------------------------- ---------------------------
7           Amy Trefl                                          ["Slovak","Spanish","Polish"]                                                                                                                                                                                                                                    2016-05-31 23:14:00.0000000 9999-12-31 23:59:59.9999999
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2016-03-20 08:00:00.0000000 2016-05-31 23:13:00.0000000
7           Amy Trefl                                          ["Slovak","Spanish","Polish"]                                                                                                                                                                                                                                    2016-05-31 23:13:00.0000000 2016-05-31 23:14:00.0000000
*/

--example using CONTAINED IN
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People FOR SYSTEM_TIME CONTAINED IN ('2016-03-20 08:00:01','2016-05-31 23:14:00') WHERE PersonID = 7;
/*Result:
PersonID    FullName                                           OtherLanguages                                                                                                                                                                                                                                                   ValidFrom                   ValidTo
----------- -------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- --------------------------- ---------------------------
7           Amy Trefl                                          ["Slovak","Spanish","Polish"]                                                                                                                                                                                                                                    2016-05-31 23:13:00.0000000 2016-05-31 23:14:00.0000000
*/

--example using ALL
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People FOR SYSTEM_TIME ALL
WHERE PersonID = 7;
/*Result:
PersonID    FullName                                           OtherLanguages                                                                                                                                                                                                                                                   ValidFrom                   ValidTo
----------- -------------------------------------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- --------------------------- ---------------------------
7           Amy Trefl                                          ["Slovak","Spanish","Polish"]                                                                                                                                                                                                                                    2016-05-31 23:14:00.0000000 9999-12-31 23:59:59.9999999
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2013-01-01 00:00:00.0000000 2013-01-05 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2013-01-05 08:00:00.0000000 2013-01-22 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2013-01-22 08:00:00.0000000 2013-02-26 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2013-02-26 08:00:00.0000000 2013-03-07 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2013-03-07 08:00:00.0000000 2013-04-24 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2013-04-24 08:00:00.0000000 2013-07-05 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2013-07-05 08:00:00.0000000 2013-08-31 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2013-08-31 08:00:00.0000000 2014-02-03 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2014-02-03 08:00:00.0000000 2014-04-23 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2014-04-23 08:00:00.0000000 2015-06-15 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2015-06-15 08:00:00.0000000 2016-03-20 08:00:00.0000000
7           Amy Trefl                                          NULL                                                                                                                                                                                                                                                             2016-03-20 08:00:00.0000000 2016-05-31 23:13:00.0000000
7           Amy Trefl                                          ["Slovak","Spanish","Polish"]                                                                                                                                                                                                                                    2016-05-31 23:13:00.0000000 2016-05-31 23:14:00.0000000
*/

--The query returns 14 rows, since there are 13 historical rows and one entry in the actual table. 
--Here is the logically equivalent, standard but a bit more complex query:
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People 
WHERE PersonID = 7
UNION ALL
SELECT PersonID, FullName, OtherLanguages, ValidFrom, ValidTo 
FROM Application.People_Archive
WHERE PersonID = 7;

----------------------------------------------
--Temporal Tables with Memory-Optimized Tables
----------------------------------------------
--create a memory-optimized temporal table
USE WideWorldImporters;
ALTER TABLE dbo.Product SET (SYSTEM_VERSIONING = OFF);   
ALTER TABLE dbo.Product DROP PERIOD FOR SYSTEM_TIME;   
DROP TABLE IF EXISTS dbo.Product;
DROP TABLE IF EXISTS dbo.ProductHistory;
GO
USE WideWorldImporters;
CREATE TABLE dbo.Product
(
   ProductId INT NOT NULL PRIMARY KEY NONCLUSTERED,
   ProductName NVARCHAR(50) NOT NULL,
   Price MONEY NOT NULL,
   ValidFrom DATETIME2 GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
   ValidTo DATETIME2 GENERATED ALWAYS AS ROW END HIDDEN NOT NULL,
   PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
)
WITH (MEMORY_OPTIMIZED = ON, DURABILITY = SCHEMA_AND_DATA, SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.ProductHistory));

--After the execution of this query, you can see that one memory-optimized table is
SELECT CONCAT(SCHEMA_NAME(schema_id),'.', name) AS table_name, is_memory_optimized, temporal_type_desc 
FROM sys.tables WHERE name IN ('Product','ProductHistory');
--Here is the code which you can use to find its name and properties
SELECT CONCAT(SCHEMA_NAME(schema_id),'.', name) AS table_name, internal_type_desc FROM  sys.internal_tables WHERE name = CONCAT('memory_optimized_history_table_', OBJECT_ID('dbo.Product'));

--Use the following code to create a native compiled stored procedure that handles inserting and updating products:
CREATE OR ALTER PROCEDURE dbo.SaveProduct  
(   
@ProductId INT,
@ProductName NVARCHAR(50),
@Price MONEY
)   
WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER   
AS    
   BEGIN ATOMIC WITH   
   (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'English')   
	UPDATE dbo.Product SET ProductName = @ProductName, Price = @Price   
	WHERE ProductId = @ProductId
	IF @@ROWCOUNT = 0
		INSERT INTO dbo.Product(ProductId,ProductName,Price) VALUES (@ProductId, @ProductName, @Price);
END
GO

--Now you can for instance add two rows and update one of it by using the above procedure:
EXEC dbo.SaveProduct 1, N'Home Jersey Benfica', 89.95;
EXEC dbo.SaveProduct 2, N'Away Jersey Juventus', 89.95;
EXEC dbo.SaveProduct 1, N'Home Jersey Benfica', 79.95;

/*Result:
ProductId ProductName          Price
--------- -------------------  ------
2         Away Jersey Juventus 89.95
1         Home Jersey Benfica  79.95

ProductId ProductName           Price  ValidFrom           ValidTo
--------- --------------------- ------ ------------------- -------------
1         Home Jersey Benfica   89.95  2016-08-20 10:29:52 2016-08-20 10:29:53
*/
