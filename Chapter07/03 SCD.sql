--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide
--------	  Chapter 07 - Temporal Tables
--------        Dimension Data Extraction
--------------------------------------------------------------------


---------------------------------------------------------------
-- Multiple rows for a single entity in a single day
---------------------------------------------------------------

USE WideWorldImporters;
SELECT PersonID, FullName,
 ValidFrom, ValidTo
FROM Application.People
 FOR SYSTEM_TIME ALL
WHERE IsEmployee = 1
  AND PersonID = 14;

---------------------------------------------------------------
-- Find the last row for an entity for each day
---------------------------------------------------------------
WITH PersonCTE AS
(
SELECT PersonID, FullName,
 CAST(ValidFrom AS DATE) AS ValidFrom,
 CAST(ValidTo AS DATE) AS ValidTo,
 ROW_NUMBER() OVER(PARTITION BY PersonID, CAST(ValidFrom AS Date)
                 ORDER BY ValidFrom DESC) AS rn
FROM Application.People
 FOR SYSTEM_TIME ALL
WHERE IsEmployee = 1
)
SELECT PersonID, FullName,
 ValidFrom, ValidTo
FROM PersonCTE
WHERE rn = 1;
GO


