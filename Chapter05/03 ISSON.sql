--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide
--------	Chapter 05 - JSON Support
--------				ISJSON
--------------------------------------------------------------------

----------------------------------------------------
-- ISJSON
----------------------------------------------------

--check if a variable is valid
DECLARE @var NVARCHAR(20) = 'test';
SELECT ISJSON (@var) AS is_json;
/*Result:
is_json
-----------
1
*/

SELECT ISJSON ('test'), ISJSON ('') , ISJSON ('{}'), ISJSON ('{"a"}'), ISJSON ('{"a":1}') ;  
/*Result:
----------- ----------- ----------- ----------- -----------
0           0           1           0           1
*/  

--ISJSON does not check the uniqueness of keys at the same level. Therefore, this JSON data is valid
SELECT ISJSON ('{"id":1, "id":"a"}') AS is_json;
/*Result:
is_json
-----------
1
*/

--Using ISJSON in check constraint
USE WideWorldImporters;
DROP TABLE IF EXISTS dbo.Users;
CREATE TABLE dbo.Users(
id INT IDENTITY(1,1) NOT NULL,
username NVARCHAR(50) NOT NULL,
user_settings NVARCHAR(MAX) NULL CONSTRAINT CK_user_settings CHECK (ISJSON(user_settings) = 1),
CONSTRAINT PK_Users PRIMARY KEY CLUSTERED (id ASC)
);
GO

--insert some data
INSERT INTO dbo.Users(username, user_settings) VALUES(N'vasilije', '{"team" : ["Rapid", "Bayern"], "hobby" : ["soccer", "gaming"], "color" : "green" }');
/*Result:
(1 row(s) affected)
*/
INSERT INTO dbo.Users(username, user_settings) VALUES(N'mila', '{"team" : "Liverpool", "hobby"}');
/*Result:
Msg 547, Level 16, State 0, Line 33
The INSERT statement conflicted with the CHECK constraint "CK_user_settings". The conflict occurred in database "WideWorldImporters", table "dbo.Users", column 'user_settings'.
The statement has been terminated.
*/

--Ensure that you have dropped the table used in this example:
USE WideWorldImporters;
DROP TABLE IF EXISTS dbo.Users; 
GO
