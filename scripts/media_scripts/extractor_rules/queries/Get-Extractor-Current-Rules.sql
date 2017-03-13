USE NexidiaExtractor;

SELECT
SourceDirectory
,SourceFileName
,Threshold
FROM ExtractRules WITH (NOLOCK)
WHERE ExtractRules.[Rule] = 'DELETE'
ORDER BY Threshold
;