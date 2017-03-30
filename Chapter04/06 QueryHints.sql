--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide
--------	Chapter 04 - Transact-SQL Enhancements
--------		Enhanced DML and DDL Statements
--------			New Query Hints
--------------------------------------------------------------------


----------------------------------------------------------------
--NO_PERFORMANCE_SPOOL
---------------------------------------------------------------

USE WideWorldImporters;
--create UDF for spliting comma separated list of integers
DROP FUNCTION IF EXISTS dbo.ParseInt;
GO
CREATE FUNCTION dbo.ParseInt
(
   @List       VARCHAR(MAX),
   @Delimiter  CHAR(1)
)
RETURNS @Items TABLE
(
   Item INT
)
AS
BEGIN
   DECLARE @Item VARCHAR(12), @Pos  INT;
   WHILE LEN(@List)>0
   BEGIN
       SET @Pos = CHARINDEX(@Delimiter, @List);
       IF @Pos = 0 SET @Pos = LEN(@List)+1;
       SET @Item = LEFT(@List, @Pos-1);
       INSERT @Items SELECT CONVERT(INT, LTRIM(RTRIM(@Item)));
       SET @List = SUBSTRING(@List, @Pos + LEN(@Delimiter), LEN(@List));
       IF LEN(@List) = 0 BREAK;
   END
   RETURN;
END
GO

--filter orders with the sales persons from the list @SalesPersonList
SET SHOWPLAN_TEXT ON; --use this to show execution plan in he text format
DECLARE @SalesPersonList VARCHAR(MAX) = '3,6,8';
SELECT o.*
FROM Sales.Orders o
INNER JOIN dbo.ParseInt(@SalesPersonList,',') a ON a.Item = o.SalespersonPersonID 
ORDER BY o.OrderID;
GO

/*Result:
in the execution plan you can see the Table Spool operator
  |--Sequence
       |--Table-valued function(OBJECT:([WideWorldImporters].[dbo].[ParseInt] AS [a]))
       |--Nested Loops(Inner Join, WHERE:([WideWorldImporters].[Sales].[Orders].[SalespersonPersonID] as [o].[SalespersonPersonID]=[WideWorldImporters].[dbo].[ParseInt].[Item] as [a].[Item]))
            |--Clustered Index Scan(OBJECT:([WideWorldImporters].[Sales].[Orders].[PK_Sales_Orders] AS [o]), ORDERED FORWARD)
            |--Table Spool
                 |--Table Scan(OBJECT:([WideWorldImporters].[dbo].[ParseInt] AS [a]))
*/
--when you repeat the query with the query hint NO_PERFORMANCE_SPOOL
DECLARE @SalesPersonList VARCHAR(MAX) = '3,6,8';
SELECT o.*
FROM Sales.Orders o
INNER JOIN dbo.ParseInt(@SalesPersonList,',') a ON a.Item = o.SalespersonPersonID 
ORDER BY o.OrderID
OPTION (NO_PERFORMANCE_SPOOL);
GO
/*Result:
there is no Table Spool operator in the execution plan
  |--Sequence
       |--Table-valued function(OBJECT:([WideWorldImporters].[dbo].[ParseInt] AS [a]))
       |--Nested Loops(Inner Join, WHERE:([WideWorldImporters].[Sales].[Orders].[SalespersonPersonID] as [o].[SalespersonPersonID]=[WideWorldImporters].[dbo].[ParseInt].[Item] as [a].[Item]))
            |--Clustered Index Scan(OBJECT:([WideWorldImporters].[Sales].[Orders].[PK_Sales_Orders] AS [o]), ORDERED FORWARD)
            |--Table Scan(OBJECT:([WideWorldImporters].[dbo].[ParseInt] AS [a]))
*/

--If the Spool operator is required in a plan to enforce the validity and correctness, the hint will be ignored

--create test table
DROP TABLE IF EXISTS dbo.T1;
CREATE TABLE dbo.T1(
id INT NOT NULL,
c1 INT NOT NULL,
)
GO
INSERT INTO dbo.T1(id, c1) VALUES(1, 5),(1, 10);
GO
--add existing rows where ID < 10 again 
INSERT INTO dbo.T1(id, c1)
SELECT id, c1 FROM dbo.T1
WHERE id < 10;

/*Result:
in the execution plan you can see the Table Spool operator
 |--Table Insert(OBJECT:([WideWorldImporters].[dbo].[T1]), SET:([WideWorldImporters].[dbo].[T1].[id] = [WideWorldImporters].[dbo].[T1].[id],[WideWorldImporters].[dbo].[T1].[c1] = [WideWorldImporters].[dbo].[T1].[c1]))
       |--Table Spool
            |--Table Scan(OBJECT:([WideWorldImporters].[dbo].[T1]), WHERE:([WideWorldImporters].[dbo].[T1].[id]<(10)))
*/

--when you repeat the query with the query hint NO_PERFORMANCE_SPOOL
INSERT INTO dbo.T1(id, c1)
SELECT id, c1 FROM dbo.T1
WHERE id < 10
OPTION (NO_PERFORMANCE_SPOOL);
/*Result:
Table Spool operator is still in the execution plan. The execution plan is identical to the previous one
  |--Table Insert(OBJECT:([WideWorldImporters].[dbo].[T1]), SET:([WideWorldImporters].[dbo].[T1].[id] = [WideWorldImporters].[dbo].[T1].[id],[WideWorldImporters].[dbo].[T1].[c1] = [WideWorldImporters].[dbo].[T1].[c1]))
       |--Table Spool
            |--Table Scan(OBJECT:([WideWorldImporters].[dbo].[T1]), WHERE:([WideWorldImporters].[dbo].[T1].[id]<(10)))
*/

SET SHOWPLAN_TEXT OFF; --back to the default option

--Cleanup
DROP TABLE IF EXISTS dbo.T1;
GO

----------------------------------------------------------------
--MAX_GRANT_PERCENT
----------------------------------------------------------------

--create test table and populate it with 10M rows
DROP TABLE IF EXISTS dbo.T1;
CREATE TABLE dbo.T1(
id INT NOT NULL,
c1 INT NOT NULL,
c2 TINYINT NOT NULL DEFAULT 1,
c3 CHAR(100) NOT NULL DEFAULT 'test',
CONSTRAINT PK_T1 PRIMARY KEY CLUSTERED (id ASC)
);
GO
INSERT INTO dbo.T1(id, c1)
SELECT 
	n AS id,
	1 + ABS(CHECKSUM(NEWID())) % 10000 AS c1
FROM dbo.GetNums(10000000);
GO
CREATE INDEX ix1 ON dbo.T1(c2);
GO

--Return all rows from the table T1 that have values 0 or 2 in the column c2
SELECT * FROM dbo.T1 WHERE c2 IN (0, 2) ORDER BY c1;

/*Result (on my test server, you might get different values)
No rows returned.
The execution plan is Clustered Index Scan followed by the Sort operator that has to process 10M rows
Memory Grant 1906728 KB => 1.9 GB
Estimated Number of Rows: 10M
Estimated Subtree Cost: 2493.24
Logical Reads: 147.607
*/

--use the hint MAX_GRANT_PERCENT
SELECT * FROM dbo.T1 WHERE c2 IN (0, 2) ORDER BY c1 OPTION (MAX_GRANT_PERCENT=0.001);

/*Result (on my test server, you might get different values)
No rows returned.
The execution plan is the same: Clustered Index Scan followed by the Sort operator that has to process 10M rows
Memory Grant dropped to 512 KB
Estimated Number of Rows is still 10M
Estimated Subtree Cost: 2493.24
Logical Reads: 147.607
*/

--MAX_GRANT_PERCENT reduce wasting of memory, but don't change the plan or the estimation
--Solution 1 (use the old CE)
SELECT * FROM dbo.T1 WHERE c2 IN (0, 2) ORDER BY c1 OPTION (QUERYTRACEON 9481);
/*Result (on my test server, you might get different values)
No rows returned.
The execution plan is the same: Nested Loop followed by the Sort operator that has to process one row
Memory Grant dropped to 1024 KB
Estimated Number of Rows: 1
Estimated Subtree Cost: 0.0179
Logical Reads: 6
*/

--Solution 2 (workaround with new CE)
SELECT * FROM dbo.T1 WHERE c2 = 0
UNION ALL
SELECT * FROM dbo.T1 WHERE c2 = 2
ORDER BY c1;
/*Result (on my test server, you might get different values)
No rows returned.
The execution plan is acceptable: double Nested Loop with concatenation followed by the Sort operator that has to process two rows
Memory Grant dropped to 1024 KB
Estimated Number of Rows: 1
Estimated Subtree Cost: 0.0245
Logical Reads: 6
*/
--Cleanup
DROP TABLE IF EXISTS dbo.T1;
GO