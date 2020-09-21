DECLARE
   @MinimumTableRows INT = 200000
 , @MinimumModCountr INT = 100000
 , @MinimumDaysOld INT = 35

SET NOCOUNT, ARITHABORT, XACT_ABORT ON;
IF OBJECT_ID('tempdb..#tmpStats') IS NOT NULL DROP TABLE #tmpStats;
CREATE TABLE #tmpStats(
 DBname SYSNAME,
 DatabaseId INT,
 ObjectId INT,
 StatsName SYSNAME,
 LastUpdate DATETIME,
 ModCntr BIGINT,
 TotalRows BIGINT
);

DECLARE @qry NVARCHAR(MAX);
SET @qry = CONCAT(N'IF DATABASEPROPERTYEX(''?'', ''Updateability'') = ''READ_WRITE'' 
 AND DATABASEPROPERTYEX(''?'', ''Status'') = ''ONLINE''
 AND DB_ID(''?'') > 4
 AND ''?'' NOT IN(''master'', ''model'', ''msdb'', ''tempdb'', ''ReportServerTempDB'', ''distribution'', ''SSISDB'')
BEGIN
 USE [?];
 SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

 INSERT #tmpStats
 SELECT
  DB_NAME(),
  DB_ID(),
  stat.object_id,
  stat.name,
  MIN(sp.last_updated),
  MAX(sp.modification_counter),
  SUM(sp.rows)
 FROM sys.tables AS t
  INNER JOIN (
   SELECT SUM(ps.rows) AS rows, ps.object_id
   FROM sys.partitions ps 
   WHERE ps.index_id <= 1 
   GROUP BY ps.object_id
   HAVING SUM(ps.rows) >= ', @MinimumTableRows, N'
   ) AS ps
   ON t.object_id = ps.object_id 
  INNER JOIN sys.stats AS stat ON t.object_id = stat.object_id
  CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
 WHERE sp.modification_counter >= ', @MinimumModCountr, N'
  AND sp.last_updated < DATEADD(day, -', @MinimumDaysOld, N', GETDATE())
 GROUP BY stat.object_id,stat.name
END')

EXEC sp_MSforeachdb @qry;

SELECT
  [database_name] = DB_NAME(databaseId)
, [schema_name] = OBJECT_SCHEMA_NAME(objectId, databaseId)
, [table_name] = OBJECT_NAME(objectId, databaseId)
, statsName
, ModCntr
, LastUpdate
, RemediationCmd = CONCAT('UPDATE STATISTICS ' , QUOTENAME(DB_NAME(databaseId))
	, '.', QUOTENAME(OBJECT_SCHEMA_NAME(objectId, databaseId))
	, '.', QUOTENAME(OBJECT_NAME(objectId, databaseId))
	, ' ', QUOTENAME(statsName))
FROM #tmpStats
ORDER BY
	ModCntr DESC,
	LastUpdate ASC