USE [master];

DECLARE @LineTerm CHAR(2) = CHAR(13) + CHAR(10);
DECLARE @SQuote CHAR(1) = CHAR(39);

SELECT DISTINCT
ServerName = @@SERVERNAME
,DatabaseName = sys.databases.name
,LogicalName = sys.master_files.name
,PhysicalName = physical_name
,FileSizeKB = (sys.master_files.size * 8) 
,ShrinkCommand = 'USE [' + DB_NAME(sys.master_files.database_id) + '] ;' + @LineTerm +
				 'DBCC SHRINKFILE(N' + @SQuote + sys.master_files.name + @SQuote + ' , 0);'
FROM sys.master_files
JOIN sys.databases
	ON sys.master_files.database_id = sys.databases.database_id
WHERE sys.master_files.type_desc = 'ROWS'
AND sys.master_files.name LIKE '%index%'
AND sys.databases.name NOT IN ('master', 'tempdb', 'model', 'msdb')
;