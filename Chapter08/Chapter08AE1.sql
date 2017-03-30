------------------------------------------------------
-------   SQL Server 2016 Developer’s Guide    -------
------   Chapter 08 - Tightening the Security  -------
------------------------------------------------------

----------------------------------------------------
-- Section 2: Data Encryption
-- Always Encrypted Session 1
----------------------------------------------------

USE master;
IF DB_ID(N'AEDemo') IS NULL
   CREATE DATABASE AEDemo;
GO
USE AEDemo;
GO

-- Create the column master key
-- Can also use SSMS GUI
CREATE COLUMN MASTER KEY AE_ColumnMasterKey
WITH
(
 KEY_STORE_PROVIDER_NAME = N'MSSQL_CERTIFICATE_STORE',
 KEY_PATH = N'CurrentUser/My/31DE4568DE505EC641DFF848DD5801B44C6BC6E1'
);
GO

-- Check the column master keys
SELECT * 
FROM sys.column_master_keys;
GO

-- Create the column encryption key
CREATE COLUMN ENCRYPTION KEY AE_ColumnEncryptionKey
WITH VALUES
(
 COLUMN_MASTER_KEY = AE_ColumnMasterKey,
 ALGORITHM = 'RSA_OAEP',
 ENCRYPTED_VALUE =
  0x016E000001630075007200720065006E00740075007300650072002F006D0079002F0033003100640065003400350036003800640065003500300035006500630036003400310064006600660038003400380064006400350038003000310062003400340063003600620063003600650031005DDD3D932BD39C2528680EBA81FE15817AE0AAC2A33DE7563943FB86B095F5C5A88A2917FE18EF0BD1A69C701951DF75F520D8CF965F1E1F60FDFFC53661FAC926189ADA06B5329DAA02CBC4A2C52DD6A9E777487266CBDE0E62F96957A95ABBB5A71D4AEC4ABBC19B84CCCCF80C6873E980BAE0D1394E4C6938A39E5F9686EA983BB0401518363877405C0CAABAFD1469FEF7E7F02F62878B396A7D75120712EF5EBB056282C2B91032E8A53B0D6F0A6AD0B20503B6B5B5C4DD97DE01BFA883D0264906E8B8761437080A1FC4DF9D49F821966AF881A3E9D164F35958DD985F723C2538A790899B0ECF66566F445264D9906D43C328C1E3B7D2F947EC7BDB35495BAA3911E5E7FBFFB272DE0813FA1E69E70C4E30A2381A64141CF96D5FF65DF0C948387C587553E65198D9327E8A5D8D48C11A254B820C144040F3BF36A65EA732C139D77F5BFA58975B47903B822D73BEC6CE4EF6A15A283016169C6B1AC9CF8A94563B39CBB5AC893AFB17A8EBEB87C2FB6CF06E56D82948E02B8AB070715F49DED547859DED2D3F0C0725D4275D467019EBFE76348A62BE6BAEC9B360D1BCDE489CB6EAB87B421C41E68B7075D241B8DA20CD23AD1A1A8CD9091EA52283444660F35F07A94BA5657E7BA99AB4844B779D3544EA9307BCFA73F95AEB2583D336020F847353428FEDA424C31AED9E01679DBC5A0944A192C7D53F9DA82DD3
);
-- Check the column encryption keys
SELECT * 
FROM sys.column_encryption_keys;
GO

-- A table with one deterministic encryption
-- and one random encryption (salted) columns
-- Try with
CREATE TABLE dbo.Table1
(id INT,
 SecretDeterministic NVARCHAR(10) 
  ENCRYPTED WITH (COLUMN_ENCRYPTION_KEY = AE_ColumnEncryptionKey,
   ENCRYPTION_TYPE = DETERMINISTIC,
   ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256') NULL,
 SecretRandomized NVARCHAR(10) 
  ENCRYPTED WITH (COLUMN_ENCRYPTION_KEY = AE_ColumnEncryptionKey,
   ENCRYPTION_TYPE = RANDOMIZED,
   ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256') NULL
);
GO
/* Error
Msg 33289, Level 16, State 38, Line 59
Cannot create encrypted column 'SecretDeterministic',
 character strings that do not use a *_BIN2 collation cannot be encrypted.
*/

-- Correct
CREATE TABLE dbo.Table1
(id INT,
 SecretDeterministic NVARCHAR(10) COLLATE Latin1_General_BIN2 
  ENCRYPTED WITH (COLUMN_ENCRYPTION_KEY = AE_ColumnEncryptionKey,
   ENCRYPTION_TYPE = DETERMINISTIC,
   ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256') NULL,
 SecretRandomized NVARCHAR(10) COLLATE Latin1_General_BIN2
  ENCRYPTED WITH (COLUMN_ENCRYPTION_KEY = AE_ColumnEncryptionKey,
   ENCRYPTION_TYPE = RANDOMIZED,
   ALGORITHM = 'AEAD_AES_256_CBC_HMAC_SHA_256') NULL
);
GO

-- Try to insert data
INSERT INTO dbo.Table1
 (id, SecretDeterministic, SecretRandomized)
VALUES (1, N'DeterSec01', N'RandomSec1');
GO
/* Error
Msg 206, Level 16, State 2, Line 93
Operand type clash: nvarchar is incompatible with nvarchar(4000) 
 encrypted with (encryption_type = 'DETERMINISTIC', 
 encryption_algorithm_name = 'AEAD_AES_256_CBC_HMAC_SHA_256', 
 column_encryption_key_name = 'AE_ColumnEncryptionKey', 
 column_encryption_key_database_name = 'AEDemo')
*/

-- Can truncate the table
TRUNCATE TABLE dbo.Table1;
GO

-- Run the AEDemo client application to insert two rows
-- Use SQLCMD mode
!!C:\SQL2016DevGuide\AEDemo 1 DeterSec01 RandomSec1
!!C:\SQL2016DevGuide\AEDemo 2 DeterSec02 RandomSec2
GO

-- Try to read the data wihtout the Column Encryption Setting=enabled
SELECT *
FROM dbo.Table1;
GO
-- Data is encrypted

-- Use a new query window Always Encrypted Session 2
-- to show how to read the data with the Column Encryption Setting=enabled

-- Index on the deterministic encription
CREATE NONCLUSTERED INDEX NCI_Table1_SecretDeterministic
 ON dbo.Table1(SecretDeterministic);
GO
-- Works

-- Index on the random encription
CREATE NONCLUSTERED INDEX NCI_Table1_SecretRandomized
 ON dbo.Table1(SecretRandomized);
GO
/* Error
Msg 33282, Level 16, State 2, Line 127
Column 'dbo.Table1.SecretRandomized' is encrypted using
 a randomized encryption type and is therefore not valid for use 
 as a key column in a constraint, index, or statistics.
*/

-- Clean up 
USE master;
IF DB_ID(N'AEDemo') IS NOT NULL
   DROP DATABASE AEDemo;
GO
