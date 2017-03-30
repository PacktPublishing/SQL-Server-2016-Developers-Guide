--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide
--------	Chapter 04 - Transact-SQL Enhancements
--------		Enhanced DML and DDL Statements
--------				TRUNCATE TABLE
--------------------------------------------------------------------


--In SQL Server 2016 the TRINCATE TABLE statement has been extended so that 
--you can specify partitions from which rows have to be removed. 

 --Let's create partitioning infrastructure (partition function and schema)
USE WideWorldImporters;
--To populate the table efficiently you can use the function GetNums created by Itzik Ben-Gan. 
--The function is available at http://tsql.solidq.com/SourceCodes/GetNums.txt. Here is the function definition:
-------------------------------------------------------------
-- © Itzik Ben-Gan
-------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.GetNums(@n AS BIGINT) RETURNS TABLE
AS
RETURN
  WITH
  L0   AS(SELECT 1 AS c UNION ALL SELECT 1),
  L1   AS(SELECT 1 AS c FROM L0 AS A CROSS JOIN L0 AS B),
  L2   AS(SELECT 1 AS c FROM L1 AS A CROSS JOIN L1 AS B),
  L3   AS(SELECT 1 AS c FROM L2 AS A CROSS JOIN L2 AS B),
  L4   AS(SELECT 1 AS c FROM L3 AS A CROSS JOIN L3 AS B),
  L5   AS(SELECT 1 AS c FROM L4 AS A CROSS JOIN L4 AS B),
  Nums AS(SELECT ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS n FROM L5)
  SELECT n FROM Nums WHERE n <= @n;
GO

--Create and populate sample table with 10M rows
DROP TABLE IF EXISTS dbo.Orders;
CREATE TABLE dbo.Orders(
id INT IDENTITY(1,1) NOT NULL,
custid INT NOT NULL,
orderdate DATETIME NOT NULL,
amount MONEY NOT NULL,
rest CHAR(100) NOT NULL DEFAULT 'test',
CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (id ASC)
);
GO
INSERT INTO dbo.Orders(custid,orderdate,amount)
SELECT 
	1 + ABS(CHECKSUM(NEWID())) % 1000 AS custid,
	DATEADD(minute,    -ABS(CHECKSUM(NEWID())) % 5000000, '20160630') AS orderdate,
	50 + ABS(CHECKSUM(NEWID())) % 1000 AS amount
FROM dbo.GetNums(10000000)
GO

IF EXISTS(SELECT 1 FROM sys.partition_schemes WHERE name = N'PSchTest')
	DROP PARTITION SCHEME PSchTest;
GO
IF EXISTS(SELECT 1 FROM sys.partition_functions WHERE name = N'PFTest')
	DROP PARTITION FUNCTION PFTest;
GO

CREATE PARTITION FUNCTION PFTest (DATETIME)
AS RANGE RIGHT FOR VALUES ('20100101', '20110101', '20120101','20130101','20140101','20150101','20160101')
GO

CREATE PARTITION SCHEME PSchTest 
AS PARTITION PFTest ALL TO ([PRIMARY]) 
GO

--Now we need to create a cluster index on the partition schema. Therefore we need to remove existing clustered index
ALTER TABLE dbo.Orders DROP CONSTRAINT IF EXISTS PK_Orders;
GO
--Create new clustered index
CREATE CLUSTERED INDEX CL_Orders ON dbo.Orders(orderdate) ON PSchTest(orderdate);
GO

--Let's check the data distribution after the index creation:
SELECT partition_number, rows 
FROM sys.partitions
WHERE object_id = OBJECT_ID('dbo.Orders');
/*Result:

1	3164914
2	1050638
3	1049804
4	1054192
5	1054126
6	1052339
7	1051029
8	522958
*/

--Remove all rows from the partitions 1,2 and 4
TRUNCATE TABLE dbo.Orders WITH (PARTITIONS (1, 2, 4));  

--Let's check the data distribution after the TRUNCATE TABLE:
SELECT partition_number, rows 
FROM sys.partitions
WHERE object_id = OBJECT_ID('dbo.Orders');

/*Result:

1	0
2	0
3	1049804
4	0
5	1054126
6	1052339
7	1051029
8	522958
*/

--Remove all rows from the partitions 5,6 and 7
TRUNCATE TABLE dbo.Orders WITH (PARTITIONS (5 TO 7)); 

--Let's check the data distribution after the TRUNCATE TABLE:
SELECT partition_number, rows 
FROM sys.partitions
WHERE object_id = OBJECT_ID('dbo.Orders');

/*Result:

1	0
2	0
3	1049804
4	0
5	0
6	0
7	0
8	522958
*/

--Cleanup the table
DROP TABLE IF EXISTS dbo.Orders;
GO

