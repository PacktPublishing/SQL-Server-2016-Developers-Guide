--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide
--------	Chapter 04 - Transact-SQL Enhancements
--------		Enhanced DML and DDL Statements
--------			DROP {OBJECT} IF EXITS
--------------------------------------------------------------------

----------------------------------------------------
-- DROP {OBJECT} IF EXITS
----------------------------------------------------
--conditional drop table
USE WideWorldImporters;
DROP TABLE IF EXISTS dbo.TestTable;
CREATE TABLE dbo.TestTable(id INT NOT NULL, 
c1 VARCHAR(10) NOT NULL,
c2 INT NULL,
CONSTRAINT PK_TestTable PRIMARY KEY CLUSTERED (id)
);
GO

--conditional drop column
ALTER TABLE dbo.TestTable DROP COLUMN IF EXISTS c2;
--Check columns
SELECT name FROM sys.columns WHERE object_id = OBJECT_ID('dbo.TestTable');
/*Result:
name
----
id
c1
*/
--run the same command again
ALTER TABLE dbo.TestTable DROP COLUMN IF EXISTS c2;
/*Result:
Command(s) completed successfully.
No errors.
*/

--conditional drop constraint
ALTER TABLE dbo.TestTable DROP CONSTRAINT IF EXISTS PK_TestTable;
--Check columns
SELECT name FROM sys.key_constraints WHERE object_id = OBJECT_ID('dbo.TestTable');
/*Result:
an empty set
*/

/*
Conditional DROP statement is suppoerted for the following database objects:
AGGREGATE, ASSEMBLY, COLUMN, CONSTRAINT, DATABASE, DEFAULT, FUNCTION, INDEX, PROCEDURE, ROLE, 
RULE, SCHEMA, SECURITY POLICY, SEQUENCE, SYNONYM, TABLE, TRIGGER, TYPE, USER, VIEW
*/

--Partition function or schema cannot be dropped with the conditional DROP
USE WideWorldImporters;
CREATE PARTITION FUNCTION PartitionFunction1 (INT)
AS RANGE RIGHT FOR VALUES (1000,2000,3000)
GO

CREATE PARTITION SCHEME PartitionSchema1 
AS PARTITION PartitionFunction1 ALL TO ([PRIMARY]) 
GO

DROP PARTITION SCHEME IF EXISTS PartitionSchema1;
/*Result:
Msg 156, Level 15, State 1, Line 39
Incorrect syntax near the keyword 'IF'.
*/

DROP PARTITION FUNCTION IF EXISTS PartitionFunction1;
/*Result:
Msg 156, Level 15, State 1, Line 45
Incorrect syntax near the keyword 'IF'.
*/

--You still need to check for the existence
IF EXISTS(SELECT 1 FROM sys.partition_schemes WHERE name = N'PartitionSchema1')
	DROP PARTITION SCHEME PartitionSchema1;
GO
IF EXISTS(SELECT 1 FROM sys.partition_functions WHERE name = N'PartitionFunction1')
	DROP PARTITION FUNCTION PartitionFunction1;
GO

----------------------------------------------------
-- CREATE OR ALTER
----------------------------------------------------
CREATE OR ALTER FUNCTION dbo.GetWorldsBestCityToLiveIn()
RETURNS NVARCHAR(10)
AS
BEGIN
	RETURN N'Vienna';
END
GO

--let's invoke it
SELECT dbo.GetWorldsBestCityToLiveIn();

/*Result:
-----------
Vienna
*/
 