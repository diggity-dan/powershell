
USE NexidiaExtractor;

DECLARE @MediaRoot NVARCHAR(1024) = '{{MEDIAROOT}}'

--Increase Threshold value to account for late processing/late deletes:
DECLARE @ThresholdBump INT = 2;

--Find if the ExtractDeleteProtected table exists:
DECLARE @ExtractDeleteTable BIT = 0;

IF (EXISTS(SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ExtractDeleteProtected'))
BEGIN
	SET @ExtractDeleteTable = 1;
END
;

IF (@ExtractDeleteTable = 1)
BEGIN

	SELECT DISTINCT
	RepositoryDateTime = CAST(ExtractTables.RepositoryDateTime AS DATE)
	,CutOffDate = CAST(GETDATE() - (CAST(ExtractRules.Threshold AS INT) + @ThresholdBump ) AS DATE)
	,ExtractRules.Threshold
	,ExtractTables.TableLocation
	,ExtractTables.FullFilePath
	,ReasonForKeeping = CASE
							WHEN ExtractDeleteProtected.Externalmediaid IS NOT NULL THEN 'Extractor - ExtractDeleteProtected'
							WHEN ExtractFileAction.action IS NOT NULL THEN 'Extractor - ExtractFileAction ' + ExtractFileAction.action
							ELSE 'Extractor - Unknown - Check Data Aging'
						END
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

	JOIN ExtractRules WITH (NOLOCK)
		ON ExtractTables.DirectoryPath LIKE REPLACE(ExtractRules.SourceDirectory, '*', '%' )
		AND LEN(ExtractRules.SourceFileName) <> LEN( REPLACE(ExtractRules.SourceFileName, ExtractTables.Extension, '') )
		AND ExtractRules.[Rule] = 'DELETE'
	LEFT JOIN ExtractFileAction WITH (NOLOCK)
		ON ExtractTables.FullFilePath = ExtractFileAction.FullFilePath
	LEFT JOIN ExtractDeleteProtected WITH (NOLOCK)
		ON ExtractTables.FullFilePath = ExtractDeleteProtected.Externalmediaid
	WHERE ExtractTables.FullFilePath LIKE @MediaRoot + '%'
	ORDER BY RepositoryDateTime, ExtractTables.FullFilePath
	;

END
--Table doesn't exist, run query without it:
ELSE
BEGIN

	SELECT DISTINCT
	RepositoryDateTime = CAST(ExtractTables.RepositoryDateTime AS DATE)
	,CutOffDate = CAST(GETDATE() - (CAST(ExtractRules.Threshold AS INT) + @ThresholdBump ) AS DATE)
	,ExtractRules.Threshold
	,ExtractTables.TableLocation
	,ExtractTables.FullFilePath
	,ReasonForKeeping = CASE
							WHEN ExtractFileAction.action IS NOT NULL THEN 'Extractor - ExtractFileAction ' + ExtractFileAction.action
							ELSE 'Extractor - Unknown - Check Data Aging'
						END
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

	JOIN ExtractRules WITH (NOLOCK)
		ON ExtractTables.DirectoryPath LIKE REPLACE(ExtractRules.SourceDirectory, '*', '%' )
		AND LEN(ExtractRules.SourceFileName) <> LEN( REPLACE(ExtractRules.SourceFileName, ExtractTables.Extension, '') )
		AND ExtractRules.[Rule] = 'DELETE'
	LEFT JOIN ExtractFileAction WITH (NOLOCK)
		ON ExtractTables.FullFilePath = ExtractFileAction.FullFilePath
	WHERE ExtractTables.FullFilePath LIKE @MediaRoot + '%'
	ORDER BY RepositoryDateTime, ExtractTables.FullFilePath
	;

END
;