--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide
--------	Chapter 05 - JSON Support
--------			JSON_QUERY
--------------------------------------------------------------------

--------------------------------------------------------------------
-- JSON_QUERY
--------------------------------------------------------------------
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
--get Songs JSON fragment (array)
SELECT JSON_QUERY(@json,'$.Songs');
--get Members SON fragment (object)
SELECT JSON_QUERY(@json,'$.Members');
--get fourth Song JSON fragment (object)
SELECT JSON_QUERY(@json,'$.Songs[3]');
--get property value (number)
SELECT JSON_QUERY(@json,'$.Year');
--get property value (string)
SELECT JSON_QUERY(@json,'$.Songs[1].Title');
--get value for non-existing property
SELECT JSON_QUERY(@json,'$.Studios');
GO
/*Result:
[{"Title":"Shine On You Crazy Diamond","Writers":"Gilmour, Waters, Wright"},
{"Title":"Have a Cigar","Writers":"Waters"},
{"Title":"Welcome to the Machine","Writers":"Waters"},
{"Title":"Wish You Were Here","Writers":"Gilmour, Waters"}]

{"Guitar":"David Gilmour","Bass Guitar":"Roger Waters","Keyboard":"Richard Wright","Drums":"Nick Mason"}

{"Title":"Wish You Were Here","Writers":"Gilmour, Waters"}

NULL

NULL

NULL
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
--get property value (number)
SELECT JSON_QUERY(@json,'strict $.Year');
/*Result:
Msg 13624, Level 16, State 1, Line 54
Object or array cannot be found in the specified JSON path.
*/
--get value for non-existing property
SELECT JSON_QUERY(@json,'strict $.Studios');
/*Result:
Msg 13608, Level 16, State 5, Line 60
Property cannot be found on the specified JSON path
*/

--create a check constraint ensures that all persons in the People table 
--have the property OtherLanguages in within the column CustomFields if this column has value
USE WideWorldImporters;
ALTER TABLE Application.People
ADD CONSTRAINT CHK_ OtherLanguagesRequired
CHECK (JSON_QUERY(CustomFields, '$.OtherLanguages') IS NOT NULL OR CustomFields IS NULL);
GO

 