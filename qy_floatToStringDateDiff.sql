DECLARE	@dt1 datetime = GETDATE()
		,@dt2 datetime = {ts '2015-10-16 11:08:30.413'}
		,@fltConvMs numeric(28,20) = 1.15740767796524E-08
		,@numConvDays numeric(17,0) = (24 * POWER(60,2) * POWER(10,3))
		,@numConvHours numeric(17,0) = (POWER(60,2) * POWER(10,3))
		,@numConvMinutes numeric(17,0) = (POWER(60,1) * POWER(10,3))
		,@numConvSeconds numeric(17,0) = POWER(10,3);

SELECT		dt1, dt2, strTimeElapsed
FROM		(VALUES(@dt1, @dt2, CAST(@dt1 as numeric(28,20)) - CAST(@dt2 as numeric(28,20)))) tbl(dt1, dt2, fltDiff)
CROSS APPLY	(VALUES(CAST(ROUND(ABS(tbl.fltDiff) / @fltConvMs,0) as numeric(17,0)))) ca1(numMilliseconds)
CROSS APPLY	(
			SELECT	[numDays] = CAST(NULLIF(ROUND(ca1.numMilliseconds / @numConvDays, 0), 0) as int)
					,[numHours] = CAST(NULLIF(ROUND((ca1.numMilliseconds % @numConvDays) / @numConvHours, 0), 0) as int)
					,[numMinutes] = CAST(NULLIF(ROUND((ca1.numMilliseconds % @numConvHours) / @numConvMinutes, 0), 0) as int)
					,[numSeconds] = CAST(NULLIF(ROUND((ca1.numMilliseconds % @numConvMinutes) / @numConvSeconds, 0), 0) as int)
					,[numMilliseconds] = CAST(NULLIF(ROUND(ca1.numMilliseconds % @numConvSeconds, 0), 0) as int)
			) ca2
CROSS APPLY	(VALUES(COALESCE(CAST(ca2.numDays as varchar) + 'd ','') + COALESCE(CAST(ca2.numHours as varchar) + 'h ','') + COALESCE(CAST(ca2.numMinutes as varchar) + 'm ','') + COALESCE(CAST(ca2.numSeconds as varchar) + 's ','') + COALESCE(CAST(ca2.numMilliseconds as varchar) + 'ms',''))) ca3(strTimeElapsed);