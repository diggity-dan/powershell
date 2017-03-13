
USE NexidiaESI;

DECLARE @MediaRoot NVARCHAR(1024) = '{{MEDIAROOT}}'
;

--Check Files:
SELECT
SourceMediaId = SourceMedia.SourceMediaId
,ExternalMediaId = SourceMedia.ExternalMediaId
,CallDateTime = CAST(SourceMedia.CallDateTime AS DATE)
,ReasonForKeeping = CASE
						WHEN SourceMediaAssignedTo.SourceMediaID IS NOT NULL THEN 'NIA - Media Assigned'
						WHEN SourceMediaMediaReservation.SourceMediaId IS NOT NULL THEN 'NIA - Media Reserved'
						ELSE 'NIA - Unknown - Check Data Aging'
					END
FROM SourceMedia WITH (NOLOCK)
LEFT JOIN SourceMediaMediaReservation WITH (NOLOCK)
	ON SourceMedia.SourceMediaId = SourceMediaMediaReservation.SourceMediaId
LEFT JOIN SourceMediaAssignedTo WITH (NOLOCK)
	ON SourceMedia.SourceMediaId = SourceMediaAssignedTo.SourceMediaId
WHERE SourceMedia.ExternalMediaId LIKE @MediaRoot + '%'
ORDER BY CAST(SourceMedia.CallDateTime AS DATE) DESC, SourceMedia.ExternalMediaId
;