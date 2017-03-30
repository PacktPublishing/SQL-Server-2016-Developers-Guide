------------------------------------------------------
-------   SQL Server 2016 Developer’s Guide    -------
------   Chapter 08 - Tightening the Security  -------
------------------------------------------------------

----------------------------------------------------
-- Section 4: Dynamic Data Masking
----------------------------------------------------

-- Setup
-- Demo database
USE master;
IF DB_ID(N'DDMDemo') IS NULL
   CREATE DATABASE DDMDemo;
GO
USE DDMDemo;
GO

-- Create non-privileged users
CREATE USER SalesUser1 WITHOUT LOGIN;
CREATE USER SalesUser2 WITHOUT LOGIN;
GO

-- Create and populate a demo table
SELECT PersonID, FullName, EmailAddress,
 CAST(JSON_VALUE(CustomFields, '$.HireDate') AS DATE)
  AS HireDate,
 CAST(RAND(CHECKSUM(NEWID()) % 100000 + PersonID) * 50000 AS INT) + 20000
  AS Salary
INTO dbo.Employees
FROM WideWorldImporters.Application.People
WHERE IsEmployee = 1;
GO

-- Grant SELECT to users
GRANT SELECT ON dbo.Employees
 TO SalesUser1, SalesUser2;
GO

-- Users can see all of the data
SELECT * FROM dbo.Employees;
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesUser1';
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesUser2';
GO

-- Add masking
ALTER TABLE dbo.Employees ALTER COLUMN EmailAddress
  ADD MASKED WITH (FUNCTION = 'email()');
ALTER TABLE dbo.Employees ALTER COLUMN HireDate
  ADD MASKED WITH (FUNCTION = 'default()');
ALTER TABLE dbo.Employees ALTER COLUMN FullName
  ADD MASKED WITH (FUNCTION = 'partial(1, "&&&&&", 3)');
ALTER TABLE dbo.Employees ALTER COLUMN Salary
  ADD MASKED WITH (FUNCTION = 'random(1, 100000)');
GO

-- dbo sees unmasked data, users masked
SELECT * FROM dbo.Employees;
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesUser1';
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesUser2';
GO

-- Grant unmask to SalesUser1
GRANT UNMASK TO SalesUser1;
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesUser1';
GO

-- Grant CREATE TABLE permissions
GRANT CREATE TABLE TO SalesUser1, SalesUser2;
GRANT ALTER ON SCHEMA::dbo TO  SalesUser1, SalesUser2;
-- Select into
EXECUTE (N'SELECT * INTO dbo.SU1 FROM dbo.Employees') AS USER = N'SalesUser1';
EXECUTE (N'SELECT * INTO dbo.SU2 FROM dbo.Employees') AS USER = N'SalesUser2';
GO
-- Second table masked with static data
SELECT * FROM dbo.SU1;
SELECT * FROM dbo.SU2;
GO

-- Bypassing masking

-- System functions
EXECUTE AS USER = 'SalesUser2';
SELECT Salary AS SalaryMaskedRandom,
 EXP(LOG(Salary)) AS SalaryExpLog, 
 SQRT(SQUARE(salary)) AS SalarySqrtSquare
FROM dbo.Employees
WHERE PersonID = 2;
REVERT;

-- Filtering
EXECUTE AS USER = 'SalesUser2';
SELECT *
FROM dbo.Employees
WHERE Salary > 50000;
REVERT;

-- Clean up 
USE master;
IF DB_ID(N'DDMDemo') IS NOT NULL
   ALTER DATABASE DDMDemo SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
   DROP DATABASE DDMDemo;
GO
