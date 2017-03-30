--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide
--------	Chapter 05 - JSON Support
--------				OPENJSON
--------------------------------------------------------------------

----------------------------------------------------
-- OPENJSON with default schema
----------------------------------------------------

DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Songs" :[{"Title":"Shine On You Crazy Diamond","Writers":"Gilmour, Waters, Wright"},
{"Title":"Have a Cigar","Writers":"Waters"},
{"Title":"Welcome to the Machine","Writers":"Waters"},
{"Title":"Wish You Were Here","Writers":"Gilmour, Waters"}],
"Members":{"Guitar":"David Gilmour","Bass Guitar":"Roger Waters","Keyboard":"Richard Wright","Drums":"Nick Mason"}
}';
SELECT * FROM OPENJSON(@json);
GO
/*Result:
key		value				type
------- ------------------	-------
Album	Wish You Were Here	1
Year	1975				2
IsVinyl	true				3
Songs	[{"Title":"Shine On You Crazy Diamond","Writers":"Gilmour, Waters, Wright"},  {"Title":"Have a Cigar","Writers":"Waters"},  {"Title":"Welcome to the Machine","Writers":"Waters"},  {"Title":"Wish You Were Here","Writers":"Gilmour, Waters"}]	4
Members	{"Guitar":"David Gilmour","Bass Guitar":"Roger Waters","Keyboard":"Richard Wright","Drums":"Nick Mason"}	5
*/

--input string must be well formatted. Otherwise an error:
DECLARE @json NVARCHAR(500) = '{
"Album":"Wish You Were Here",
Year":1975,
"IsVinyl":true
}';
SELECT * FROM OPENJSON(@json);
/*Result:
Msg 13609, Level 16, State 4, Line 38
JSON text is not properly formatted. Unexpected character 'Y' is found at position 34.
*/

--use path expression to extract songs
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Songs" :[{"Title":"Shine On You Crazy Diamond","Writers":"Gilmour, Waters, Wright"},
{"Title":"Have a Cigar","Writers":"Waters"},
{"Title":"Welcome to the Machine","Writers":"Waters"},
{"Title":"Wish You Were Here","Writers":"Gilmour, Waters"}],
"Members":{"Guitar":"David Gilmour","Bass Guitar":"Roger Waters","Keyboard":"Richard Wright","Drums":"Nick Mason"}
}';
SELECT * FROM OPENJSON(@json,'$.Songs');
GO
/*Result:
key		value																		type
------- ------------------															-------
0		{"Title":"Shine On You Crazy Diamond","Writers":"Gilmour, Waters, Wright"}	5
1		{"Title":"Have a Cigar","Writers":"Waters"}									5
2		{"Title":"Welcome to the Machine","Writers":"Waters"}						5
3		{"Title":"Wish You Were Here","Writers":"Gilmour, Waters"}					5
*/

--use path expression to extract members
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Songs" :[{"Title":"Shine On You Crazy Diamond","Writers":"Gilmour, Waters, Wright"},
{"Title":"Have a Cigar","Writers":"Waters"},
{"Title":"Welcome to the Machine","Writers":"Waters"},
{"Title":"Wish You Were Here","Writers":"Gilmour, Waters"}],
"Members":{"Guitar":"David Gilmour","Bass Guitar":"Roger Waters","Keyboard":"Richard Wright","Drums":"Nick Mason"}
}';
SELECT * FROM OPENJSON(@json,'$.Members');
GO
/*Result:
key			value			type
-------		---------------	-------
Guitar		David Gilmour	1
Bass Guitar	Roger Waters	1
Keyboard	Richard Wright	1
Drums		Nick Mason		1
*/

--You cannot specify a property; it must be either an object or array
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Songs" :[{"Title":"Shine On You Crazy Diamond","Writers":"Gilmour, Waters, Wright"},
{"Title":"Have a Cigar","Writers":"Waters"},
{"Title":"Welcome to the Machine","Writers":"Waters"},
{"Title":"Wish You Were Here","Writers":"Gilmour, Waters"}],
"Members":{"Guitar":"David Gilmour","Bass Guitar":"Roger Waters","Keyboard":"Richard Wright","Drums":"Nick Mason"}
}';
SELECT * FROM OPENJSON(@json,'$.Members.Guitar');
GO
/*Result:
key			value			type
-------		---------------	-------
*/
--Default ist lax mode, therefore we got an empty table
--if you specify strict mode the function returns an empty table again, but in addition to this an error is raised
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Songs" :[{"Title":"Shine On You Crazy Diamond","Writers":"Gilmour, Waters, Wright"},
{"Title":"Have a Cigar","Writers":"Waters"},
{"Title":"Welcome to the Machine","Writers":"Waters"},
{"Title":"Wish You Were Here","Writers":"Gilmour, Waters"}],
"Members":{"Guitar":"David Gilmour","Bass Guitar":"Roger Waters","Keyboard":"Richard Wright","Drums":"Nick Mason"}
}';
SELECT * FROM OPENJSON(@json,N'strict $.Members.Guitar');
GO
/*Result:
key			value			type
-------		---------------	-------
Msg 13611, Level 16, State 1, Line 15
Value referenced by JSON path is not an array or object and cannot be opened with OPENJSON.
*/

--Similar happens if you specify a non-existing property
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Songs" :[{"Title":"Shine On You Crazy Diamond","Writers":"Gilmour, Waters, Wright"},
{"Title":"Have a Cigar","Writers":"Waters"},
{"Title":"Welcome to the Machine","Writers":"Waters"},
{"Title":"Wish You Were Here","Writers":"Gilmour, Waters"}],
"Members":{"Guitar":"David Gilmour","Bass Guitar":"Roger Waters","Keyboard":"Richard Wright","Drums":"Nick Mason"}
}';
SELECT * FROM OPENJSON(@json,N'lax $.Movies');
GO
/*Result:
key			value			type
-------		---------------	-------
*/
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Songs" :[{"Title":"Shine On You Crazy Diamond","Writers":"Gilmour, Waters, Wright"},
{"Title":"Have a Cigar","Writers":"Waters"},
{"Title":"Welcome to the Machine","Writers":"Waters"},
{"Title":"Wish You Were Here","Writers":"Gilmour, Waters"}],
"Members":{"Guitar":"David Gilmour","Bass Guitar":"Roger Waters","Keyboard":"Richard Wright","Drums":"Nick Mason"}
}';
SELECT * FROM OPENJSON(@json,N'strict $.Movies');
/*Result:
key			value			type
-------		---------------	-------
Msg 13608, Level 16, State 3, Line 152
Property cannot be found on the specified JSON path.
*/

--Cool implementation
--Check differences in database settings between master and model database:
SELECT 
	mst.[key], 
	mst.[value] AS mst_val, 
	mdl.[value] AS mdl_val
FROM OPENJSON ((SELECT * FROM sys.databases WHERE database_id = 1 FOR JSON AUTO, WITHOUT_ARRAY_WRAPPER)) mst
INNER JOIN OPENJSON((SELECT * FROM sys.databases WHERE database_id = 3 FOR JSON AUTO, WITHOUT_ARRAY_WRAPPER)) mdl
ON mst.[key] = mdl.[key] AND mst.[value] <> mdl.[value];


/*Result:
key                            mst_val    mdl_val
------------------------------ ---------- ----------
name                           master     model
database_id                    1          3
compatibility_level            120        130
snapshot_isolation_state       1          0
snapshot_isolation_state_desc  ON         OFF
recovery_model                 3          1
recovery_model_desc            SIMPLE     FULL
is_db_chaining_on              true       false
*/

----------------------------------------------------
-- OPENJSON with an Explicit Schema
----------------------------------------------------
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Songs" :[{"Title":"Shine On You Crazy Diamond","Writers":"Gilmour, Waters, Wright"},
{"Title":"Have a Cigar","Writers":"Waters"},
{"Title":"Welcome to the Machine","Writers":"Waters"},
{"Title":"Wish You Were Here","Writers":"Gilmour, Waters"}],
"Members":{"Guitar":"David Gilmour","Bass Guitar":"Roger Waters","Keyboard":"Richard Wright","Drums":"Nick Mason"}
}';
SELECT * FROM OPENJSON(@json)
WITH
(
	AlbumName NVARCHAR(50) '$.Album',
	AlbumYear SMALLINT '$.Year',
	IsVinyl	BIT '$.IsVinyl'
);
GO
/*
Result:
AlbumName                                          AlbumYear IsVinyl
-------------------------------------------------- --------- -------
Wish You Were Here                                 1975      1
*/
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Songs" :[{"Title":"Shine On You Crazy Diamond","Writers":"Gilmour, Waters, Wright"},
{"Title":"Have a Cigar","Writers":"Waters"},
{"Title":"Welcome to the Machine","Writers":"Waters"},
{"Title":"Wish You Were Here","Writers":"Gilmour, Waters"}],
"Members":{"Guitar":"David Gilmour","Bass Guitar":"Roger Waters","Keyboard":"Richard Wright","Drums":"Nick Mason"}
}';
SELECT * FROM OPENJSON(@json)
WITH
(
	AlbumName NVARCHAR(50) '$.Album',
	AlbumYear SMALLINT '$.Year',
	IsVinyl	BIT '$.IsVinyl',
	Members	NVARCHAR(1000) '$.Members'
);
GO
/*
Result:
AlbumName                                          AlbumYear IsVinyl	Members
-------------------------------------------------- --------- -------	-------
Wish You Were Here                                 1975      1			NULL
*/
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Songs" :[{"Title":"Shine On You Crazy Diamond","Writers":"Gilmour, Waters, Wright"},
{"Title":"Have a Cigar","Writers":"Waters"},
{"Title":"Welcome to the Machine","Writers":"Waters"},
{"Title":"Wish You Were Here","Writers":"Gilmour, Waters"}],
"Members":{"Guitar":"David Gilmour","Bass Guitar":"Roger Waters","Keyboard":"Richard Wright","Drums":"Nick Mason"}
}';
SELECT * FROM OPENJSON(@json)
WITH
(
	AlbumName NVARCHAR(50) '$.Album',
	AlbumYear SMALLINT '$.Year',
	IsVinyl	BIT '$.IsVinyl',
	Members	NVARCHAR(1000) 'strict $.Members'
);
GO
/*
Result:
AlbumName                                          AlbumYear IsVinyl	Members
-------------------------------------------------- --------- -------	-------

Msg 13624, Level 16, State 1, Line 40
Object or array cannot be found in the specified JSON path.
*/
--Fix the problem


DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Songs" :[{"Title":"Shine On You Crazy Diamond","Writers":"Gilmour, Waters, Wright"},
{"Title":"Have a Cigar","Writers":"Waters"},
{"Title":"Welcome to the Machine","Writers":"Waters"},
{"Title":"Wish You Were Here","Writers":"Gilmour, Waters"}],
"Members":{"Guitar":"David Gilmour","Bass Guitar":"Roger Waters","Keyboard":"Richard Wright","Drums":"Nick Mason"}
}';
SELECT * FROM OPENJSON(@json)
WITH
(
	AlbumName NVARCHAR(50) '$.Album',
	AlbumYear SMALLINT '$.Year',
	IsVinyl	BIT '$.IsVinyl',
	Members	NVARCHAR(MAX) '$.Members' AS JSON

);
GO
/*
Result:
AlbumName                                          AlbumYear IsVinyl	Members
-------------------------------------------------- --------- -------	-------
Wish You Were Here                                 1975      1			{"Guitar":"David Gilmour","Bass Guitar":"Roger Waters","Keyboard":"Richard Wright","Drums":"Nick Mason"}
*/

DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Songs" :[{"Title":"Shine On You Crazy Diamond","Writers":"Gilmour, Waters, Wright"},
{"Title":"Have a Cigar","Writers":"Waters"},
{"Title":"Welcome to the Machine","Writers":"Waters"},
{"Title":"Wish You Were Here","Writers":"Gilmour, Waters"}],
"Members":{"Guitar":"David Gilmour","Bass Guitar":"Roger Waters","Keyboard":"Richard Wright","Drums":"Nick Mason"}
}';
SELECT s.SongTitle, s.SongAuthors, a.AlbumName FROM OPENJSON(@json)
WITH
(
	AlbumName NVARCHAR(50) '$.Album',
	AlbumYear SMALLINT '$.Year',
	IsVinyl BIT '$.IsVinyl',
	Songs	NVARCHAR(MAX) '$.Songs' AS JSON,
	Members NVARCHAR(MAX) '$.Members' AS JSON

) a
CROSS APPLY OPENJSON(Songs)
WITH
(
	SongTitle NVARCHAR(200) '$.Title',
	SongAuthors NVARCHAR(200) '$.Writers'
)s;
/*
Result:
SongTitle						SongAuthors					AlbumName
------------------------------	------------------------	--------------------
Shine On You Crazy Diamond		Gilmour, Waters, Wright		Wish You Were Here
Have a Cigar					Waters, Wright				Wish You Were Here
Welcome to the Machine			Waters						Wish You Were Here
Wish You Were Here				Gilmour, Waters				Wish You Were Here
*/

-----------------------------------------------------------------------
--Import JSON Data from File
-----------------------------------------------------------------------

--generate JSON
USE WideWorldImporters;
SELECT PersonID,FullName, PhoneNumber, FaxNumber, EmailAddress, LogonName, IsEmployee, IsSalesperson
FROM Application.People FOR JSON AUTO;

--save it as app.people.json file in the folder C:\Temp
--import it into SQL Server in a single column
SELECT BulkColumn
FROM OPENROWSET (BULK 'C:\Temp\app.people.json', SINGLE_CLOB) AS x;


--use OPENJSON with default schema to show one row for each JSON array element
 SELECT [key], [value], [type]
 FROM OPENROWSET (BULK 'C:\Temp\app.people.lite.json', SINGLE_CLOB) AS x
 CROSS APPLY OPENJSON(BulkColumn);

 --use OPENJSON with an explicit schema
 SELECT PersonID,FullName, PhoneNumber, FaxNumber, EmailAddress, LogonName, IsEmployee, IsSalesperson
 FROM OPENROWSET (BULK 'C:\Temp\app.people.lite.json', SINGLE_CLOB) AS x
 CROSS APPLY OPENJSON(BulkColumn)
 WITH
(
	PersonID INT '$.PersonID',
	FullName NVARCHAR(50) '$.FullName',
	PhoneNumber NVARCHAR(20) '$.PhoneNumber',
	FaxNumber NVARCHAR(20) '$.FaxNumber',
	EmailAddress NVARCHAR(256) '$.EmailAddress',
	LogonName NVARCHAR(50) '$.LogonName',
	IsEmployee	BIT '$.IsEmployee',
	IsSalesperson BIT '$.IsSalesperson'
);
