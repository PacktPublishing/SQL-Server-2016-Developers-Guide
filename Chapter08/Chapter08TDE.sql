------------------------------------------------------
-------   SQL Server 2016 Developer’s Guide    -------
------   Chapter 08 - Tightening the Security  -------
------------------------------------------------------

----------------------------------------------------
-- Section 2: Data Encryption
-- Transparent Data Encryption
----------------------------------------------------

USE master;
-- Create the master database DMK
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Pa$$w0rd';  
GO  

-- Check the SMB and DMB
SELECT name, key_length, algorithm_desc
FROM sys.symmetric_keys;

-- Backup SMK
BACKUP SERVICE MASTER KEY
 TO FILE = N'C:\SQL2016DevGuide\SMK.key'   
 ENCRYPTION BY PASSWORD = 'Pa$$w0rd';  
-- Backup master DMK
BACKUP MASTER KEY
 TO FILE = N'C:\SQL2016DevGuide\masterDMK.key'   
 ENCRYPTION BY PASSWORD = 'Pa$$w0rd'; 
GO

IF DB_ID(N'TDEDemo') IS NULL
   CREATE DATABASE TDEDemo;
GO

-- Create the TDE certificate in master
CREATE CERTIFICATE DemoTDEEncryptCert  
 WITH SUBJECT = 'TDEDemo TDE Certificate';  
GO

-- Backup certificate
BACKUP CERTIFICATE DemoTDEEncryptCert
 TO FILE = N'C:\SQL2016DevGuide\DemoTDEEncryptCert.cer'
 WITH PRIVATE KEY
  (
   FILE = N'C:\SQL2016DevGuide\DemoTDEEncryptCert.key',
   ENCRYPTION BY PASSWORD = 'Pa$$w0rd'
  );
GO

USE TDEDemo;  
CREATE DATABASE ENCRYPTION KEY  
 WITH ALGORITHM = AES_128 
 ENCRYPTION BY SERVER CERTIFICATE DemoTDEEncryptCert;  
GO  

-- Turn TDE on
ALTER DATABASE TDEDemo  
 SET ENCRYPTION ON;  
GO  

-- Check the status
SELECT DB_NAME(database_id) AS DatabaseName,
    key_algorithm AS [Algorithm],
    key_length AS KeyLength,
	encryption_state AS EncryptionState,
    CASE encryption_state
        WHEN 0 THEN 'No database encryption key present, no encryption'
        WHEN 1 THEN 'Unencrypted'
        WHEN 2 THEN 'Encryption in progress'
        WHEN 3 THEN 'Encrypted'
        WHEN 4 THEN 'Key change in progress'
        WHEN 5 THEN 'Decryption in progress'
    END AS EncryptionStateDesc,
    percent_complete AS PercentComplete
FROM sys.dm_database_encryption_keys;
GO

-- Turn TDE off
ALTER DATABASE TDEDemo
SET ENCRYPTION OFF;
GO

-- Check the status again
SELECT DB_NAME(database_id) AS DatabaseName,
    key_algorithm AS [Algorithm],
    key_length AS KeyLength,
	encryption_state AS EncryptionState,
    CASE encryption_state
        WHEN 0 THEN 'No database encryption key present, no encryption'
        WHEN 1 THEN 'Unencrypted'
        WHEN 2 THEN 'Encryption in progress'
        WHEN 3 THEN 'Encrypted'
        WHEN 4 THEN 'Key change in progress'
        WHEN 5 THEN 'Decryption in progress'
    END AS EncryptionStateDesc,
    percent_complete AS PercentComplete
FROM sys.dm_database_encryption_keys;
GO
-- tempdb is still encrypted
-- Restart SQL Server and check the encryption again
-- After restart,tempdb should be unencrypted

-- Clean up - use SQLCMD mode
USE master;
!!del C:\SQL2016DevGuide\DemoTDEEncryptCert.cer
!!del C:\SQL2016DevGuide\DemoTDEEncryptCert.key
!!del C:\SQL2016DevGuide\masterDMK.key
!!del C:\SQL2016DevGuide\SMK.key
IF DB_ID(N'TDEDemo') IS NOT NULL
   DROP DATABASE TDEDemo;
DROP CERTIFICATE DemoTDEEncryptCert;
DROP MASTER KEY;
GO