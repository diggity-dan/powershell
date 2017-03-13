USE [master];

SELECT
ServerName = @@SERVERNAME 
,DatabaseName = sys.databases.name
,RecoveryModel = sys.databases.recovery_model_desc
,RecoveryCommand = 'ALTER DATABASE ' + sys.databases.name + ' SET RECOVERY SIMPLE;'
FROM sys.databases  
WHERE recovery_model_desc <> 'SIMPLE' 
AND name NOT IN (
'master'
,'model'
,'msdb'
,'tempdb'
);