3
4
5
6
7
8
9

--------------------------------------------------------------------
--------    SQL Server 2016 Developer’s Guide
--------    Chapter 06 - Stretch Databases
------		Enabling Stretch DB for a table
--------------------------------------------------------------------
 
-------------------------------------------------------------
------Enable Stretch DB feature on the instance level
-------------------------------------------------------------

EXEC sys.sp_configure N'remote data archive', '1';
RECONFIGURE;
GO

-------------------------------------------------------------
------Enabling Stretch Database at the Database Level
-------------------------------------------------------------

--The following code creates a database master key for the sample database Mila.
USE Mila; 
GO  
CREATE MASTER KEY ENCRYPTION BY PASSWORD='<very secure password>'; 


--Now, you need to create a credential.
CREATE DATABASE SCOPED CREDENTIAL MilaStretchCredential  
WITH 
IDENTITY = 'Vasilije', 
SECRET = '<very secure password>';

--Now you can finally enable Stretch DB feature by using ALTER DATABASE statement.  
--You need to set REMOTE_DATA_ARCHIVE and to define two parameters: Azure server and just created database scoped credential. 
--Here is the code that can be used to enable Stretch DB feature for the database Mila.
ALTER DATABASE Mila  
    SET REMOTE_DATA_ARCHIVE = ON  
        (  
            SERVER = 'MyStretchDatabaseServer.database.windows.net',  
            CREDENTIAL = [MilaStretchCredential] 
        );  



----------------------------------------------------
-- Enabling Stretch Database for a Table
----------------------------------------------------
USE SQLServer2016DevsGuideStretchDB;
GO
CREATE TABLE dbo.T1(
id INT NOT NULL, 
c1 VARCHAR(10) NOT NULL,
c2 INT NULL,
CONSTRAINT PK_T1 PRIMARY KEY CLUSTERED (id)
)
    WITH ( REMOTE_DATA_ARCHIVE = ON (MIGRATION_STATE = OUTBOUND)) ;  
GO
 
CREATE TABLE dbo.T2(
id INT NOT NULL, 
c1 VARCHAR(10) NOT NULL,
c2 DATETIME NOT NULL,
CONSTRAINT PK_T2 PRIMARY KEY CLUSTERED (id)
)
    WITH ( REMOTE_DATA_ARCHIVE = ON (
    FILTER_PREDICATE = dbo.StretchPredicate(c2), 
    MIGRATION_STATE = OUTBOUND)) ;  
GO


--The following code creates a filter function that can be used to migrate 
--all rows where the column col has value older than 1st June 2016
CREATE FUNCTION dbo.StretchFilter(@col DATETIME)  
RETURNS TABLE  
WITH SCHEMABINDING   
AS   
       RETURN SELECT 1 AS is_eligible 
WHERE @col < CONVERT(DATETIME, '01.06.2016', 104);

--The following code creates a filter function that can be used to migrate 
--all rows where the column status has values 2 or 3. (cancelled and done)
CREATE FUNCTION dbo.StretchFilter(@col TINYINT)  
RETURNS TABLE  
WITH SCHEMABINDING   
AS   
       RETURN SELECT 1 AS is_eligible 
WHERE @col IN (2, 3);


--Sliding window implementation for filter function
--create a filter function to remove all rows older than 1st July 2016. 
CREATE FUNCTION dbo.StretchFilter20160701(@col DATETIME)  
RETURNS TABLE  
WITH SCHEMABINDING   
AS   
       RETURN SELECT 1 AS is_eligible 
WHERE @col < CONVERT(DATETIME, '01.07.2016', 104);
  
--And assign it to the table T1:
ALTER TABLE dbo.T1   
SET (REMOTE_DATA_ARCHIVE = ON   
    (FILTER_PREDICATE = dbo.StretchFilter20160701 (col1),
     MIGRATION_STATE = OUTBOUND   
     )  
);  

--Since you used SCHEMABINDING option, you cannot alter the function. Therefore, you need to create a new function. 
--The following code creates a new function dbo.StretchFilter20160702:
CREATE FUNCTION dbo.StretchFilter20160702(@col DATETIME)  
RETURNS TABLE  
WITH SCHEMABINDING   
AS   
       RETURN SELECT 1 AS is_eligible 
WHERE @col < CONVERT(DATETIME, '01.07.2016', 104);

--Now, you need to replace the function:
ALTER TABLE dbo.T1   
SET (REMOTE_DATA_ARCHIVE = ON   
    (FILTER_PREDICATE = dbo.StretchFilter20160702 (col1),
     MIGRATION_STATE = OUTBOUND   
     )  
);  

--And finally, to remove the previous function:
DROP FUNCTION IF EXISTS dbo.StretchFilter20160701;


--Disable Stretch Database for Tables by Using Transact-SQL
--You can use Transact-SQL to perform the same action. 
--The following code examples instructs SQL Server to disable Stretch DB feature for the stretch table T1, 
--but to transfer already migrated data for the table to the local database first:
USE MyStrecthDB;
GO
ALTER TABLE dbo.T1 SET (REMOTE_DATA_ARCHIVE (MIGRATION_STATE = INBOUND)); 

--If you don’t need already migrated data (or you want to avoid data transfer costs) use the following code:
USE MyStrecthDB;
GO
ALTER TABLE dbo.T1 SET (REMOTE_DATA_ARCHIVE = OFF_WITHOUT_DATA_RECOVERY (MIGRATION_STATE = PAUSED)); 

--Disable Stretch Database for a Database
ALTER DATABASE MyStrecthDB SET REMOTE_DATA_ARCHIVE = OFF;  

