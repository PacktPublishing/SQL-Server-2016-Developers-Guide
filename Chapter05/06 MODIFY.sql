--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide
--------	Chapter 05 - JSON Support
--------			JSON_MODIFY
--------------------------------------------------------------------

--------------------------------------------------------------------
-- JSON_MODIFY
--------------------------------------------------------------------

DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true
}';

--add new entry
PRINT JSON_MODIFY(@json, '$.Recorded', 'Abbey Road Studios');
GO
/*Result:
{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Recorded":"Abbey Road Studios"
}
*/
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Recorded":"Abbey Road Studios"
}';

--update existing entry to NULL
PRINT JSON_MODIFY(@json, 'strict $.Recorded', NULL);
GO
/*Result:
{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Recorded":null
}
*/

--remove existing entry
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Recorded":"Abbey Road Studios"
}';
PRINT JSON_MODIFY(@json, '$.Recorded', NULL);
GO
/*Result:
{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true
}
*/
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true
}';
PRINT JSON_MODIFY(@json, '$.IsVinyl', CAST(0 AS BIT));
GO
/*Result:
{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":false
}
*/

--update existing entry "IsVinyl":false (same lax/strict)
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true
}';
PRINT JSON_MODIFY(@json, 'strict $.IsVinyl', CAST(0 AS BIT));
GO
/*Result:
{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":false
}
*/

 
-- add a new property named Members and with an already prepared JSON array:
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true
}';
DECLARE @members NVARCHAR(500) = N'["Gilmour","Waters","Wright","Mason"]';
PRINT JSON_MODIFY(@json, '$.Members', @members);
GO
/*Result:
{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Members":"[\"Gilmour\",\"Waters\",\"Wright\",\"Mason\"]"
}
*/

--To avoid escaping of JSON conform text we need to instruct the function that the text is already JSON 
-- and escaping should not be performed. We achieve this by wrapping the new value with the JSON_QUERY function:
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true
}';
DECLARE @members NVARCHAR(500) = N'["Gilmour","Waters","Wright","Mason"]';
PRINT JSON_MODIFY(@json, '$.Members', JSON_QUERY(@members));
GO
/*Result:
{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Members":["Gilmour","Waters","Wright","Mason"]
}
*/

--updateing a value of JSON property
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1973
}';
PRINT JSON_MODIFY(@json, '$.Year', 1975);
PRINT JSON_MODIFY(@json, 'strict $.Year', 1975);
GO
/*Result:
{
"Album":"Wish You Were Here",
"Year":1975
}
{
"Album":"Wish You Were Here",
"Year":1975
}
*/


--replace the first element of the Members array (Gilmour) with the value (Barrett).
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"Members":["Gilmour","Waters","Wright","Mason"]
}';
PRINT JSON_MODIFY(@json, '$.Members[0]', 'Barrett');
GO
/*Result:
{
"Album":"Wish You Were Here",
"Year":1975,
"Members":["Barrett","Waters","Wright","Mason"]
}
*/

-- add a new element to an array, we have to use append
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"Members":["Gilmour","Waters","Wright","Mason"]
}';
PRINT JSON_MODIFY(@json, 'append $.Members', 'Barrett');
GO
/*Result:
{
"Album":"Wish You Were Here",
"Year":1975,
"Members":["Gilmour","Waters","Wright","Mason","Barrett"]
}
*/

--You can change only one property at time, for multiple changes you need multiple calls. 
--In this example we want to update the IsVinyl property to false, add new property Recorded 
--and add another element Barrett to the property Members.
DECLARE @json NVARCHAR(MAX) = N'{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":true,
"Members":["Gilmour","Waters","Wright","Mason"]
}';
PRINT JSON_MODIFY(JSON_MODIFY(JSON_MODIFY(@json, '$.IsVinyl', CAST(0 AS BIT)), '$.Recorded', 'Abbey Road Studios'), 'append $.Members', 'Barrett');
GO
/*Result:
{
"Album":"Wish You Were Here",
"Year":1975,
"IsVinyl":false,
"Members":["Gilmour","Waters","Wright","Mason","Barrett"],
"Recorded":"Abbey Road Studios"
}
*/

