--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide
--------	Chapter 05 - JSON Support
--------			JSON_VALUE
--------------------------------------------------------------------

----------------------------------------------------
-- JSON_VALUE
----------------------------------------------------
 DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Members":["Gilmour","Waters","Wright","Mason"]
}';
SELECT 
	JSON_VALUE(@json, '$.Album') AS album,
	JSON_VALUE(@json, '$.IsVinyl') AS isVinyl,
	JSON_VALUE(@json, '$.Members[0]') AS member1;

GO
/*
Result:
album					isVinyl		member1 
-------------------		-----		--------
Wish You Were Here		true		Gilmour
*/

--object or array results with NULL (lax mode) or an error (strict mode)
 DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Members":["Gilmour","Waters","Wright","Mason"]
}';
SELECT 
	JSON_VALUE(@json, '$.Members') AS members
/*
Result:
members
---------
NULL
*/
 DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Members":["Gilmour","Waters","Wright","Mason"]
}';
SELECT 
	JSON_VALUE(@json, 'strict $.Members') AS members
/*
Result:
Msg 13623, Level 16, State 1, Line 75
Scalar value cannot be found in the specified JSON path.
*/
DECLARE @json NVARCHAR(MAX) = CONCAT('{"name":"', REPLICATE('A',4000), '",}'),
@json4001 NVARCHAR(MAX) = CONCAT('{"name":"', REPLICATE('A',4001), '",}') 
SELECT 
	JSON_VALUE(@json, '$.name') AS name4000,
	JSON_VALUE(@json4001, '$.name') AS name4001;  

/*
Result:
name4000				name4001
-------------------		---------
AAAAAAAAAAAAAAAA...		NULL
*/
DECLARE @json4001 NVARCHAR(MAX) = CONCAT('{"name":"', REPLICATE('A',4001), '",}') 
SELECT 
	JSON_VALUE(@json4001, 'strict $.name') AS name4001;
/*
Result:
Msg 13625, Level 16, State 1, Line 65
String value in the specified JSON path would be truncated.
*/
USE WideWorldImporters;
SELECT PersonID,
JSON_VALUE(UserPreferences, '$.timeZone') AS TimeZone,
JSON_VALUE(UserPreferences, '$.table.pageLength') AS PageLength
FROM Application.People
WHERE JSON_VALUE(UserPreferences, '$.dateFormat')='yy-mm-dd'
AND JSON_VALUE(UserPreferences, '$.theme')='blitzer'
ORDER BY JSON_VALUE(UserPreferences, '$.theme'), PersonID
/*
Result:
PersonID    TimeZone	PageLength
----------- --------	---------
1           PST			25
1121        PST			25
2241        PST			25
*/

--JSON PATH must be literal
DECLARE @jsonPath NVARCHAR(50) = N'$.Album';
 DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Members":["Gilmour","Waters","Wright","Mason"]
}';
SELECT 
	JSON_VALUE(@json, @jsonPath) AS album;
/*
Result:
 Msg 13610, Level 16, State 1, Line 137
The argument 2 of the "JSON_VALUE or JSON_QUERY" must be a string literal.
*/