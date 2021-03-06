/*
Read contents of a SQLDump file's txt file
=============================================
Author: Eitan Blumin | https://www.madeiradata.com
Date: 2020-12-08
*/
SET NOCOUNT, ARITHABORT, XACT_ABORT ON;
DECLARE @FilePath NVARCHAR(4000), @CMD NVARCHAR(MAX)

-- Use below to read the contents of latest memory dump file (mdmp) generated by the current instance:
SET @FilePath = (SELECT TOP 1 REPLACE([filename], N'.mdmp', N'.txt') FROM sys.dm_server_memory_dumps ORDER BY creation_time DESC)

-- Use below to read the contents of an explicitely specified txt file:
--SET @FilePath = N'C:\temp\SQLDump0001.txt'

IF OBJECT_ID('tempdb..#Bulk') IS NOT NULL DROP TABLE #Bulk;
CREATE TABLE #Bulk(Content NVARCHAR(MAX));

SET @CMD = N'
BULK INSERT #Bulk
FROM ' + QUOTENAME(@FilePath, N'''')

EXEC(@CMD);

ALTER TABLE #Bulk ADD ID INT IDENTITY(1,1);
DECLARE @FromID INT, @ToID INT;

SELECT @FromID = MIN(ID), @ToID = MAX(ID)
FROM (
SELECT TOP 2 ID
FROM #Bulk
WHERE Content LIKE '* **************%'
OR Content LIKE '*%MODULE%BASE%END%SIZE%'
ORDER BY ID ASC
) AS q

SELECT Content = N'Source: ' + @FilePath
UNION ALL
SELECT Content
FROM #Bulk
WHERE Content LIKE '* %'
AND LTRIM(Content) <> '*'
AND ID > @FromID
AND ID < @ToID
