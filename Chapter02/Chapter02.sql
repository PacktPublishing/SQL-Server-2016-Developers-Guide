--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide				--------
---- Chapter 02 - Review of SQL Server Features for Developers -----
--------------------------------------------------------------------

----------------------------------------------------
-- Section 1: Transact-SQL SELECT
----------------------------------------------------

-- SELECT..FROM..WHERE..GROUP BY..HAVING..ORDER BY

-- The simplest query
USE WideWorldImportersDW;
SELECT *
FROM Dimension.Customer;

-- Projection - specifying columns
SELECT [Customer Key], [WWI Customer ID],
  [Customer], [Buying Group]
FROM Dimension.Customer;

-- Adding column aliases
SELECT [Customer Key] AS CustomerKey,
  [WWI Customer ID] AS CustomerId,
  [Customer],
  [Buying Group] AS BuyingGroup
FROM Dimension.Customer;

-- Filtering unknown customer
SELECT [Customer Key] AS CustomerKey,
  [WWI Customer ID] AS CustomerId,
  [Customer], 
  [Buying Group] AS BuyingGroup
FROM Dimension.Customer
WHERE [Customer Key] <> 0;

-- Joining to sales fact table and adding table aliases
SELECT c.[Customer Key] AS CustomerKey,
  c.[WWI Customer ID] AS CustomerId,
  c.[Customer], 
  c.[Buying Group] AS BuyingGroup,
  f.Quantity,
  f.[Total Excluding Tax] AS Amount,
  f.Profit
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS c
    ON f.[Customer Key] = c.[Customer Key];
-- 228265 rows

-- Filtering unknown customer
SELECT c.[Customer Key] AS CustomerKey,
  c.[WWI Customer ID] AS CustomerId,
  c.[Customer], 
  c.[Buying Group] AS BuyingGroup,
  f.Quantity,
  f.[Total Excluding Tax] AS Amount,
  f.Profit
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS c
    ON f.[Customer Key] = c.[Customer Key]
WHERE c.[Customer Key] <> 0;
-- 143968 rows

-- Joining sales fact table with dimension Date
SELECT d.Date, f.[Total Excluding Tax],
  f.[Delivery Date Key]
FROM Fact.Sale AS f
  INNER JOIN Dimension.Date AS d
    ON f.[Delivery Date Key] = d.Date;
-- 227981 rows

-- Using a LEFT OUTER JOIN and ordering the result
SELECT d.Date, f.[Total Excluding Tax],
  f.[Delivery Date Key], f.[Invoice Date Key]
FROM Fact.Sale AS f
  LEFT OUTER JOIN Dimension.Date AS d
    ON f.[Delivery Date Key] = d.Date
ORDER BY f.[Invoice Date Key] DESC;
-- 228265 rows
-- For the last invoice date (2016-05-31), delivery date is NULL

-- Joining multiple tables and controlling outer join order
-- Sales - fact table & all dimensions
SELECT cu.[Customer Key] AS CustomerKey, cu.Customer,
  ci.[City Key] AS CityKey, ci.City, 
  ci.[State Province] AS StateProvince, ci.[Sales Territory] AS SalesTeritory,
  d.Date, d.[Calendar Month Label] AS CalendarMonth, 
  d.[Calendar Year] AS CalendarYear,
  s.[Stock Item Key] AS StockItemKey, s.[Stock Item] AS Product, s.Color,
  e.[Employee Key] AS EmployeeKey, e.Employee,
  f.Quantity, f.[Total Excluding Tax] AS TotalAmount, f.Profit
FROM (Fact.Sale AS f
  INNER JOIN Dimension.Customer AS cu
    ON f.[Customer Key] = cu.[Customer Key]
  INNER JOIN Dimension.City AS ci
    ON f.[City Key] = ci.[City Key]
  INNER JOIN Dimension.[Stock Item] AS s
    ON f.[Stock Item Key] = s.[Stock Item Key]
  INNER JOIN Dimension.Employee AS e
    ON f.[Salesperson Key] = e.[Employee Key])
  LEFT OUTER JOIN Dimension.Date AS d
    ON f.[Delivery Date Key] = d.Date;
-- 228265 rows

-- Checking the number if rows in the sales fact table
-- Introducing an aggregate function
SELECT COUNT(*) AS SalesCount
FROM Fact.Sale;
-- 228265

-- Aggregates in groups - introducting GROUP BY
SELECT c.Customer,
  SUM(f.Quantity) AS TotalQuantity,
  SUM(f.[Total Excluding Tax]) AS TotalAmount,
  COUNT(*) AS SalesCount
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS c
    ON f.[Customer Key] = c.[Customer Key]
WHERE c.[Customer Key] <> 0
GROUP BY c.Customer;
-- 402 rows

-- Customers with more than 400 sales
-- Filtering aggregates - introducing HAVING
-- Note: can't use column aliases in HAVING
SELECT c.Customer,
  SUM(f.Quantity) AS TotalQuantity,
  SUM(f.[Total Excluding Tax]) AS TotalAmount,
  COUNT(*) AS SalesCount
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS c
    ON f.[Customer Key] = c.[Customer Key]
WHERE c.[Customer Key] <> 0
GROUP BY c.Customer
HAVING COUNT(*) > 400;
-- 45 rows

-- Customers with more than 400 sales,
-- ordered by sales count descending
-- Note: can use column aliases in ORDER BY
SELECT c.Customer,
  SUM(f.Quantity) AS TotalQuantity,
  SUM(f.[Total Excluding Tax]) AS TotalAmount,
  COUNT(*) AS SalesCount
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS c
    ON f.[Customer Key] = c.[Customer Key]
WHERE c.[Customer Key] <> 0
GROUP BY c.Customer
HAVING COUNT(*) > 400
ORDER BY SalesCount DESC;
-- 45 rows

-- Introducing window functions

-- Aggregates in partitions and total

-- Subqueries
SELECT c.Customer,
  f.Quantity,
  (SELECT SUM(f1.Quantity) FROM Fact.Sale AS f1
   WHERE f1.[Customer Key] = c.[Customer Key]) AS TotalCustomerQuantity,
  f2.TotalQuantity
FROM (Fact.Sale AS f
  INNER JOIN Dimension.Customer AS c
    ON f.[Customer Key] = c.[Customer Key])
  CROSS JOIN 
    (SELECT SUM(f2.Quantity) FROM Fact.Sale AS f2
	 WHERE f2.[Customer Key] <> 0) AS f2(TotalQuantity)
WHERE c.[Customer Key] <> 0
ORDER BY c.Customer, f.Quantity DESC;

-- Window functions
SELECT c.Customer,
  f.Quantity,
  SUM(f.Quantity)
   OVER(PARTITION BY c.Customer) AS TotalCustomerQuantity,
  SUM(f.Quantity)
   OVER() AS TotalQuantity
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS c
    ON f.[Customer Key] = c.[Customer Key]
WHERE c.[Customer Key] <> 0
ORDER BY c.Customer, f.Quantity DESC;

-- Row number in partitions and total
SELECT c.Customer,
  f.Quantity,
  ROW_NUMBER()
   OVER(PARTITION BY c.Customer
        ORDER BY f.Quantity DESC) AS CustomerOrderPosition,
  ROW_NUMBER()
   OVER(ORDER BY f.Quantity DESC) AS TotalOrderPosition
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS c
    ON f.[Customer Key] = c.[Customer Key]
WHERE c.[Customer Key] <> 0
ORDER BY c.Customer, f.Quantity DESC;

-- Running total quantity per customer and
-- moving average over last three sales keys
SELECT c.Customer,
  f.[Sale Key] AS SaleKey,
  f.Quantity,
  SUM(f.Quantity)
   OVER(PARTITION BY c.Customer
        ORDER BY [Sale Key]
	    ROWS BETWEEN UNBOUNDED PRECEDING
                 AND CURRENT ROW) AS Q_RT,
  AVG(f.Quantity)
   OVER(PARTITION BY c.Customer
        ORDER BY [Sale Key]
	    ROWS BETWEEN 2 PRECEDING
                 AND CURRENT ROW) AS Q_MA
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS c
    ON f.[Customer Key] = c.[Customer Key]
WHERE c.[Customer Key] <> 0
ORDER BY c.Customer, f.[Sale Key];

-- Top 3 orders by quantity for Tailspin Toys (Aceitunas, PR) 
SELECT c.Customer,
  f.[Sale Key] AS SaleKey,
  f.Quantity
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS c
    ON f.[Customer Key] = c.[Customer Key]
WHERE c.Customer = N'Tailspin Toys (Aceitunas, PR)'
ORDER BY f.Quantity DESC
OFFSET 0 ROWS FETCH NEXT 3 ROWS ONLY;
-- 3 rows

-- Top 3 orders by quantity with ties
SELECT TOP 3 WITH TIES
  c.Customer,
  f.[Sale Key] AS SaleKey,
  f.Quantity
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS c
    ON f.[Customer Key] = c.[Customer Key]
WHERE c.Customer = N'Tailspin Toys (Aceitunas, PR)'
ORDER BY f.Quantity DESC;
-- 4 rows

-- Top 3 orders by quantity for each customer
-- Introducing APPLY
SELECT c.Customer,
  t3.SaleKey, t3.Quantity
FROM Dimension.Customer AS c
  CROSS APPLY (SELECT TOP(3) 
                 f.[Sale Key] AS SaleKey,
                 f.Quantity
                FROM Fact.Sale AS f
                WHERE f.[Customer Key] = c.[Customer Key]
                ORDER BY f.Quantity DESC) AS t3
WHERE c.[Customer Key] <> 0
ORDER BY c.Customer, t3.Quantity DESC;

-- Calculating averages and standard deviation
-- for customers' orders
-- Introducing common table expressions (CTEs)
WITH CustomerSalesCTE AS
(
SELECT c.Customer, 
  SUM(f.[Total Excluding Tax]) AS TotalAmount,
  COUNT(*) AS SalesCount
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS c
    ON f.[Customer Key] = c.[Customer Key]
WHERE c.[Customer Key] <> 0 
GROUP BY c.Customer
)
SELECT ROUND(AVG(TotalAmount), 6) AS AvgAmountPerCustomer,
  ROUND(STDEV(TotalAmount), 6) AS StDevAmountPerCustomer, 
  AVG(SalesCount) AS AvgCountPerCustomer
FROM CustomerSalesCTE;
GO


----------------------------------------------------
-- Section 2: DDL, DML, and programmable objects
----------------------------------------------------

-- Creating two simple tables
IF OBJECT_ID(N'dbo.SimpleOrders', N'U') IS NOT NULL
   DROP TABLE dbo.SimpleOrders;
CREATE TABLE dbo.SimpleOrders
(
  OrderId   INT         NOT NULL,
  OrderDate DATE        NOT NULL,
  Customer  NVARCHAR(5) NOT NULL,
  CONSTRAINT PK_SimpleOrders PRIMARY KEY (OrderId)
);
GO

IF OBJECT_ID(N'dbo.SimpleOrderDetails', N'U') IS NOT NULL
   DROP TABLE dbo.SimpleOrderDetails;
CREATE TABLE dbo.SimpleOrderDetails
(
  OrderId   INT NOT NULL,
  ProductId INT NOT NULL,
  Quantity  INT NOT NULL
   CHECK(Quantity <> 0),
  CONSTRAINT PK_SimpleOrderDetails
   PRIMARY KEY (OrderId, ProductId)
);
GO

-- Adding a foreign key
ALTER TABLE dbo.SimpleOrderDetails ADD CONSTRAINT FK_Details_Orders
FOREIGN KEY (OrderId) REFERENCES dbo.SimpleOrders(OrderId);
GO

-- Inserting some data
INSERT INTO dbo.SimpleOrders
 (OrderId, OrderDate, Customer)
VALUES
 (1, '20160701', N'CustA');
INSERT INTO dbo.SimpleOrderDetails
 (OrderId, ProductId, Quantity)
VALUES
 (1, 7, 100),
 (1, 3, 200);
GO

-- Check the data
SELECT o.OrderId, o.OrderDate, o.Customer,
  od.ProductId, od.Quantity
FROM dbo.SimpleOrderDetails AS od
  INNER JOIN dbo.SimpleOrders AS o
    ON od.OrderId = o.OrderId
ORDER BY o.OrderId, od.ProductId;

-- Update a row
UPDATE dbo.SimpleOrderDetails
   SET Quantity = 150
WHERE OrderId = 1
  AND ProductId = 3;

-- Check the data
SELECT o.OrderId, o.OrderDate, o.Customer,
  od.ProductId, od.Quantity
FROM dbo.SimpleOrderDetails AS od
  INNER JOIN dbo.SimpleOrders AS o
    ON od.OrderId = o.OrderId
ORDER BY o.OrderId, od.ProductId;
GO

-- Returning modifications - introducing OUTPUT
INSERT INTO dbo.SimpleOrders
 (OrderId, OrderDate, Customer)
OUTPUT inserted.*
VALUES
 (2, '20160701', N'CustB');
INSERT INTO dbo.SimpleOrderDetails
 (OrderId, ProductId, Quantity)
OUTPUT inserted.*
VALUES
 (2, 4, 200);
GO

-- Using a trigger to correct order dates in the past
-- with a default date 20160101

-- Insert of an old order date without a trigger 
INSERT INTO dbo.SimpleOrders
 (OrderId, OrderDate, Customer)
VALUES
 (3, '20100701', N'CustC');
 -- Check the data
SELECT o.OrderId, o.OrderDate, o.Customer
FROM dbo.SimpleOrders AS o
ORDER BY o.OrderId;
GO

-- Create the trigger
CREATE TRIGGER trg_SimpleOrders_OrdereDate
 ON dbo.SimpleOrders AFTER INSERT, UPDATE
AS
 UPDATE dbo.SimpleOrders
    SET OrderDate = '20160101'
 WHERE OrderDate < '20160101';
GO

-- Try to insert an old order date 
-- and update a valid order date 
INSERT INTO dbo.SimpleOrders
 (OrderId, OrderDate, Customer)
VALUES
 (4, '20100701', N'CustD');
UPDATE dbo.SimpleOrders
   SET OrderDate = '20110101'
 WHERE OrderId = 3;
-- Check the data
SELECT o.OrderId, o.OrderDate, o.Customer,
  od.ProductId, od.Quantity
FROM dbo.SimpleOrderDetails AS od
  RIGHT OUTER JOIN dbo.SimpleOrders AS o
    ON od.OrderId = o.OrderId
ORDER BY o.OrderId, od.ProductId;
GO

-- Creating stored procedures for inserts
CREATE PROCEDURE dbo.InsertSimpleOrder
(@OrderId AS INT, @OrderDate AS DATE, @Customer AS NVARCHAR(5))
AS
INSERT INTO dbo.SimpleOrders
 (OrderId, OrderDate, Customer)
VALUES
 (@OrderId, @OrderDate, @Customer);
GO

CREATE PROCEDURE dbo.InsertSimpleOrderDetail
(@OrderId AS INT, @ProductId AS INT, @Quantity AS INT)
AS 
INSERT INTO dbo.SimpleOrderDetails
 (OrderId, ProductId, Quantity)
VALUES
 (@OrderId, @ProductId, @Quantity);
GO

-- Test the procedures
EXEC dbo.InsertSimpleOrder
 @OrderId = 5, @OrderDate = '20160702', @Customer = N'CustA';
EXEC dbo.InsertSimpleOrderDetail
 @OrderId = 5, @ProductId = 1, @Quantity = 50;
-- Inserting couple of order details
EXEC dbo.InsertSimpleOrderDetail
 @OrderId = 2, @ProductId = 5, @Quantity = 150;
EXEC dbo.InsertSimpleOrderDetail
 @OrderId = 2, @ProductId = 6, @Quantity = 250;
EXEC dbo.InsertSimpleOrderDetail
 @OrderId = 1, @ProductId = 5, @Quantity = 50;
EXEC dbo.InsertSimpleOrderDetail
 @OrderId = 1, @ProductId = 6, @Quantity = 200;
-- Check the data
SELECT o.OrderId, o.OrderDate, o.Customer,
  od.ProductId, od.Quantity
FROM dbo.SimpleOrderDetails AS od
  RIGHT OUTER JOIN dbo.SimpleOrders AS o
    ON od.OrderId = o.OrderId
ORDER BY o.OrderId, od.ProductId;
GO

-- Creating a view to quickly find orders without details
CREATE VIEW dbo.OrdersWithoutDetails
AS
SELECT o.OrderId, o.OrderDate, o.Customer
FROM dbo.SimpleOrderDetails AS od
  RIGHT OUTER JOIN dbo.SimpleOrders AS o
    ON od.OrderId = o.OrderId
WHERE od.OrderId IS NULL;
GO
-- Using the view
SELECT OrderId, OrderDate, Customer
FROM dbo.OrdersWithoutDetails;
GO

-- Creating a function to select top 2 order details by quantity for an order
CREATE FUNCTION dbo.Top2OrderDetails
(@OrderId AS INT)
RETURNS TABLE
AS RETURN
SELECT TOP 2 ProductId, Quantity
FROM dbo.SimpleOrderDetails
WHERE OrderId = @OrderId
ORDER BY Quantity DESC;
GO

-- Using the function with OUTER APPLY
SELECT o.OrderId, o.OrderDate, o.Customer,
  t2.ProductId, t2.Quantity
FROM dbo.SimpleOrders AS o
  OUTER APPLY dbo.Top2OrderDetails(o.OrderId) AS t2
ORDER BY o.OrderId, t2.Quantity DESC;
GO


----------------------------------------------------
-- Section 3: Transactions and error handling
----------------------------------------------------

-- No error handling
EXEC dbo.InsertSimpleOrder
 @OrderId = 6, @OrderDate = '20160706', @Customer = N'CustE';
EXEC dbo.InsertSimpleOrderDetail
 @OrderId = 6, @ProductId = 2, @Quantity = 0;
-- Error 547 - The INSERT statement conflicted with the CHECK constraint
-- Quantity must be greater than 0

-- Try to insert order 6 another time
EXEC dbo.InsertSimpleOrder
 @OrderId = 6, @OrderDate = '20160706', @Customer = N'CustE';
-- Error 2627 - Violation of PRIMARY KEY constraint

-- Check the data
SELECT o.OrderId, o.OrderDate, o.Customer,
  od.ProductId, od.Quantity
FROM dbo.SimpleOrderDetails AS od
  RIGHT OUTER JOIN dbo.SimpleOrders AS o
    ON od.OrderId = o.OrderId
WHERE o.OrderId > 5
ORDER BY o.OrderId, od.ProductId;
GO

-- Handling errors with TRY..CATCH

-- Error in the first statement
BEGIN TRY
 EXEC dbo.InsertSimpleOrder
  @OrderId = 6, @OrderDate = '20160706', @Customer = N'CustF';
 EXEC dbo.InsertSimpleOrderDetail
  @OrderId = 6, @ProductId = 2, @Quantity = 5;
END TRY
BEGIN CATCH
 SELECT ERROR_NUMBER(),
   ERROR_MESSAGE(),
   ERROR_LINE();
END CATCH
-- Check the data
SELECT o.OrderId, o.OrderDate, o.Customer,
  od.ProductId, od.Quantity
FROM dbo.SimpleOrderDetails AS od
  RIGHT OUTER JOIN dbo.SimpleOrders AS o
    ON od.OrderId = o.OrderId
WHERE o.OrderId > 5
ORDER BY o.OrderId, od.ProductId;
-- 2nd command was not executed, control was
-- transferred immediately after the error to the catch block
GO

-- Error in the second statement
BEGIN TRY
 EXEC dbo.InsertSimpleOrder
  @OrderId = 7, @OrderDate = '20160706', @Customer = N'CustF';
 EXEC dbo.InsertSimpleOrderDetail
  @OrderId = 7, @ProductId = 2, @Quantity = 0;
END TRY
BEGIN CATCH
 SELECT ERROR_NUMBER(),
   ERROR_MESSAGE(),
   ERROR_LINE();
END CATCH
-- Check the data
SELECT o.OrderId, o.OrderDate, o.Customer,
  od.ProductId, od.Quantity
FROM dbo.SimpleOrderDetails AS od
  RIGHT OUTER JOIN dbo.SimpleOrders AS o
    ON od.OrderId = o.OrderId
WHERE o.OrderId > 5
ORDER BY o.OrderId, od.ProductId;
-- 1st command was executed
GO

-- Using transactions
-- Error in the second statement
BEGIN TRY
 BEGIN TRANSACTION
  EXEC dbo.InsertSimpleOrder
   @OrderId = 8, @OrderDate = '20160706', @Customer = N'CustG';
  EXEC dbo.InsertSimpleOrderDetail
   @OrderId = 8, @ProductId = 2, @Quantity = 0;
 COMMIT TRANSACTION
END TRY
BEGIN CATCH
 SELECT ERROR_NUMBER(),
   ERROR_MESSAGE(),
   ERROR_LINE();
 IF XACT_STATE() <> 0
    ROLLBACK TRANSACTION;
END CATCH
-- Check the data
SELECT o.OrderId, o.OrderDate, o.Customer,
  od.ProductId, od.Quantity
FROM dbo.SimpleOrderDetails AS od
  RIGHT OUTER JOIN dbo.SimpleOrders AS o
    ON od.OrderId = o.OrderId
WHERE o.OrderId > 5
ORDER BY o.OrderId, od.ProductId;
-- 1st command was rolled back as well
GO

-- Clean up
DROP FUNCTION dbo.Top2OrderDetails;
DROP VIEW dbo.OrdersWithoutDetails;
DROP PROCEDURE dbo.InsertSimpleOrderDetail;
DROP PROCEDURE dbo.InsertSimpleOrder;
DROP TABLE dbo.SimpleOrderDetails;
DROP TABLE dbo.SimpleOrders;
GO


----------------------------------------------------
-- Section 4: Beyond relational
----------------------------------------------------

-- Spatial data
SELECT City,
  [Sales Territory] AS SalesTerritory,
  Location AS LocationBinary,
  Location.ToString() AS LocationLongLat
FROM Dimension.City
WHERE [City Key] <> 0
  AND [Sales Territory] NOT IN
      (N'External', N'Far West');
-- Check the spatial results
-- Only first 5000 objects displayed

-- Denver, Colorado data
SELECT [City Key] AS CityKey, City,
  [State Province] AS State,
  [Latest Recorded Population] AS Population,
  Location.ToString() AS LocationLongLat
FROM Dimension.City
WHERE [City Key] = 114129
  AND [Valid To] = '9999-12-31 23:59:59.9999999';

-- Distance between Denver and Seattle
DECLARE @g AS GEOGRAPHY;
DECLARE @h AS GEOGRAPHY;
DECLARE @unit AS NVARCHAR(50);
SET @g = (SELECT Location FROM Dimension.City
          WHERE [City Key] = 114129);
SET @h = (SELECT Location FROM Dimension.City
          WHERE [City Key] = 108657);
SET @unit = (SELECT unit_of_measure 
             FROM sys.spatial_reference_systems
             WHERE spatial_reference_id = @g.STSrid);
SELECT FORMAT(@g.STDistance(@h), 'N', 'en-us') AS Distance,
 @unit AS Unit;
GO

-- Major cities withing circle of 1,000 km around Denver, Colorado
DECLARE @g AS GEOGRAPHY;
SET @g = (SELECT Location FROM Dimension.City
          WHERE [City Key] = 114129);
SELECT DISTINCT City,
  [State Province] AS State,
  FORMAT([Latest Recorded Population], '000,000') AS Population,
  FORMAT(@g.STDistance(Location), '000,000.00') AS Distance
FROM Dimension.City
WHERE Location.STIntersects(@g.STBuffer(1000000)) = 1
  AND [Latest Recorded Population] > 200000
  AND [City Key] <> 114129
  AND [Valid To] = '9999-12-31 23:59:59.9999999'
ORDER BY Distance;
GO

-- CLR integration

-- C# code skewness and kurtosis 
/*
using System;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using Microsoft.SqlServer.Server;

[Serializable]
[SqlUserDefinedAggregate(
   Format.Native,	              
   IsInvariantToDuplicates = false, 
   IsInvariantToNulls = true,       
   IsInvariantToOrder = true,     
   IsNullIfEmpty = false)]            
public struct Skew
{
	private double rx;	
	private double rx2;	
	private double r2x;	
	private double rx3;	
	private double r3x2;
	private double r3x;	
	private Int64 rn;	
 
	public void Init()
	{
		rx = 0;
		rx2 = 0;
		r2x = 0;
		rx3 = 0;
		r3x2 = 0;
		r3x = 0;
		rn = 0;
	}

	public void Accumulate(SqlDouble inpVal)
	{
		if (inpVal.IsNull)
		{
			return;
		}
		rx = rx + inpVal.Value;
		rx2 = rx2 + Math.Pow(inpVal.Value, 2);
		r2x = r2x + 2 * inpVal.Value;
		rx3 = rx3 + Math.Pow(inpVal.Value, 3);
		r3x2 = r3x2 + 3 * Math.Pow(inpVal.Value, 2);
		r3x = r3x + 3 * inpVal.Value;
		rn = rn + 1;
	}

	public void Merge(Skew Group)
	{
		this.rx = this.rx + Group.rx;
		this.rx2 = this.rx2 + Group.rx2;
		this.r2x = this.r2x + Group.r2x;
		this.rx3 = this.rx3 + Group.rx3;
		this.r3x2 = this.r3x2 + Group.r3x2;
		this.r3x = this.r3x + Group.r3x;
		this.rn = this.rn + Group.rn;
	}

	public SqlDouble Terminate()
	{
		double myAvg = (rx / rn);
		double myStDev = Math.Pow((rx2 - r2x * myAvg + rn * Math.Pow(myAvg, 2))
		                 / (rn - 1), 1d / 2d);
		double mySkew = (rx3 - r3x2 * myAvg + r3x * Math.Pow(myAvg, 2)
		                - rn * Math.Pow(myAvg, 3)) /
						Math.Pow(myStDev,3) * rn / (rn - 1) / (rn - 2);
		return (SqlDouble)mySkew;
	}

}

[Serializable]
[SqlUserDefinedAggregate(
   Format.Native,
   IsInvariantToDuplicates = false,
   IsInvariantToNulls = true,
   IsInvariantToOrder = true,
   IsNullIfEmpty = false)]
public struct Kurt
{
	private double rx;	
	private double rx2;	
	private double r2x;	
	private double rx4;	
	private double r4x3;
	private double r6x2;
	private double r4x;	
	private Int64 rn;

	public void Init()
	{
		rx = 0;
		rx2 = 0;
		r2x = 0;
		rx4 = 0;
		r4x3 = 0;
		r6x2 = 0;
		r4x = 0;
		rn = 0;
	}

	public void Accumulate(SqlDouble inpVal)
	{
		if (inpVal.IsNull)
		{
			return;
		}
		rx = rx + inpVal.Value;
		rx2 = rx2 + Math.Pow(inpVal.Value, 2);
		r2x = r2x + 2 * inpVal.Value;
		rx4 = rx4 + Math.Pow(inpVal.Value, 4);
		r4x3 = r4x3 + 4 * Math.Pow(inpVal.Value, 3);
		r6x2 = r6x2 + 6 * Math.Pow(inpVal.Value, 2);
		r4x = r4x + 4 * inpVal.Value;
		rn = rn + 1;
	}

	public void Merge(Kurt Group)
	{
		this.rx = this.rx + Group.rx;
		this.rx2 = this.rx2 + Group.rx2;
		this.r2x = this.r2x + Group.r2x;
		this.rx4 = this.rx4 + Group.rx4;
		this.r4x3 = this.r4x3 + Group.r4x3;
		this.r6x2 = this.r6x2 + Group.r6x2;
		this.r4x = this.r4x + Group.r4x;
		this.rn = this.rn + Group.rn;
	}

	public SqlDouble Terminate()
	{
		double myAvg = (rx / rn);
		double myStDev = Math.Pow((rx2 - r2x * myAvg + rn * Math.Pow(myAvg, 2)) / (rn - 1), 1d / 2d);
		double myKurt = (rx4 - r4x3 * myAvg + r6x2 * Math.Pow(myAvg, 2) - r4x * Math.Pow(myAvg, 3) + rn * Math.Pow(myAvg, 4)) /
						Math.Pow(myStDev, 4) * rn * (rn + 1) / (rn - 1) / (rn - 2) / (rn - 3) -
						3 * Math.Pow((rn - 1), 2) / (rn - 2) / (rn - 3);
		return (SqlDouble)myKurt;
	}

}
*/
-- C# code skewness and kurtosis 

-- Deploying CLR UDAs for skewness and kurtosis
-- Enable CLR
EXEC sp_configure 'clr enabled', 1;
RECONFIGURE WITH OVERRIDE;

-- Load CS Assembly - change the path if needed
CREATE ASSEMBLY DescriptiveStatistics 
FROM 'C:\SQL2016DevGuide\DescriptiveStatistics.dll'
WITH PERMISSION_SET = SAFE;

-- Skewness UDA
CREATE AGGREGATE dbo.Skew(@s float)
RETURNS float
EXTERNAL NAME DescriptiveStatistics.Skew;

-- Kurtosis UDA
CREATE AGGREGATE dbo.Kurt(@s float)
RETURNS float
EXTERNAL NAME DescriptiveStatistics.Kurt;
GO

-- Using the UDAs
-- Calculating average, standard deviation,
-- skewness and kurtosis
-- for customers' orders
WITH CustomerSalesCTE AS
(
SELECT c.Customer, 
  SUM(f.[Total Excluding Tax]) AS TotalAmount
FROM Fact.Sale AS f
  INNER JOIN Dimension.Customer AS c
    ON f.[Customer Key] = c.[Customer Key]
WHERE c.[Customer Key] <> 0 
GROUP BY c.Customer
)
SELECT ROUND(AVG(TotalAmount), 2) AS Average,
  ROUND(STDEV(TotalAmount), 2) AS StandardDeviation, 
  ROUND(dbo.Skew(TotalAmount), 6) AS Skewness,
  ROUND(dbo.Kurt(TotalAmount), 6) AS Kurtosis
FROM CustomerSalesCTE;
GO

-- Clean up
DROP AGGREGATE dbo.Skew;
DROP AGGREGATE dbo.Kurt;
DROP ASSEMBLY DescriptiveStatistics;
/*
EXEC sp_configure 'clr enabled', 0;
RECONFIGURE WITH OVERRIDE;
*/

-- XML support in SQL Server

-- Generating XML
-- FOR XML with AUTO option, element-centric, with namespace and XMLSCHEMA
SELECT c.[Customer Key] AS CustomerKey,
  c.[WWI Customer ID] AS CustomerId,
  c.[Customer], 
  c.[Buying Group] AS BuyingGroup,
  f.Quantity,
  f.[Total Excluding Tax] AS Amount,
  f.Profit
FROM Dimension.Customer AS c
  INNER JOIN Fact.Sale AS f
    ON c.[Customer Key] = f.[Customer Key]
WHERE c.[Customer Key] IN (127, 128)
FOR XML AUTO, ELEMENTS, 
  ROOT('CustomersOrders'),
  XMLSCHEMA('CustomersOrdersSchema');
GO

-- Using XQuery
-- FLWOR Expressions
DECLARE @x AS XML;
SET @x = N'
<CustomersOrders>
  <Customer custid="1">
    <!-- Comment 111 -->
    <companyname>CustA</companyname>
    <Order orderid="1">
      <orderdate>2016-07-01T00:00:00</orderdate>
    </Order>
    <Order orderid="9">
      <orderdate>2016-07-03T00:00:00</orderdate>
    </Order>
    <Order orderid="12">
      <orderdate>2016-07-12T00:00:00</orderdate>
    </Order>
  </Customer>
  <Customer custid="2">
    <!-- Comment 222 -->  
    <companyname>CustB</companyname>
    <Order orderid="3">
      <orderdate>2016-07-01T00:00:00</orderdate>
    </Order>
    <Order orderid="10">
      <orderdate>2016-07-05T00:00:00</orderdate>
    </Order>
  </Customer>
</CustomersOrders>';
SELECT @x.query('for $i in CustomersOrders/Customer/Order
                 let $j := $i/orderdate
                 where $i/@orderid < 10900
                 order by ($j)[1]
                 return 
                 <Order-orderid-element>
                  <orderid>{data($i/@orderid)}</orderid>
                  {$j}
                 </Order-orderid-element>')
       AS [Filtered, sorted and reformatted orders with let clause];
GO


--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide				--------
---- Chapter 02 - Review of SQL Server Features for Developers -----
--------------------------------------------------------------------
