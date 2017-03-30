------------------------------------------------------
-------   SQL Server 2016 Developer’s Guide    -------
------   Chapter 08 - Tightening the Security  -------
------------------------------------------------------

----------------------------------------------------
-- Section 3: Row-Level Security
----------------------------------------------------

-- Setup
-- Demo database
USE master;
IF DB_ID(N'RLSDemo') IS NULL
   CREATE DATABASE RLSDemo;
GO
USE RLSDemo;
GO

-- Database users
CREATE USER SalesUser1 WITHOUT LOGIN;
CREATE USER SalesUser2 WITHOUT LOGIN;
CREATE USER SalesUser3 WITHOUT LOGIN;
CREATE USER SalesManager WITHOUT LOGIN;
GO

-- Employees table
CREATE TABLE dbo.Employees
(
 EmployeeId   INT          NOT NULL PRIMARY KEY,
 EmployeeName NVARCHAR(10) NOT NULL,
 SalesRegion  NVARCHAR(3)  NOT NULL,
 SalaryRank   INT          NOT NULL
);
GO
-- Demo rows
INSERT INTO dbo.Employees
 (EmployeeId, EmployeeName, SalesRegion, SalaryRank)
VALUES
 (1, N'SalesUser1', N'USA', 5),
 (2, N'SalesUser2', N'USA', 4),
 (3, N'SalesUser3', N'EU', 6);
-- Check the data
SELECT *
FROM dbo.Employees;
GO

-- Customers table
CREATE TABLE dbo.Customers
(
 CustomerId   INT          NOT NULL PRIMARY KEY,
 CustomerName NVARCHAR(10) NOT NULL,
 SalesRegion  NVARCHAR(3)  NOT NULL
);
GO
-- Demo rows
INSERT INTO dbo.Customers
 (CustomerId, CustomerName, SalesRegion)
VALUES
 (1, N'Customer01', N'USA'),
 (2, N'Customer02', N'USA'),
 (3, N'Customer03', N'EU'),
 (4, N'Customer04', N'EU');
-- Check the data
SELECT *
FROM dbo.Customers;
GO

-- No permissions yet - database users can't see any rows, except dbo, of course
SELECT * FROM dbo.Employees;
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesUser1';
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesUser2';
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesUser3';
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesManager';
GO

-- Programmable objects for security
-- SELECT procedure
CREATE PROCEDURE dbo.SelectEmployees
AS
SELECT *
FROM dbo.Employees
WHERE EmployeeName = USER_NAME()
   OR USER_NAME() = N'SalesManager';
GO
-- Grant the permission to execute the procedure
GRANT EXECUTE ON dbo.SelectEmployees
 TO SalesUser1, SalesUser2, SalesUser3, SalesManager;
GO

-- Users still can't see the data directly
SELECT * FROM dbo.Employees;
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesUser1';
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesUser2';
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesUser3';
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesManager';
GO

-- Users can see the data thought the procedure
-- Note that dbo can't see any rows through the procedure
EXEC dbo.SelectEmployees;
EXECUTE AS USER = N'SalesUser1' EXEC dbo.SelectEmployees;
REVERT;
EXECUTE AS USER = N'SalesUser2' EXEC dbo.SelectEmployees;
REVERT;
EXECUTE AS USER = N'SalesUser3' EXEC dbo.SelectEmployees;
REVERT;
-- SalesManager sees all rows
EXECUTE AS USER = N'SalesManager' EXEC dbo.SelectEmployees;
REVERT;
GO

-- Broken ownership chain
-- SELECT procedure
CREATE PROCEDURE dbo.SelectEmployeesDynamic
AS
DECLARE @sqlStatement AS NVARCHAR(4000);
SET @sqlStatement = N'
SELECT *
FROM dbo.Employees
WHERE EmployeeName = USER_NAME();'
EXEC(@sqlStatement);
GO
-- Grant the permission to execute the procedure
GRANT EXECUTE ON dbo.SelectEmployeesDynamic
 TO SalesUser1, SalesUser2, SalesUser3, SalesManager;
GO

-- Execute in different contexts
-- dbo can execute, does not see the data
EXEC dbo.SelectEmployeesDynamic;
-- Other users get an error
EXECUTE AS USER = N'SalesUser1' EXEC dbo.SelectEmployeesDynamic;
REVERT;
EXECUTE AS USER = N'SalesUser2' EXEC dbo.SelectEmployeesDynamic;
REVERT;
EXECUTE AS USER = N'SalesUser3' EXEC dbo.SelectEmployeesDynamic;
REVERT;
EXECUTE AS USER = N'SalesManager' EXEC dbo.SelectEmployeesDynamic;
REVERT;
GO
/*
Msg 229, Level 14, State 5, Line 141
The SELECT permission was denied on the object 'Employees', database 'RLSDemo', schema 'dbo'.
*/


-- SQL 2016 row-level security

-- Grant the permission to see the data
GRANT SELECT ON dbo.Employees
 TO SalesUser1, SalesUser2, SalesUser3, SalesManager;
GRANT SELECT ON dbo.Customers
 TO SalesUser1, SalesUser2, SalesUser3, SalesManager;
GO

-- Everybody can see all of the data
SELECT * FROM dbo.Employees;
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesUser1';
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesUser2';
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesUser3';
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesManager';
GO

-- Now create a separate schema for security functions
CREATE SCHEMA Security;  
GO  

-- Function to limit the rows in the dbo.Employees table
-- Add dbo to those who can see all rows
CREATE FUNCTION Security.EmployeesRLS(@UserName AS NVARCHAR(10))  
RETURNS TABLE  
WITH SCHEMABINDING  
AS  
RETURN SELECT 1 AS SecurityPredicateResult  
 WHERE @UserName = USER_NAME()
    OR USER_NAME() IN (N'SalesManager', N'dbo');  
GO

-- Security policy for filtering employee rows
CREATE SECURITY POLICY EmployeesFilter  
ADD FILTER PREDICATE Security.EmployeesRLS(EmployeeName)   
ON dbo.Employees  
WITH (STATE = ON);  
GO

-- Test the RLS filter
SELECT * FROM dbo.Employees;
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesUser1';
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesUser2';
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesUser3';
EXECUTE (N'SELECT * FROM dbo.Employees') AS USER = N'SalesManager';
GO

-- Carefully crafted queries
-- SalesUser1 checks whether an user with SalaryRank = 6 exists
EXECUTE (N'SELECT * FROM dbo.Employees 
           WHERE SalaryRank = 6')
AS USER = N'SalesUser1';
-- Empty rowset
EXECUTE (N'SELECT * FROM dbo.Employees 
           WHERE SalaryRank / (SalaryRank - 6) = 0')
AS USER = N'SalesUser1';
/*
Msg 8134, Level 16, State 1, Line 200
Divide by zero error encountered.
*/
-- SalesUser1 now knows there is an employee with SalaryRank = 6
GO

-- RLS function with a join
CREATE FUNCTION Security.CustomersRLS(@CustomerId AS INT)  
RETURNS TABLE  
WITH SCHEMABINDING  
AS  
RETURN 
SELECT 1 AS SecurityPredicateResult  
FROM dbo.Customers AS c
 CROSS APPLY(
  SELECT TOP 1 1
  FROM dbo.Employees AS e
  WHERE c.SalesRegion = e.SalesRegion
    AND (e.EmployeeName = USER_NAME()
         OR USER_NAME() IN (N'SalesManager', N'dbo')))
 AS E(EmployeesResult)
WHERE c.CustomerId = @CustomerId;  
GO

-- Security policy for filtering customer rows
CREATE SECURITY POLICY CustomersFilter  
ADD FILTER PREDICATE Security.CustomersRLS(CustomerId)   
ON dbo.Customers  
WITH (STATE = ON);  
GO

-- Test the RLS filter
SELECT * FROM dbo.Customers;
EXECUTE (N'SELECT * FROM dbo.Customers') AS USER = N'SalesUser1';
EXECUTE (N'SELECT * FROM dbo.Customers') AS USER = N'SalesUser2';
EXECUTE (N'SELECT * FROM dbo.Customers') AS USER = N'SalesUser3';
EXECUTE (N'SELECT * FROM dbo.Customers') AS USER = N'SalesManager';
GO

-- Block DML
-- Give permissions to users
GRANT INSERT, UPDATE, DELETE ON dbo.Customers
 TO SalesUser1, SalesUser2, SalesUser3, SalesManager;
GO
-- Try to delete as SalesUser1 a row that this user does not see
EXECUTE (N'DELETE FROM dbo.Customers WHERE CustomerId = 3')
 AS USER = N'SalesUser1';
-- 0 row(s) affected - SELECT filter works

-- Try to update as SalesUser1 a row that this user does not see
EXECUTE (N'UPDATE dbo.Customers
              SET CustomerName =' + '''' + 'Updated' + '''' +
           'WHERE CustomerId = 3')
 AS USER = N'SalesUser1';
-- 0 row(s) affected - SELECT filter works

-- Try to insert as SalesUser1 a row that this user does not see
EXECUTE (N'INSERT INTO dbo.Customers
            (CustomerId, CustomerName, SalesRegion)
		   VALUES(5, ' + '''' + 'Customer05' + '''' + ',' +
		          '''' + 'EU' + '''' + ');'
        ) AS USER = N'SalesUser1';
-- (1 row(s) affected) - insert succeeded
-- Try to update as SalesUser1 a row that this user does see, but would not see after the update
EXECUTE (N'UPDATE dbo.Customers
              SET SalesRegion =' + '''' + 'EU' + '''' +
           'WHERE CustomerId = 2')
 AS USER = N'SalesUser1';
 -- 1 row(s) affected - update succeeded
 -- dbo sees all of the rows
SELECT * FROM dbo.Customers;
-- Yet, SalesUser1 does not see the row (s)he just inserted and updated
EXECUTE (N'SELECT * FROM dbo.Customers') AS USER = N'SalesUser1';
GO

-- Block such inserts and updates
ALTER SECURITY POLICY CustomersFilter  
ADD BLOCK PREDICATE Security.CustomersRLS(CustomerId)   
ON dbo.Customers AFTER INSERT,
ADD BLOCK PREDICATE Security.CustomersRLS(CustomerId)   
ON dbo.Customers AFTER UPDATE;  
GO

-- Try to insert as SalesUser1 a row that this user does not see
EXECUTE (N'INSERT INTO dbo.Customers
            (CustomerId, CustomerName, SalesRegion)
		   VALUES(6, ' + '''' + 'Customer06' + '''' + ',' +
		          '''' + 'EU' + '''' + ');'
        ) AS USER = N'SalesUser1';
-- Error 33504

-- Try to update as SalesUser1 a row that this user does see, but would not see after the update
EXECUTE (N'UPDATE dbo.Customers
              SET SalesRegion =' + '''' + 'EU' + '''' +
           'WHERE CustomerId = 1')
 AS USER = N'SalesUser1';
-- Error 33504

-- No changes in the table
SELECT * FROM dbo.Customers;
-- SalesUser1 still sees USA customers only
EXECUTE (N'SELECT * FROM dbo.Customers') AS USER = N'SalesUser1';
GO


-- Clean up 
USE master;
IF DB_ID(N'RLSDemo') IS NOT NULL
   ALTER DATABASE RLSDemo SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
   DROP DATABASE RLSDemo;
GO
