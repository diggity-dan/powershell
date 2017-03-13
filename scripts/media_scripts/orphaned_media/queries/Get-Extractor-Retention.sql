
USE NexidiaExtractor;

DECLARE @ThresholdBump INT = 2;

SELECT
SourceDirectory
,SourceFileName
,Threshold = (CAST(Threshold AS INT) + @ThresholdBump)
,CutOff = CAST( GETDATE() - (CAST(Threshold AS INT) + @ThresholdBump) AS DATE)
FROM ExtractRules
WHERE [Rule] = 'Delete'
;