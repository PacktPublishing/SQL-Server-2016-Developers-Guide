--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide
--------	Chapter 04 - Transact-SQL Enhancements
--------		Enhanced DML and DDL Statements
--------			ALTER COLUMN ONLINE
--------------------------------------------------------------------


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


----------------------------------------------------------------
--ALTER COLUMN Offline (amount)
----------------------------------------------------------------

--Connection 1:
ALTER TABLE dbo.Orders ALTER COLUMN amount DECIMAL(10,2) NOT NULL;
/*Result:
Command(s) completed successfully. After 23 seconds
*/
--Connection 2:
SELECT TOP (2) id, custid, orderdate, amount
FROM dbo.Orders ORDER BY id DESC;
/*Result:
Waits - the command must wait until the alter column operation is done.
*/
--Connection 3:
SELECT request_mode, request_type, request_status, resource_type, request_owner_type
FROM sys.dm_tran_locks WHERE request_session_id = 69;
/*Result:

request_mode    request_type           request_status     resource_type                request_owner_type
-------------- ----------------------- ------------------ ---------------------------- -----------------------
S              LOCK                    GRANT              DATABASE                     SHARED_TRANSACTION_WORKSPACE
IS             LOCK                    WAIT               OBJECT                       TRANSACTION
*/

--Let's repeat the action with the NOLOCK hibt for the query in the connection 2
 
 --Connection 1:
ALTER TABLE dbo.Orders ALTER COLUMN amount MONEY NOT NULL;
/*Result:
Command(s) completed successfully. After 18 seconds
*/
--Connection 2:
SELECT TOP (10) id, custid, orderdate, amount
FROM dbo.Orders WITH (NOLOCK) ORDER BY id DESC;
/*Result:
Waits - the command must still wait until the alter column operation is done although NOLOCK hint is used.
*/
--Connection 3: (you need to replace 69 with the session ID from the second connection)
SELECT request_mode, request_type, request_status, resource_type, request_owner_type
FROM sys.dm_tran_locks WHERE request_session_id = 69;
/*Result:

request_mode    request_type        request_status     resource_type        request_owner_type
-------------- -------------------  ------------------ -------------------- -----------------------
S				LOCK				GRANT				DATABASE			SHARED_TRANSACTION_WORKSPACE
S				LOCK				GRANT				DATABASE			TRANSACTION
Sch-S			LOCK				WAIT				OBJECT				TRANSACTION
*/
-- We can see different lock types (instead of IS now is Sch-S) but the table is still not available

---------------------------------------------------------------
--ALTER COLUMN Online (amount)
----------------------------------------------------------------

--Connection 1:
ALTER TABLE dbo.Orders ALTER COLUMN amount DECIMAL(10,2) NOT NULL WITH (ONLINE = ON);
/*Result:
Command(s) completed successfully. After 45 seconds
*/
--Connection 2:
SELECT TOP (2) id, custid, orderdate, amount
FROM dbo.Orders ORDER BY id DESC;
/*Result:
10000000	468	2012-05-30 14:14:00.000	301,00
9999999	363	2013-11-06 19:08:00.000	242,00
We don't need the 3rd connection since it's clear that the table is available. The altering column took more (45 sec)
but the table is available
*/

