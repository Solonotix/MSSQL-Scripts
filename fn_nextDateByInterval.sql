USE Utility;

IF EXISTS(SELECT * FROM sys.objects WHERE [type] = N'FN' and [name] = 'fn_nextDateByInterval')
	DROP FUNCTION dbo.fn_nextDateByInterval;
GO

CREATE FUNCTION dbo.fn_nextDateByInterval
	(
	@intInterval int
	,@dt1 datetime
	,@dt2 datetime
	)
RETURNS date
AS
	BEGIN
		DECLARE @dtNextInterval date
				,@flt1 real
				,@flt2 real;

		SELECT
			@flt1 = CAST(CAST(@dt1 as datetime) as float)
			,@flt2 = CAST(CAST(@dt2 as datetime) as float);

		SELECT
			@dtNextInterval = DATEADD(DD, (1 + FLOOR((@flt2 - @flt1) / @intInterval)) * @intInterval, @dt1);

		RETURN @dtNextInterval;
	END;
GO

SELECT
	[fn_dtNextInterval] = dbo.fn_nextDateByInterval(180, dtLastVisit, dtCampaign)
	,*
	,flt2 - flt1
	,(flt2 - flt1) / intInterval
	,DATEADD(DD, (FLOOR((flt2 - flt1) / intInterval)) * intInterval, dtLastVisit)
FROM
	(VALUES(180, CAST({d '2016-06-19'} as date), CAST({d '2016-12-22'} as date))) tbl(intInterval, dtLastVisit, dtCampaign)
	cross apply (
		SELECT
			[flt1] = CAST(CAST(dtLastVisit as datetime) as real)
			,[flt2] = CAST(CAST(dtCampaign as datetime) as real)
		) ca1
	cross apply (
		SELECT
			[qy_dtNextInterval] = DATEADD(DD, (1 + FLOOR((flt2 - flt1) / intInterval)) * intInterval, dtLastVisit)
		) ca2;