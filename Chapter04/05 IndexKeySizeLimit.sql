--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide
--------	Chapter 04 - Transact-SQL Enhancements
--------		Enhanced DML and DDL Statements
--------		Nonclustered Index Key Size Limit
--------------------------------------------------------------------

------------------------------------------------
--- SQL Server 2014 (Index Limit 900 bytes)
------------------------------------------------
USE tempdb;
CREATE TABLE dbo.T1(id INT NOT NULL PRIMARY KEY CLUSTERED, c1 NVARCHAR(500) NULL, c2 NVARCHAR(851) NULL);
GO
--Create index on the column c1
CREATE INDEX ix1 ON dbo.T1(c1);
/*Result:
Warning! The maximum key length is 900 bytes. The index 'ix1' has maximum length of 1000 bytes. For some combination of large values, the insert/update operation will fail.
*/
--
INSERT INTO dbo.T1(id,c1, c2) VALUES(1, N'Mila', N'Vasilije');
/*Result:
(1 row(s) affected)
*/
INSERT INTO dbo.T1(id,c1, c2) VALUES(2,REPLICATE('Mila', 113), NULL);
/*Result:
--Msg 1946, Level 16, State 3, Line 9
--Operation failed. The index entry of length 904 bytes for the index 'ix1' exceeds the maximum length of 900 bytes.
*/

--Clean up
DROP TABLE dbo.T1

------------------------------------------------
--- SQL Server 2016 (Index Limit 1.700 bytes)
------------------------------------------------

USE WideWorldImporters;

--Create sample table with a column which length is more than 900 bytes and another with more than 1700 bytes
DROP TABLE IF EXISTS dbo.T1;
CREATE TABLE dbo.T1(id INT NOT NULL PRIMARY KEY CLUSTERED, c1 VARCHAR(1000) NULL, c2 VARCHAR(1701) NULL );

--Create index on the first column
CREATE INDEX ix1 ON dbo.T1(c1);
/*Result:
Command(s) completed successfully.
*/

--Create index on the second column
CREATE INDEX ix2 ON dbo.T1(c2);
/*Result:
Warning! The maximum key length for a nonclustered index is 1700 bytes. The index 'ix2' has maximum length of 1701 bytes. For some combination of large values, the insert/update operation will fail.
*/

--insert some rows
INSERT INTO dbo.T1(id,c1, c2) VALUES(1,'Mila', 'Vasilije');
/*Result:
(1 row(s) affected)
*/
--insert some larger rows
INSERT INTO dbo.T1(id,c1, c2) VALUES(2,REPLICATE('Mila', 250), NULL);
/*Result:
(1 row(s) affected)
The lenght of the value for the column c1 is 1000 and it is stored in the table without errors or warnings. Prior to SQL Server 2016 it would be an error
*/
INSERT INTO dbo.T1(id,c1, c2) VALUES(2,REPLICATE('Mila', 250), REPLICATE('Vasilije', 213));
/*Result:
Msg 8152, Level 16, State 14, Line 148
String or binary data would be truncated.
The statement has been terminated.

The length of the value for the column c2 is 1704 bytes and violates the new limit for the size of nonclustered keys
*/

--Cleanup
DROP TABLE IF EXISTS dbo.T1;
GO