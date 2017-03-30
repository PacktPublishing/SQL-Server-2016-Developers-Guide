 --------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide
--------	Chapter 05 - JSON Support
--------			JSON Performance
--------------------------------------------------------------------

--------------------------------------------------------------------
-- JSON and Computed Columns and Indexes 
--------------------------------------------------------------------
USE WideWorldImporters;
 DROP TABLE IF EXISTS dbo.T1;
 CREATE TABLE dbo.T1(
 id INT NOT NULL IDENTITY,
 info NVARCHAR(2000) NOT NULL,
 CONSTRAINT PK_T1 PRIMARY KEY CLUSTERED(id)
 );
INSERT INTO dbo.T1
SELECT c1 FROM dbo.GetNums(4000)
CROSS APPLY(
SELECT
 (SELECT PersonID, FullName,EmailAddress,PhoneNumber,IsPermittedToLogon
 FROM Application.People WHERE PersonID = n FOR JSON AUTO, WITHOUT_ARRAY_WRAPPER) c1
 ) x
 WHERE c1 IS NOT NULL;
 
 --Simple Query
 SELECT id, info
 FROM dbo.T1
 WHERE JSON_VALUE(info,'$.FullName')='Vilma Niva';
 /*
 Result:
 34	{"PersonID":34,"FullName":"Vilma Niva","EmailAddress":"vilman@litwareinc.com","PhoneNumber":"(209) 555-0103","IsPermittedToLogon":false}
 Execution Plan: Clustered Index Scan
 Logical Reads: 45
 */
 --Add computed column
 ALTER TABLE dbo.T1 ADD jsonFullName AS JSON_VALUE(info,'$.FullName');
 GO
 --Add  index on the computed column
 CREATE INDEX IX1 ON dbo.T1(jsonFullName);
 /*
 Result:
 Warning! The maximum key length for a nonclustered index is 1700 bytes. The index 'IX1' has maximum length of 8000 bytes. For some combination of large values, the insert/update operation will fail.
Table 'Worktable'. Scan count 0, logical reads 0, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
Table 'T1'. Scan count 1, logical reads 45, physical reads 0, read-ahead reads 0, lob logical reads 0, lob physical reads 0, lob read-ahead reads 0.
*/
--try query again
 SELECT id, info
 FROM dbo.T1
 WHERE JSON_VALUE(info,'$.FullName') = 'Vilma Niva';
/*
Result:
34	{"PersonID":34,"FullName":"Vilma Niva","EmailAddress":"vilman@litwareinc.com","PhoneNumber":"(209) 555-0103","IsPermittedToLogon":false}
Execution Plan: Index Seek (IX1) + Key Lookup
Logical Reads: 4
*/

-------------------------------
--Fulltext Index
-------------------------------
--create FT catalog and index
CREATE FULLTEXT CATALOG ft AS DEFAULT;  
CREATE FULLTEXT INDEX ON dbo.T1(info) KEY INDEX PK_T1 ON ft;

--check the query
SELECT id, info
FROM dbo.T1
WHERE CONTAINS(info,'NEAR(FullName,"Vilma")');
/*
Result:
34	{"PersonID":34,"FullName":"Vilma Niva","EmailAddress":"vilman@litwareinc.com","PhoneNumber":"(209) 555-0103","IsPermittedToLogon":false}
Execution Plan: FulltextIndex + Clustered Index Seek
Logical Reads: 4
*/
SELECT id, info
FROM dbo.T1
WHERE CONTAINS(info,'NEAR(PhoneNumber,"(209) 555-0103")');
/*
Result:
34	{"PersonID":34,"FullName":"Vilma Niva","EmailAddress":"vilman@litwareinc.com","PhoneNumber":"(209) 555-0103","IsPermittedToLogon":false}
Execution Plan: FulltextIndex + Clustered Index Seek
Logical Reads: 4
*/

--Ensure that you have dropped the table used in this example:
USE WideWorldImporters;
DROP TABLE IF EXISTS dbo.T1; 
