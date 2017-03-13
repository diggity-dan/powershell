USE NexidiaESI;

DECLARE @RetentionBump INT = 2;

--Get Stored Params:
DECLARE @MediaRetention INT = (SELECT dbo.cfnGetCfgParameter('cfgMediaRetentionDays', ''));
DECLARE @MediaTypeList NVARCHAR(1024) = (SELECT 
										 dbo.cfnGetCfgParameter('Nexidia.Enterprise.IngestServer.MediaFileExtensions'
										 ,'aac,aif,aifc,aiff,alaw,asf,au,aud,avi,g722,g729a,gsm,mov,mp2,mp3,mp4,mpeg,mpg,mpg4,mulaw,nmf,pcm,qt,vox,vx8,wav,wm,wma,wmv')
										 );
DECLARE @DataRetention INT = (SELECT dbo.cfnGetCfgParameter('cfgDataRetentionDays', ''));

--Check for -1 media: 
IF (@MediaRetention = -1 AND @DataRetention > 0)
BEGIN
	SET @MediaRetention = @DataRetention;
END
;

--Check for -1 data:
IF (@DataRetention = -1 AND @MediaRetention > 0)
BEGIN
	SET @DataRetention = @MediaRetention;
END
;

--Assign CutOff Date:
--Add one day because aging usually happens overnight.
DECLARE @MediaCutoff DATE = CAST(GETDATE() - (@MediaRetention + @RetentionBump) AS DATE);
DECLARE @DataCutoff DATE = CAST(GETDATE() - (@DataRetention + @RetentionBump) AS DATE);


--Return Values:
SELECT
MediaRetention = (@MediaRetention + @RetentionBump)
,MediaCutoff = @MediaCutoff
,MediaTypeList = @MediaTypeList
,DataRetention = (@DataRetention + @RetentionBump)
,DataCutoff = @DataCutoff
;