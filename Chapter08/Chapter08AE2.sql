------------------------------------------------------
-------   SQL Server 2016 Developer’s Guide    -------
------   Chapter 08 - Tightening the Security  -------
------------------------------------------------------

----------------------------------------------------
-- Section 2: Data Encryption
-- Always Encrypted Session 2
----------------------------------------------------

-- Right-click in this window and choose Connection, then Change Connection
-- In the connection dialog, click Options
-- Type AEDemo for the database name
-- Click on Additional Connection Parameters and enter
-- Column Encryption Setting=enabled
-- Click Connect

-- Try to insert data
INSERT INTO dbo.Table1
 (id, SecretDeterministic, SecretRandomized)
VALUES (2, N'DeterSec2', N'RandomSec2');
GO
/* Error
Msg 206, Level 16, State 2, Line 93
Operand type clash: nvarchar is incompatible with nvarchar(4000) 
 encrypted with (encryption_type = 'DETERMINISTIC', 
 encryption_algorithm_name = 'AEAD_AES_256_CBC_HMAC_SHA_256', 
 column_encryption_key_name = 'AE_ColumnEncryptionKey', 
 column_encryption_key_database_name = 'AEDemo')
*/
-- Still does not work -
-- insert must be parametrized and data encrypted by the client application

-- Select works
SELECT * 
FROM dbo.Table1;
GO

-- Close window and continue in the first window
