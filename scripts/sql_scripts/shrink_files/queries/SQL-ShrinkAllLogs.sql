USE [master];

DECLARE @LineTerm CHAR(2) = CHAR(13) + CHAR(10);
DECLARE @SQuote CHAR(1) = CHAR(39);

SELECT
ServerName = @@SERVERNAME
,DatabaseName = DB_NAME(database_id)
,LogicalName = name
,PhysicalName = physical_name
,FileSizeKB = (sys.master_files.size * 8)
,ShrinkCommand = 'USE [' + DB_NAME(database_id) + '] ;' + @LineTerm +
				 'DBCC SHRINKFILE(N' + @SQuote + name + @SQuote + ' , 0);'
FROM sys.master_files
WHERE type_desc = 'LOG'
;