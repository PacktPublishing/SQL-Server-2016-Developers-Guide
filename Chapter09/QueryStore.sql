--------------------------------------------------------------------
--------	SQL Server 2016 Developer’s Guide
--------	Chapter 09 - Query Store
--------------------------------------------------------------------

----------------------------------------------------
-- Getting troubeshooting data form server cache
----------------------------------------------------

USE WideWorldImporters;
--create some workload
EXEC Website.SearchForPeople @SearchText = N'Peter', @MaximumRowsToReturn = 20;
GO 10

--Getting exec plan for a given stored procedure
SELECT 
	c.usecounts, c.cacheobjtype, c.objtype, q.text AS query_text, p.query_plan
FROM 
	sys.dm_exec_cached_plans c
	CROSS APPLY sys.dm_exec_sql_text(c.plan_handle) q
	CROSS APPLY sys.dm_exec_query_plan(c.plan_handle) p
WHERE
	c.objtype = 'Proc' AND q.text LIKE '%SearchForPeople%';


/*Result:
usecounts   cacheobjtype    objtype    query_text                                       query_plan                                                                                                                                                                                                                
----------- -------------   ---------- --------------------------- -------------------- -----------------------------------
14	Compiled Plan			Proc	   CREATE PROCEDURE Website.SearchForPeople.... <ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.5" Build="13.0.4001.0"><BatchSequence><Batch><Statements><StmtSimple StatementText="&#xD;&#xA;CREATE PROCEDURE Website.SearchForPeople&#xD;&#xA;@SearchText nvarchar(100
*/

--Getting exec statistics for a given stored procedure
SELECT 
p.name,
s.execution_count,
ISNULL(s.execution_count*60/(DATEDIFF(second, s.cached_time, GETDATE())), 0) AS calls_per_minute,
(s.total_elapsed_time/(1000*s.execution_count)) AS avg_elapsed_time_ms,
s.total_logical_reads/s.execution_count AS avg_logical_reads,
s.last_execution_time,
s.last_elapsed_time/1000 AS last_elapsed_time_ms,
s.last_logical_reads
FROM sys.procedures p
INNER JOIN sys.dm_exec_procedure_stats AS s ON p.object_id = s.object_id AND s.database_id = DB_ID()
WHERE p.name LIKE '%SearchForPeople%';

/*Result:
name               execution_count      calls_per_minute     avg_elapsed_time_ms  avg_logical_reads    last_execution_time     last_elapsed_time_ms last_logical_reads
------------------ -------------------- -------------------- -------------------- -------------------- ----------------------- -------------------- --------------------
SearchForPeople    14                   2                    8                    91                   2017-02-22 11:14:43.677 6                    92

*/


----------------------------------------------------
-- Enable and configure Query Store
----------------------------------------------------
ALTER DATABASE WideWorldImporters
SET QUERY_STORE = ON;
--This is equivalent to
ALTER DATABASE WideWorldImporters
SET QUERY_STORE = ON   
(
	OPERATION_MODE = READ_WRITE,   
	MAX_STORAGE_SIZE_MB = 100,
	DATA_FLUSH_INTERVAL_SECONDS = 900,
	INTERVAL_LENGTH_MINUTES = 60,
	CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 367),
	QUERY_CAPTURE_MODE = ALL,
	SIZE_BASED_CLEANUP_MODE = OFF,
	MAX_PLANS_PER_QUERY = 200
);  

--check Query Store configuration
SELECT * FROM sys.database_query_store_options;

/*Result:
desired_state desired_state_desc                                           actual_state actual_state_desc                                            readonly_reason current_storage_size_mb flush_interval_seconds interval_length_minutes max_storage_size_mb  stale_query_threshold_days max_plans_per_query  query_capture_mode query_capture_mode_desc                                      size_based_cleanup_mode size_based_cleanup_mode_desc                                 actual_state_additional_info
------------- ------------------------------------------------------------ ------------ ------------------------------------------------------------ --------------- ----------------------- ---------------------- ----------------------- -------------------- -------------------------- -------------------- ------------------ ------------------------------------------------------------ ----------------------- ------------------------------------------------------------ ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
2             READ_WRITE                                                   2            READ_WRITE                                                   0               11                      3000                   15                      500                  30                         1000                 2                  AUTO                                                         1                       AUTO                                                         
*/

--clearing Query Store
ALTER DATABASE WideWorldImporters SET QUERY_STORE CLEAR; 
--disabling Query Store
ALTER DATABASE WideWorldImporters SET QUERY_STORE = OFF; 


---------------------------------------
--- Query Store Demo
---------------------------------------
--create new database Mila
IF DB_ID('Mila') IS NULL CREATE DATABASE Mila;
GO 
USE Mila;
GO
--help function GetNums created by Itzik Ben-Gan (http://tsql.solidq.com)
CREATE OR ALTER FUNCTION dbo.GetNums(@n AS BIGINT) RETURNS TABLE
AS
RETURN
  WITH
  L0   AS(SELECT 1 AS c UNION ALL SELECT 1),
  L1   AS(SELECT 1 AS c FROM L0 AS A CROSS JOIN L0 AS B),
  L2   AS(SELECT 1 AS c FROM L1 AS A CROSS JOIN L1 AS B),
  L3   AS(SELECT 1 AS c FROM L2 AS A CROSS JOIN L2 AS B),
  L4   AS(SELECT 1 AS c FROM L3 AS A CROSS JOIN L3 AS B),
  L5   AS(SELECT 1 AS c FROM L4 AS A CROSS JOIN L4 AS B),
  Nums AS(SELECT ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS n FROM L5)
  SELECT n FROM Nums WHERE n <= @n;
GO
 
--Create sample table
DROP TABLE IF EXISTS dbo.Orders;
CREATE TABLE dbo.Orders(
id INT IDENTITY(1,1) NOT NULL,
custid INT NOT NULL,
details NVARCHAR(200) NOT NULL,
status TINYINT NOT NULL DEFAULT (1) INDEX ix1 NONCLUSTERED,
CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (id ASC)
);
GO
 
-- Populate the table with 2M rows
INSERT INTO dbo.Orders (custid, details)
SELECT 1 + ABS(CHECKSUM(NEWID())) % 1111100 AS custid, REPLICATE(N'X', 200) AS details
FROM dbo.GetNums(2000000);
GO
--simulate SQL Server 2012 by setting comp level to 110
ALTER DATABASE Mila SET COMPATIBILITY_LEVEL = 110;

--ALTER DATABASE Mila SET QUERY_STORE CLEAR;
--ALTER DATABASE Mila SET QUERY_STORE = OFF 
--enable Query Store
ALTER DATABASE Mila 
SET QUERY_STORE = ON   
(  
    OPERATION_MODE = READ_WRITE,   
    INTERVAL_LENGTH_MINUTES = 1   
);  

--check Query Store configuration
SELECT * FROM sys.database_query_store_options;
/*Result:
desired_state desired_state_desc                                           actual_state actual_state_desc                                            readonly_reason current_storage_size_mb flush_interval_seconds interval_length_minutes max_storage_size_mb  stale_query_threshold_days max_plans_per_query  query_capture_mode query_capture_mode_desc                                      size_based_cleanup_mode size_based_cleanup_mode_desc                                 actual_state_additional_info
------------- ------------------------------------------------------------ ------------ ------------------------------------------------------------ --------------- ----------------------- ---------------------- ----------------------- -------------------- -------------------------- -------------------- ------------------ ------------------------------------------------------------ ----------------------- ------------------------------------------------------------ ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
2             READ_WRITE                                                   2            READ_WRITE                                                   0               0                       900                    1                       100                  367                        200                  1                  ALL                                                          1                       AUTO                                                         
*/

--execute sample query
USE Mila;
SET NOCOUNT ON;
SELECT * FROM dbo.Orders WHERE Status IN (0, 2);
GO 100

 --check query store (your results might be different)
SELECT * FROM sys.query_store_query;
/*Result:
query_id             query_text_id        context_settings_id  object_id            batch_sql_handle                                                                           query_hash         is_internal_query query_parameterization_type query_parameterization_type_desc                             initial_compile_start_time         last_compile_start_time            last_execution_time                last_compile_batch_sql_handle                                                              last_compile_batch_offset_start last_compile_batch_offset_end count_compiles       avg_compile_duration   last_compile_duration avg_bind_duration      last_bind_duration   avg_bind_cpu_time      last_bind_cpu_time   avg_optimize_duration  last_optimize_duration avg_optimize_cpu_time  last_optimize_cpu_time avg_compile_memory_kb  last_compile_memory_kb max_compile_memory_kb is_clouddb_internal_query
-------------------- -------------------- -------------------- -------------------- ------------------------------------------------------------------------------------------ ------------------ ----------------- --------------------------- ------------------------------------------------------------ ---------------------------------- ---------------------------------- ---------------------------------- ------------------------------------------------------------------------------------------ ------------------------------- ----------------------------- -------------------- ---------------------- --------------------- ---------------------- -------------------- ---------------------- -------------------- ---------------------- ---------------------- ---------------------- ---------------------- ---------------------- ---------------------- --------------------- -------------------------
1                    1                    1                    0                    NULL                                                                                       0x3400C010AC4BA0F0 0                 0                           None                                                         2017-01-17 09:46:51.0270000 +00:00 2017-01-17 09:46:51.0630000 +00:00 2017-01-17 09:46:58.4300000 +00:00 0x020000003AAE22123851AC9E22615D14ADB4A66E550698540000000000000000000000000000000000000000 0                               86                            2                    2644                   796                   1642                   120                  742                    120                  1002                   676                    1002                   676                    184                    184                    184                   0
*/

--get captured execution plans (your results might be different)
SELECT * FROM sys.query_store_plan;
/*Result:
plan_id              query_id             plan_group_id        engine_version                   compatibility_level query_plan_hash    query_plan                                                                                                                                                                                                                                                       is_online_index_plan is_trivial_plan is_parallel_plan is_forced_plan is_natively_compiled force_failure_count  last_force_failure_reason last_force_failure_reason_desc                                                                                                   count_compiles       initial_compile_start_time         last_compile_start_time            last_execution_time                avg_compile_duration   last_compile_duration
-------------------- -------------------- -------------------- -------------------------------- ------------------- ------------------ ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- -------------------- --------------- ---------------- -------------- -------------------- -------------------- ------------------------- -------------------------------------------------------------------------------------------------------------------------------- -------------------- ---------------------------------- ---------------------------------- ---------------------------------- ---------------------- ---------------------
1                    1                    0                    13.0.4001.0                      110                 0x78B2879E098D0C3D <ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.5" Build="13.0.4001.0"><BatchSequence><Batch><Statements><StmtSimple StatementText="SELECT * FROM sys.database_query_store_options" StatementId="1" StatementCompId="1"  0                    0               0                0              0                    0                    0                         NONE                                                                                                                             1                    2017-01-17 10:05:53.4430000 +00:00 2017-01-17 10:05:53.4430000 +00:00 2017-01-17 10:05:53.4570000 +00:00 9592                   9592
2                    2                    0                    13.0.4001.0                      110                 0x9876FE61E67B3F52 <ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.5" Build="13.0.4001.0"><BatchSequence><Batch><Statements><StmtSimple StatementText="SELECT * FROM dbo.Orders WHERE Status IN (0, 2)" StatementId="1" StatementCompId="2" St 0                    0               0                0              0                    0                    0                         NONE                                                                                                                             2                    2017-01-17 10:05:58.3970000 +00:00 2017-01-17 10:05:58.4170000 +00:00 2017-01-17 10:05:58.4000000 +00:00 729,5                  1459
3                    3                    0                    13.0.4001.0                      110                 0x6FA179640875F159 <ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.5" Build="13.0.4001.0"><BatchSequence><Batch><Statements><StmtSimple StatementText="SELECT * FROM sys.query_store_query" StatementId="1" StatementCompId="1" StatementTy 0                    0               0                0              0                    0                    0                         NONE                                                                                                                             2                    2017-01-17 10:06:01.9030000 +00:00 2017-01-17 10:06:05.3000000 +00:00 2017-01-17 10:06:05.3100000 +00:00 6881                   13762
*/

--get queries and plans with text (your results might be different)
SELECT qs.query_id, q.query_sql_text, p.query_plan
FROM sys.query_store_query AS qs
INNER JOIN sys.query_store_plan AS p ON p.query_id = qs.query_id
INNER JOIN sys.query_store_query_text AS q ON qs.query_text_id = q.query_text_id;
/*Result:
query_id             query_sql_text                                                                                                                                                                                                                                                   query_plan
-------------------- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
1                    SELECT * FROM sys.database_query_store_options                                                                                                                                                                                                                   <ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.5" Build="13.0.4001.0"><BatchSequence><Batch><Statements><StmtSimple StatementText="SELECT * FROM sys.database_query_store_options" StatementId="1" StatementCompId="1" 
2                    SELECT * FROM dbo.Orders WHERE Status IN (0, 2)                                                                                                                                                                                                                     <ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.5" Build="13.0.4001.0"><BatchSequence><Batch><Statements><StmtSimple StatementText="SELECT * FROM dbo.Orders WHERE Status IN (0, 2)" StatementId="1" StatementCompId="2" St
3                    SELECT * FROM sys.query_store_query                                                                                                                                                                                                                              <ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.5" Build="13.0.4001.0"><BatchSequence><Batch><Statements><StmtSimple StatementText="SELECT * FROM sys.query_store_query" StatementId="1" StatementCompId="1" StatementTy
4                    SELECT * FROM sys.query_store_plan                                                                                                                                                                                                                               <ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.5" Build="13.0.4001.0"><BatchSequence><Batch><Statements><StmtSimple StatementText="SELECT * FROM sys.query_store_plan" StatementId="1" StatementCompId="1" StatementTyp
*/

--Identify queries with multiple execution plans
SELECT query_id, COUNT(*) AS cnt 
FROM sys.query_store_plan p
GROUP BY query_id 
HAVING COUNT(*) > 1 ORDER BY cnt DESC;
/*Result:
no rows, but very useful - you can identify all queries that are executed with more than one execution plan. 
*/

--get runtime stats
SELECT * FROM sys.query_store_runtime_stats;
/*Result:
runtime_stats_id     plan_id              runtime_stats_interval_id execution_type execution_type_desc                                          first_execution_time               last_execution_time                count_executions     avg_duration           last_duration        min_duration         max_duration         stdev_duration         avg_cpu_time           last_cpu_time        min_cpu_time         max_cpu_time         stdev_cpu_time         avg_logical_io_reads   last_logical_io_reads min_logical_io_reads max_logical_io_reads stdev_logical_io_reads avg_logical_io_writes  last_logical_io_writes min_logical_io_writes max_logical_io_writes stdev_logical_io_writes avg_physical_io_reads  last_physical_io_reads min_physical_io_reads max_physical_io_reads stdev_physical_io_reads avg_clr_time           last_clr_time        min_clr_time         max_clr_time         stdev_clr_time         avg_dop                last_dop             min_dop              max_dop              stdev_dop              avg_query_max_used_memory last_query_max_used_memory min_query_max_used_memory max_query_max_used_memory stdev_query_max_used_memory avg_rowcount           last_rowcount        min_rowcount         max_rowcount         stdev_rowcount
-------------------- -------------------- ------------------------- -------------- ------------------------------------------------------------ ---------------------------------- ---------------------------------- -------------------- ---------------------- -------------------- -------------------- -------------------- ---------------------- ---------------------- -------------------- -------------------- -------------------- ---------------------- ---------------------- --------------------- -------------------- -------------------- ---------------------- ---------------------- ---------------------- --------------------- --------------------- ----------------------- ---------------------- ---------------------- --------------------- --------------------- ----------------------- ---------------------- -------------------- -------------------- -------------------- ---------------------- ---------------------- -------------------- -------------------- -------------------- ---------------------- ------------------------- -------------------------- ------------------------- ------------------------- --------------------------- ---------------------- -------------------- -------------------- -------------------- ----------------------
6                    6                    2                         0              Regular                                                      2017-01-17 10:06:48.6700000 +00:00 2017-01-17 10:06:48.6700000 +00:00 1                    381                    381                  381                  381                  0                      381                    381                  381                  381                  0                      2                      2                     2                    2                    0                      0                      0                      0                     0                     0                       0                      0                      0                     0                     0                       0                      0                    0                    0                    0                      1                      1                    1                    1                    0                      128                       128                        128                       128                       0                           0                      0                    0                    0                    0
5                    5                    2                         0              Regular                                                      2017-01-17 10:06:28.5930000 +00:00 2017-01-17 10:06:28.5930000 +00:00 1                    5489                   5489                 5489                 5489                 0                      5370                   5370                 5370                 5370                 0                      58                     58                    58                   58                   0                      0                      0                      0                     0                     0                       0                      0                      0                     0                     0                       0                      0                    0                    0                    0                      1                      1                    1                    1                    0                      204                       204                        204                       204                       0                           4                      4                    4                    4                    0
4                    4                    2                         0              Regular                                                      2017-01-17 10:06:15.7030000 +00:00 2017-01-17 10:06:15.7030000 +00:00 1                    3595                   3595                 3595                 3595                 0                      3594                   3594                 3594                 3594                 0                      28                     28                    28                   28                   0                      0                      0                      0                     0                     0                       0                      0                      0                     0                     0                       0                      0                    0                    0                    0                      1                      1                    1                    1                    0                      0                         0                          0                         0                         0                           3                      3                    3                    3                    0
3                    3                    2                         0              Regular                                                      2017-01-17 10:06:01.9200000 +00:00 2017-01-17 10:06:05.3100000 +00:00 2                    1126,5                 1149                 1104                 1149                 22,5                   1126                   1149                 1103                 1149                 23                     4                      4                     4                    4                    0                      0                      0                      0                     0                     0                       0                      0                      0                     0                     0                       0                      0                    0                    0                    0                      1                      1                    1                    1                    0                      134                       134                        134                       134                       0                           3                      3                    3                    3                    0
2                    2                    1                         0              Regular                                                      2017-01-17 10:05:58.4000000 +00:00 2017-01-17 10:05:58.8600000 +00:00 10                   46,6                   43                   31                   127                  28,9247299036655       46,4                   43                   30                   126                  28,7026131214564       6                      6                     6                    6                    0                      0                      0                      0                     0                     0                       0                      0                      0                     0                     0                       0                      0                    0                    0                    0                      1                      1                    1                    1                    0                      0                         0                          0                         0                         0                           0                      0                    0                    0                    0
1                    1                    1                         0              Regular                                                      2017-01-17 10:05:53.4570000 +00:00 2017-01-17 10:05:53.4570000 +00:00 1                    2130                   2130                 2130                 2130                 0                      2130                   2130                 2130                 2130                 0                      8                      8                     8                    8                    0                      0                      0                      0                     0                     0                       0                      0                      0                     0                     0                       0                      0                    0                    0                    0                      1                      1                    1                    1                    0                      544                       544                        544                       544                       0                           1                      1                    1                    1                    0
*/


--execute sample query again
USE Mila;
SELECT * FROM dbo.Orders WHERE Status IN (0, 2);
GO 100

--get runtime stats for the plan with ID 1
SELECT * FROM sys.query_store_runtime_stats WHERE plan_id = 2;
/*Result:
runtime_stats_id     plan_id              runtime_stats_interval_id execution_type execution_type_desc       first_execution_time               last_execution_time                count_executions     avg_duration           last_duration        min_duration         max_duration         stdev_duration         avg_cpu_time           last_cpu_time        min_cpu_time         max_cpu_time         stdev_cpu_time         avg_logical_io_reads   last_logical_io_reads min_logical_io_reads max_logical_io_reads stdev_logical_io_reads avg_logical_io_writes  last_logical_io_writes min_logical_io_writes max_logical_io_writes stdev_logical_io_writes avg_physical_io_reads  last_physical_io_reads min_physical_io_reads max_physical_io_reads stdev_physical_io_reads avg_clr_time           last_clr_time        min_clr_time         max_clr_time         stdev_clr_time         avg_dop                last_dop             min_dop              max_dop              stdev_dop              avg_query_max_used_memory last_query_max_used_memory min_query_max_used_memory max_query_max_used_memory stdev_query_max_used_memory avg_rowcount           last_rowcount        min_rowcount         max_rowcount         stdev_rowcount
-------------------- -------------------- ------------------------- -------------- ------------------------- ---------------------------------- ---------------------------------- -------------------- ---------------------- -------------------- -------------------- -------------------- ---------------------- ---------------------- -------------------- -------------------- -------------------- ---------------------- ---------------------- --------------------- -------------------- -------------------- ---------------------- ---------------------- ---------------------- --------------------- --------------------- ----------------------- ---------------------- ---------------------- --------------------- --------------------- ----------------------- ---------------------- -------------------- -------------------- -------------------- ---------------------- ---------------------- -------------------- -------------------- -------------------- ---------------------- ------------------------- -------------------------- ------------------------- ------------------------- --------------------------- ---------------------- -------------------- -------------------- -------------------- ----------------------
8                    2                    3                         0              Regular                   2017-01-17 10:07:06.4130000 +00:00 2017-01-17 10:07:06.7600000 +00:00 10                   39,6                   31                   30                   119                  26,4696052105051       39,4                   31                   30                   118                  26,20381651592         6                      6                     6                    6                    0                      0                      0                      0                     0                     0                       0                      0                      0                     0                     0                       0                      0                    0                    0                    0                      1                      1                    1                    1                    0                      0                         0                          0                         0                         0                           0                      0                    0                    0                    0
2                    2                    1                         0              Regular                   2017-01-17 10:05:58.4000000 +00:00 2017-01-17 10:05:58.8600000 +00:00 10                   46,6                   43                   31                   127                  28,9247299036655       46,4                   43                   30                   126                  28,7026131214564       6                      6                     6                    6                    0                      0                      0                      0                     0                     0                       0                      0                      0                     0                     0                       0                      0                    0                    0                    0                      1                      1                    1                    1                    0                      0                         0                          0                         0                         0                           0                      0                    0                    0                    0

you can see two entries in this store
*/

--Migration simulation (set comp level to 130)
ALTER DATABASE Mila SET COMPATIBILITY_LEVEL = 130;

--execute execute sample query again
USE Mila;
SELECT * FROM dbo.Orders WHERE status IN (0, 2);
GO 100
--execution is slow and plan is Clustered Index Scan


--check the plans (you will find two plans for the same query => a new plan is generated under the comp level 130)
SELECT * FROM sys.query_store_plan WHERE query_id = 2;
/*Result:
plan_id              query_id             plan_group_id        engine_version                   compatibility_level query_plan_hash    query_plan                                                                                                                                                                                                                                                       is_online_index_plan is_trivial_plan is_parallel_plan is_forced_plan is_natively_compiled force_failure_count  last_force_failure_reason last_force_failure_reason_desc                                                                                                   count_compiles       initial_compile_start_time         last_compile_start_time            last_execution_time                avg_compile_duration   last_compile_duration
-------------------- -------------------- -------------------- -------------------------------- ------------------- ------------------ ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- -------------------- --------------- ---------------- -------------- -------------------- -------------------- ------------------------- -------------------------------------------------------------------------------------------------------------------------------- -------------------- ---------------------------------- ---------------------------------- ---------------------------------- ---------------------- ---------------------
2                    2                    0                    13.0.4001.0                      110                 0x9876FE61E67B3F52 <ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.5" Build="13.0.4001.0"><BatchSequence><Batch><Statements><StmtSimple StatementText="SELECT * FROM dbo.Orders WHERE Status IN (0, 2)" StatementId="1" StatementCompId="2" St 0                    0               0                0              0                    0                    0                         NONE                                                                                                                             2                    2017-01-17 10:05:58.3970000 +00:00 2017-01-17 10:05:58.4170000 +00:00 2017-01-17 10:07:06.4130000 +00:00 729,5                  1459
10                   2                    0                    13.0.4001.0                      130                 0x019EE823702337E8 <ShowPlanXML xmlns="http://schemas.microsoft.com/sqlserver/2004/07/showplan" Version="1.5" Build="13.0.4001.0"><BatchSequence><Batch><Statements><StmtSimple StatementText="SELECT * FROM dbo.Orders WHERE Status IN (0, 2)" StatementId="1" StatementCompId="2" St 0                    0               0                0              0                    0                    0                         NONE                                                                                                                             2                    2017-01-17 10:07:25.6930000 +00:00 2017-01-17 10:07:26.0770000 +00:00 2017-01-17 10:07:29.8200000 +00:00 900,5                  1801
*/

--force the old plan
EXEC sp_query_store_force_plan @query_id = 2, @plan_id = 2;


--execute query and check the plan
USE Mila;
SELECT * FROM dbo.Orders WHERE Status IN (0, 2);
--execution is fast and plan is Index Seek + Key Lookup

--unforce the plan
EXEC sp_query_store_unforce_plan @query_id = 2, @plan_id = 2;
 
--execute query and check the plan
USE Mila;
SELECT * FROM dbo.Orders WHERE Status IN (0, 2);
--execution is again slow and plan is Clustered Index Scan


--Indetify ad-hoc queries
SELECT p.query_id
FROM sys.query_store_plan p
INNER JOIN sys.query_store_runtime_stats s ON p.plan_id = s.plan_id
GROUP BY p.query_id
HAVING SUM(s.count_executions) = 1;
/*Result:
 query_id
--------------------
9
6
7
1
10
4
5
8
*/

--cleanup
USE master;
DROP DATABASE IF EXISTS Mila;
GO