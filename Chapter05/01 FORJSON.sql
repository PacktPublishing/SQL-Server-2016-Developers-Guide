--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide
--------	Chapter 05 - JSON Support
------Formatting and Exporting Data from SQL Server as JSON
--------------------------------------------------------------------

----------------------------------------------------
-- FOR JSON AUTO
----------------------------------------------------
 
--FOR JSON AUTO requires a table, you cannot use it without a database table or view. For instance, the following query will fail:
SELECT GETDATE() AS today FOR JSON AUTO;
/*Result:
Here is the error message.
Msg 13600, Level 16, State 1, Line 13
FOR JSON AUTO requires at least one table for generating JSON objects. Use FOR JSON PATH or add a FROM clause with a table name.
*/

USE WideWorldImporters;
SELECT  TOP (3) PersonID, FullName, EmailAddress, PhoneNumber
FROM Application.People ORDER BY PersonID ASC; 
/*Result:
PersonID    FullName                EmailAddress                      PhoneNumber
----------- ----------------------- --------------------------------  --------------
1           Data Conversion Only    NULL                              NULL
2           Kayla Woodcock          kaylaw@wideworldimporters.com     (415) 555-0102
3           Hudson Onslow           hudsono@wideworldimporters.com    (415) 555-0102

*/
--FOR XML AUTO
USE WideWorldImporters;
SELECT  TOP (3) PersonID, FullName, EmailAddress, PhoneNumber
FROM Application.People ORDER BY PersonID ASC FOR XML AUTO; 

/*Result:
XML_F52E2B61-18A1-11d1-B105-00805F49916B
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
<Application.People PersonID="1" FullName="Data Conversion Only" />
<Application.People PersonID="2" FullName="Kayla Woodcock" EmailAddress="kaylaw@wideworldimporters.com" PhoneNumber="(415) 555-0102" />
<Application.People PersonID="3" FullName="Hudson Onslow" EmailAddress="hudsono@wideworldimporters.com" PhoneNumber="(415) 555-0102" />
*/

--FOR JSON AUTO
SELECT TOP (3) PersonID, FullName, EmailAddress, PhoneNumber
FROM Application.People ORDER BY PersonID ASC FOR JSON AUTO;
/*Result:
[{"PersonID":1,"FullName":"Data Conversion Only"},{"PersonID":2,"FullName":"Kayla Woodcock","EmailAddress":"kaylaw@wideworldimporters.com","PhoneNumber":"(415) 555-0102"},{"PersonID":3,"FullName":"Hudson Onslow","EmailAddress":"hudsono@wideworldimporters.com","PhoneNumber":"(415) 555-0102"}]

Formatted result (with https://jsonformatter.curiousconcept.com)
[
   {
      "PersonID":1,
      "FullName":"Data Conversion Only"
   },
   {
      "PersonID":2,
      "FullName":"Kayla Woodcock",
      "EmailAddress":"kaylaw@wideworldimporters.com",
      "PhoneNumber":"(415) 555-0102"
   },
   {
      "PersonID":3,
      "FullName":"Hudson Onslow",
      "EmailAddress":"hudsono@wideworldimporters.com",
      "PhoneNumber":"(415) 555-0102"
   }
]
*/

--two tables
SELECT TOP (5) PersonID, FullName, EmailAddress, PhoneNumber, o.OrderID, o.OrderDate
FROM Application.People p
INNER JOIN Sales.Orders o ON p.PersonID = o.CustomerID
ORDER BY  OrderID
FOR JSON AUTO;
/*Result (formatted):
[
 [
   {
      "PersonID":10,
      "FullName":"Stella Rosenhain",
      "EmailAddress":"stellar@wideworldimporters.com",
      "PhoneNumber":"(415) 555-0102",
      "o":[
         {
            "OrderID":36,
            "OrderDate":"2013-01-01"
         },
         {
            "OrderID":72,
            "OrderDate":"2013-01-01"
         }
      ]
   },
   {
      "PersonID":3,
      "FullName":"Hudson Onslow",
      "EmailAddress":"hudsono@wideworldimporters.com",
      "PhoneNumber":"(415) 555-0102",
      "o":[
         {
            "OrderID":93,
            "OrderDate":"2013-01-02"
         }
      ]
   },
   {
      "PersonID":28,
      "FullName":"Helen Moore",
      "EmailAddress":"helenm@fabrikam.com",
      "PhoneNumber":"(203) 555-0104",
      "o":[
         {
            "OrderID":111,
            "OrderDate":"2013-01-02"
         }
      ]
   },
   {
      "PersonID":34,
      "FullName":"Vilma Niva",
      "EmailAddress":"vilman@litwareinc.com",
      "PhoneNumber":"(209) 555-0103",
      "o":[
         {
            "OrderID":120,
            "OrderDate":"2013-01-02"
         }
      ]
   }
]
*/

--When you compare data size between FOR XML AUTO and FOR JSON AUTO there is no significant difference, since XML RAW has less overhead
--But when you compare data size between FOR XML AUTO, ELEMENTS and FOR JSON AUTO, the difference is significant
USE WideWorldImporters;
SELECT 
	DATALENGTH(CAST((SELECT * FROM Sales.Orders FOR XML AUTO) AS NVARCHAR(MAX))) AS xml_raw_size,
	DATALENGTH(CAST((SELECT * FROM Sales.Orders FOR XML AUTO, ELEMENTS) AS NVARCHAR(MAX))) AS xml_elements_size,
	DATALENGTH(CAST((SELECT * FROM Sales.Orders FOR JSON AUTO) AS NVARCHAR(MAX))) AS json_size;
/*Result:
xml_raw_size         xml_elements_size    json_size
-------------------- -------------------- --------------------
49161702             81161852             49149364

*/

--When you compare data size between FOR XML AUTO and FOR JSON AUTO there is no significant difference, since XML RAW has less overhead
SELECT 
	DATALENGTH(CAST((SELECT * FROM Sales.Orders o INNER JOIN Sales.OrderLines l ON o.OrderID = l.OrderID FOR XML AUTO) AS NVARCHAR(MAX))) AS xml_raw_size,
	DATALENGTH(CAST((SELECT * FROM Sales.Orders o INNER JOIN Sales.OrderLines l ON o.OrderID = l.OrderID FOR JSON AUTO) AS NVARCHAR(MAX))) AS json_size;
/*Result:
xml_raw_size         json_size
-------------------- --------------------
186427802            189918034

JSON data  is even 2% larger
*/

----------------------------------------------------
-- FOR JSON PATH
----------------------------------------------------

--it does not require a table
SELECT GETDATE() AS today FOR JSON PATH;
/*Result:
[
{"today":"2016-07-26T09:13:32.007"}
]
*/


SELECT TOP (3) PersonID, FullName, EmailAddress, PhoneNumber 
FROM Application.People ORDER BY PersonID ASC FOR JSON PATH;

/*Result (formatted):
[
   {
      "PersonID":1,
      "FullName":"Data Conversion Only"
   },
   {
      "PersonID":2,
      "FullName":"Kayla Woodcock",
      "EmailAddress":"kaylaw@wideworldimporters.com",
      "PhoneNumber":"(415) 555-0102"
   },
   {
      "PersonID":3,
      "FullName":"Hudson Onslow",
      "EmailAddress":"hudsono@wideworldimporters.com",
      "PhoneNumber":"(415) 555-0102"
   }
]
*/

SELECT TOP (3) PersonID, FullName, EmailAddress AS 'Contact.Email', PhoneNumber AS 'Contact.Phone' 
FROM Application.People ORDER BY PersonID ASC FOR JSON PATH;
/*Result (formatted):
[
   {
      "PersonID":1,
      "FullName":"Data Conversion Only"
   },
   {
      "PersonID":2,
      "FullName":"Kayla Woodcock",
      "Contact":{
         "Email":"kaylaw@wideworldimporters.com",
         "Phone":"(415) 555-0102"
      }
   },
   {
      "PersonID":3,
      "FullName":"Hudson Onslow",
      "Contact":{
         "Email":"hudsono@wideworldimporters.com",
         "Phone":"(415) 555-0102"
      }
   }
]
*/

--two tables
--default
SELECT TOP 2 H.OrderID,  
       H.OrderDate,  
       D.UnitPrice,  
       D.Quantity  
FROM Sales.Orders H  
  INNER JOIN Sales.OrderLines D  
    ON H.OrderID = D.OrderID  
FOR JSON PATH;  
/*Result (formatted):
[
   {
      "OrderID":429,
      "OrderDate":"2013-01-08",
      "D":[
         {
            "UnitPrice":13.00,
            "Quantity":7
         }
      ]
   },
   {
      "OrderID":1267,
      "OrderDate":"2013-01-25",
      "D":[
         {
            "UnitPrice":13.00,
            "Quantity":7
         }
      ]
   }
]
*/

--user defined
SELECT TOP 2 H.OrderID AS 'Order.Number',  
       H.OrderDate AS 'Order.Date',  
       D.UnitPrice AS 'Product.Price',  
       D.Quantity AS 'Product.Quantity'  
FROM Sales.Orders H  
  INNER JOIN Sales.OrderLines D  
    ON H.OrderID = D.OrderID  
FOR JSON PATH;  
/*Result (formatted):
[
   {
      "Order":{
         "Number":429,
         "Date":"2013-01-08"
      },
      "Product":{
         "Price":13.00,
         "Quantity":7
      }
   },
   {
      "Order":{
         "Number":1267,
         "Date":"2013-01-25"
      },
      "Product":{
         "Price":13.00,
         "Quantity":7
      }
   }
]
*/




----------------------------------------------------
-- Add a Root Node to JSON Output
----------------------------------------------------

SELECT TOP (3) PersonID, FullName, EmailAddress, PhoneNumber
FROM Application.People ORDER BY PersonID ASC FOR JSON AUTO, ROOT('Persons');
/*Result (formatted):
{
   "Persons":[
      {
         "PersonID":1,
         "FullName":"Data Conversion Only"
      },
      {
         "PersonID":2,
         "FullName":"Kayla Woodcock",
         "EmailAddress":"kaylaw@wideworldimporters.com",
         "PhoneNumber":"(415) 555-0102"
      },
      {
         "PersonID":3,
         "FullName":"Hudson Onslow",
         "EmailAddress":"hudsono@wideworldimporters.com",
         "PhoneNumber":"(415) 555-0102"
      }
   ]
}
*/

---------------------------------------------------------------
-- Include Null Values in JSON Output (similar to XSINIL)
---------------------------------------------------------------

SELECT TOP (3) PersonID, FullName, EmailAddress, PhoneNumber 
FROM Application.People ORDER BY PersonID ASC FOR JSON AUTO, INCLUDE_NULL_VALUES;
/*Result (formatted):
[
   {
      "PersonID":1,
      "FullName":"Data Conversion Only",
      "EmailAddress":null,
      "PhoneNumber":null
   },
   {
      "PersonID":2,
      "FullName":"Kayla Woodcock",
      "EmailAddress":"kaylaw@wideworldimporters.com",
      "PhoneNumber":"(415) 555-0102"
   },
   {
      "PersonID":3,
      "FullName":"Hudson Onslow",
      "EmailAddress":"hudsono@wideworldimporters.com",
      "PhoneNumber":"(415) 555-0102"
   }
]
*/

---------------------------------------------------------------
-- Format JSON Output as Single Object (WITHOUT_ARRAY_WRAPPER)
---------------------------------------------------------------
--Format JSON Output as Single Object
SELECT PersonID, FullName, EmailAddress, PhoneNumber 
FROM Application.People WHERE PersonID = 2 FOR JSON AUTO;

/*Result (formatted):
[
   {
      "PersonID":2,
      "FullName":"Kayla Woodcock",
      "EmailAddress":"kaylaw@wideworldimporters.com",
      "PhoneNumber":"(415) 555-0102"
   }
]
*/

SELECT PersonID, FullName, EmailAddress, PhoneNumber 
FROM Application.People WHERE PersonID = 2 FOR JSON AUTO, WITHOUT_ARRAY_WRAPPER;
/*Result (formatted):
{
   "PersonID":2,
   "FullName":"Kayla Woodcock",
   "EmailAddress":"kaylaw@wideworldimporters.com",
   "PhoneNumber":"(415) 555-0102"
}
*/

--Format JSON Output as Single Object (it can happen that the data is not valid JSON)
SELECT PersonID, FullName, EmailAddress, PhoneNumber 
FROM Application.People WHERE PersonID IN (2, 3) FOR JSON AUTO, WITHOUT_ARRAY_WRAPPER;
/*Result (formatted):
{
   "PersonID":2,
   "FullName":"Kayla Woodcock",
   "EmailAddress":"kaylaw@wideworldimporters.com",
   "PhoneNumber":"(415) 555-0102"
},
{
   "PersonID":3,
   "FullName":"Hudson Onslow",
   "EmailAddress":"hudsono@wideworldimporters.com",
   "PhoneNumber":"(415) 555-0102"
}
*/
