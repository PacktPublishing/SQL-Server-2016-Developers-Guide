------------------------------------------------------
-------   SQL Server 2016 Developer’s Guide    -------
------   Chapter 08 - Tightening the Security  -------
------------------------------------------------------

----------------------------------------------------
-- Section 1: SQL Server Security Basics
----------------------------------------------------

-- Managing principals
-- Creating a SQL login 
-- Respecting policies is the default
-- The password does not meet Windows policy requirements 
-- It is not complex enough - same as login name
-- This will not succeed
USE master;
CREATE LOGIN LoginA WITH password='LoginA';
GO
-- Bypassing policies
CREATE LOGIN LoginA WITH password='LoginA',
 CHECK_POLICY=OFF;
GO
-- Creating a login from Windows
CREATE LOGIN [Builtin\Power Users] FROM WINDOWS;
GO
-- Check which SQL logins do not enforce policies
SELECT name, 
 type_desc, 
 is_disabled, 
 is_policy_checked, 
 is_expiration_checked
FROM sys.sql_logins
WHERE name LIKE 'L%';
GO

-- Who can see the databases list
SELECT pr.name, 
 pe.state_desc,
 pe.permission_name 
FROM sys.server_principals AS pr
 INNER JOIN sys.server_permissions AS pe
  ON pr.principal_id = pe.grantee_principal_id
WHERE permission_name = 'VIEW ANY DATABASE';
GO

-- Schemas and object name resolution
-- Creating a demo database
USE master;
IF DB_ID(N'SQLDevGuideDemoDb') IS NULL
   CREATE DATABASE SQLDevGuideDemoDb;
-- Creating LoginB (LoginA should already exist)
CREATE LOGIN LoginB WITH password='LB_ComplexPassword';
GO

-- Schemas and name resolution
-- Create a schema and two tables in different schemas
USE SQLDevGuideDemoDb;
GO
CREATE SCHEMA Sales;
GO
CREATE TABLE dbo.Table1
(id INT,
 tableContainer CHAR(5));
CREATE TABLE Sales.Table1
(id INT,
 tableContainer CHAR(5));
GO

-- A row in each table to show which table is going to be used
INSERT INTO dbo.Table1(id, tableContainer)
 VALUES(1,'dbo');
INSERT INTO Sales.Table1(id, tableContainer)
 VALUES(1,'Sales');
GO

-- Create database users
-- LoginA default schema is dbo
CREATE USER LoginA FOR LOGIN LoginA;
GO
-- LoginB default schema is Sales
CREATE USER LoginB FOR LOGIN LoginB
 WITH DEFAULT_SCHEMA = Sales;
GO
-- Grant Select to both users on both tables
GRANT SELECT ON dbo.Table1 TO LoginA;
GRANT SELECT ON Sales.Table1 TO LoginA;
GRANT SELECT ON dbo.Table1 TO LoginB;
GRANT SELECT ON Sales.Table1 TO LoginB;
GO

-- Impersonate LoginA
-- You get row from the dbo.table1
EXECUTE AS USER='LoginA';
SELECT USER_NAME() AS WhoAmI,
 id,
 tableContainer
FROM Table1;
REVERT;
GO

-- Impersonate LoginB
-- You get row from the Sales.table1
EXECUTE AS USER='LoginB';
SELECT USER_NAME() AS WhoAmI,
 id,
 tableContainer
FROM Table1;
REVERT;
GO

-- Drop the Sales.Table1 and impersonate LoginB again
-- You get row from the dbo.table1
DROP TABLE Sales.table1;
GO
EXECUTE AS USER='LoginB';
SELECT USER_NAME() AS WhoAmI,
 id,
 tableContainer
FROM Table1;
REVERT;
GO


-- Object permissions
-- Checking which permissions are applicable on user-defined type
SELECT * FROM sys.fn_builtin_permissions(N'TYPE');
-- Checking objects for which SELECT permission is applicable
SELECT * FROM sys.fn_builtin_permissions(DEFAULT) 
 WHERE permission_name = N'SELECT';
GO

-- Showing object permissions
-- Grant CONTROL on dbo.Table1 to LoginB
GRANT CONTROL ON dbo.Table1 TO LoginB;
GO
-- LoginB can select
EXECUTE AS USER = 'LoginB';
SELECT *
FROM dbo.Table1;
REVERT;
GO

-- Deny SELECT to LoginB
DENY SELECT ON dbo.Table1 TO LoginB;
GO
-- LoginB can insert, but not select
EXECUTE AS USER = 'LoginB';
INSERT INTO dbo.Table1(id, tableContainer)
 VALUES (2, 'dbo');
REVERT;
GO
EXECUTE AS USER = 'LoginB';
SELECT *
FROM dbo.Table1;
REVERT;
GO

-- Can LoginB revoke the denied SELECT?
EXECUTE AS USER = 'LoginB';
REVOKE SELECT ON dbo.Table1 FROM LoginB;
REVERT;
GO
-- dbo can revoke the denied SELECT
REVOKE SELECT ON dbo.Table1 FROM LoginB;
GO


----------------------------------------------------
-- Section 2: Data Encryption
----------------------------------------------------

-- Backup encryption
USE master;
-- Create the master database DMK
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Pa$$w0rd';  
-- Create the backup certificate in master
CREATE CERTIFICATE DemoBackupEncryptCert  
 WITH SUBJECT = 'SQLDevGuideDemoDb Backup Certificate';  
GO  

-- Check the SMK and DMK
SELECT name, key_length, algorithm_desc
FROM sys.symmetric_keys;

-- Backup without encryption
BACKUP DATABASE SQLDevGuideDemoDb
 TO DISK = N'C:\SQL2016DevGuide\SQLDevGuideDemoDb_Backup.bak'
 WITH INIT;
GO

-- Backup with encryption
BACKUP DATABASE SQLDevGuideDemoDb 
 TO DISK = N'C:\SQL2016DevGuide\SQLDevGuideDemoDb_BackupEncrypted.bak'  
WITH INIT,
 ENCRYPTION   
  (  
   ALGORITHM = AES_256,  
   SERVER CERTIFICATE = DemoBackupEncryptCert  
  ); 
GO  
-- Warning: The certificate used for encrypting the database encryption key has not been backed up.

-- Backup SMK
BACKUP SERVICE MASTER KEY
 TO FILE = N'C:\SQL2016DevGuide\SMK.key'   
 ENCRYPTION BY PASSWORD = 'Pa$$w0rd';  
-- Backup master DMK
BACKUP MASTER KEY
 TO FILE = N'C:\SQL2016DevGuide\masterDMK.key'   
 ENCRYPTION BY PASSWORD = 'Pa$$w0rd'; 
-- Backup certificate
BACKUP CERTIFICATE DemoBackupEncryptCert
 TO FILE = N'C:\SQL2016DevGuide\DemoBackupEncryptCert.cer'
 WITH PRIVATE KEY
  (
   FILE = N'C:\SQL2016DevGuide\DemoBackupEncryptCert.key',
   ENCRYPTION BY PASSWORD = 'Pa$$w0rd'
  );
GO

-- Drop the demo database
DROP DATABASE SQLDevGuideDemoDb;
-- Drop the certificate and the master DMK key
DROP CERTIFICATE DemoBackupEncryptCert;
DROP MASTER KEY;
GO

-- Try to restore the encrypted database
RESTORE DATABASE SQLDevGuideDemoDb
 FROM  DISK = N'C:\SQL2016DevGuide\SQLDevGuideDemoDb_BackupEncrypted.bak'
 WITH  FILE = 1;
GO
-- Error 33111, Cannot find server certificate

-- Restore master DMK
RESTORE MASTER KEY   
 FROM FILE = N'C:\SQL2016DevGuide\masterDMK.key' 
 DECRYPTION BY PASSWORD = 'Pa$$w0rd'
 ENCRYPTION BY PASSWORD = 'Pa$$w0rd'; 
GO

-- Restore certificate - open the master DMK first
OPEN MASTER KEY DECRYPTION BY PASSWORD = 'Pa$$w0rd';
CREATE CERTIFICATE DemoBackupEncryptCert  
 FROM FILE = N'C:\SQL2016DevGuide\DemoBackupEncryptCert.cer'
 WITH PRIVATE KEY (FILE = N'C:\SQL2016DevGuide\DemoBackupEncryptCert.key',
                   DECRYPTION BY PASSWORD = 'Pa$$w0rd');  
GO 

-- Try to restore the encrypted database
RESTORE DATABASE SQLDevGuideDemoDb
 FROM  DISK = N'C:\SQL2016DevGuide\SQLDevGuideDemoDb_BackupEncrypted.bak'
 WITH  FILE = 1, RECOVERY;
GO
-- Restore success

-- Encrypted backups
SELECT b.database_name,
 c.name, 
 b.encryptor_type,
 b.encryptor_thumbprint
FROM sys.certificates AS c 
 INNER JOIN msdb.dbo.backupset AS b
  ON c.thumbprint = b.encryptor_thumbprint;
GO


-- Column-level encryption
USE SQLDevGuideDemoDb;  
-- Create the SQLDevGuideDemoDb database DMK
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Pa$$w0rd';  
-- Create the column certificate in SQLDevGuideDemoDb
CREATE CERTIFICATE DemoColumnEncryptCert  
 WITH SUBJECT = 'SQLDevGuideDemoDb Column Certificate';  
-- Create the symmetric key
CREATE SYMMETRIC KEY DemoColumnEncryptSimKey 
 WITH ALGORITHM = AES_256  
 ENCRYPTION BY CERTIFICATE DemoColumnEncryptCert;  
GO  

-- Create a column in which to store the encrypted data  
ALTER TABLE dbo.Table1  
 ADD tableContainer_Encrypted VARBINARY(128);   
GO  

-- Open the symmetric key 
OPEN SYMMETRIC KEY DemoColumnEncryptSimKey  
 DECRYPTION BY CERTIFICATE DemoColumnEncryptCert;  
-- Encrypt the value in column tableContainer using the  
-- symmetric key DemoColumnEncryptSimKey 
-- Save the result in column tableContainer_Encrypted   
UPDATE dbo.Table1  
SET tableContainer_Encrypted = 
    ENCRYPTBYKEY(Key_GUID('DemoColumnEncryptSimKey'), tableContainer);
GO  

-- Verify the encryption  
-- Open the symmetric key 
OPEN SYMMETRIC KEY DemoColumnEncryptSimKey  
 DECRYPTION BY CERTIFICATE DemoColumnEncryptCert;
-- All columns
SELECT id, tableContainer,
 tableContainer_Encrypted,
 CAST(DECRYPTBYKEY(tableContainer_Encrypted) AS CHAR(5))
  AS tableContainer_Decrypted
FROM dbo.Table1;
GO 

-- Clean up - use SQLCMD mode
USE master;
!!del C:\SQL2016DevGuide\DemoBackupEncryptCert.cer
!!del C:\SQL2016DevGuide\DemoBackupEncryptCert.key
!!del C:\SQL2016DevGuide\masterDMK.key
!!del C:\SQL2016DevGuide\SMK.key
!!del C:\SQL2016DevGuide\SQLDevGuideDemoDb_Backup.bak
!!del C:\SQL2016DevGuide\SQLDevGuideDemoDb_BackupEncrypted.bak
GO
IF DB_ID(N'SQLDevGuideDemoDb') IS NOT NULL
   DROP DATABASE SQLDevGuideDemoDb;
DROP LOGIN LoginA;
DROP LOGIN [Builtin\Power Users];
DROP LOGIN LoginB;
DROP CERTIFICATE DemoBackupEncryptCert;
DROP MASTER KEY;
GO

-- Transparent data encryption (TDE)
-- Use the Chapter08TDE.sql file

-- Always encrypted (AE)
-- Use the Chapter08AE1.sql and Chapter08AE2.sql files

-- Row-level security (RLS)
-- Use the Chapter08RLS.sql file

-- Dymanic data masking (DDM)
-- Use the Chapter08DDM.sql file
