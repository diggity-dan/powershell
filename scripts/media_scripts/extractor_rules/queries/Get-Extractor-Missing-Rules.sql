
USE NexidiaExtractor;

SELECT
ExtractTables.DirectoryPath
,ExtractTables.Extension
,ExtensionCount = COUNT(*)
FROM (
	SELECT
	TableLocation = 'ExtractManifest'
	,FullFilePath
	,Extension
	,RepositoryDateTime
	,DirectoryPath
	FROM ExtractManifest WITH (NOLOCK)

	UNION ALL

	SELECT
	TableLocation = 'ExtractManifestArchive'
	,FullFilePath
	,Extension
	,RepositoryDateTime
	,DirectoryPath
	FROM ExtractManifestArchive WITH (NOLOCK)
	
) AS ExtractTables

LEFT JOIN ExtractRules WITH (NOLOCK)
	ON LEN(ExtractRules.SourceFileName) <> LEN( REPLACE(ExtractRules.SourceFileName, ExtractTables.Extension, '') )
	AND ExtractTables.DirectoryPath LIKE REPLACE(ExtractRules.SourceDirectory, '*', '%' )
	AND ExtractRules.[Rule] = 'DELETE'
WHERE ExtractRules.SourceFilename IS NULL
GROUP BY ExtractTables.DirectoryPath, ExtractTables.Extension
ORDER BY ExtensionCount DESC, ExtractTables.DirectoryPath
;