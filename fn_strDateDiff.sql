USE Utility;
GO

IF EXISTS(SELECT * FROM sys.objects WHERE [object_id] = OBJECT_ID(N'dbo.fn_strDateDiff'))
	DROP FUNCTION dbo.fn_strDateDiff;
GO

CREATE FUNCTION dbo.fn_strDateDiff
	(
	@dt1 datetime
	,@dt2 datetime
	)
RETURNS varchar(100)
	BEGIN
		DECLARE	@fltWork float = ABS(CAST(@dt1 as float) - CAST(@dt2 as float)) * 8.64e7
				,@fltMs float = 1e0
				,@fltSec float = 1e3
				,@fltMin float = 1e3 * 6e1
				,@fltHr float = 1e3 * 6e1 * 6e1
				,@fltDay float = 1e3 * 6e1 * 6e1 * 2.4e1
				,@strMs varchar(10) = ''
				,@strSec varchar(5) = ''
				,@strMin varchar(5) = ''
				,@strHr varchar(5) = ''
				,@strDay varchar(5) = ''
				,@strResult varchar(100);

		IF @fltWork > @fltDay
			BEGIN
				SELECT	@strDay = CAST(NULLIF(FLOOR(@fltWork / @fltDay), 0) as varchar) + 'd';

				WHILE @fltWork >= @fltDay
					SELECT	@fltWork = @fltWork - @fltDay;

				SELECT	@strHr = CAST(NULLIF(FLOOR(@fltWork / @fltHr), 0) as varchar) + 'hr';

				WHILE @fltWork >= @fltHr
					SELECT	@fltWork = @fltWork - @fltHr;

				SELECT	@strMin = CAST(NULLIF(FLOOR(@fltWork / @fltMin), 0) as varchar) + 'min';
				--PRINT 'Days';
			END;
		ELSE IF @fltWork > @fltHr
			BEGIN
				SELECT	@strHr = CAST(NULLIF(FLOOR(@fltWork / @fltHr), 0) as varchar) + 'hr';

				WHILE @fltWork >= @fltHr
					SELECT	@fltWork = @fltWork - @fltHr;

				SELECT	@strMin = CAST(NULLIF(FLOOR(@fltWork / @fltMin), 0) as varchar) + 'min';

				WHILE @fltWork >= @fltMin
					SELECT	@fltWork = @fltWork - @fltMin;

				SELECT	@strSec = CAST(NULLIF(FLOOR(@fltWork / @fltSec), 0) as varchar) + 's'
				--PRINT 'Hours';
			END;
		ELSE IF @fltWork > @fltMin
			BEGIN
				SELECT	@strMin = CAST(NULLIF(FLOOR(@fltWork / @fltMin), 0) as varchar) + 'min';

				WHILE @fltWork >= @fltMin
					SELECT	@fltWork = @fltWork - @fltMin;

				SELECT	@strSec = CAST(NULLIF(FLOOR(@fltWork / @fltSec), 0) as varchar) + 's';

				WHILE @fltWork >= @fltSec
					SELECT	@fltWork = @fltWork - @fltSec;

				IF @fltWork BETWEEN 2 AND 998
					SELECT	@strMs = CAST(NULLIF(FLOOR(@fltWork / @fltMS), 0) as varchar) + 'ms'
				--PRINT 'Minutes';
			END;
		ELSE IF @fltWork > @fltSec
			BEGIN
				SELECT	@strSec = CAST(NULLIF(FLOOR(@fltWork / @fltSec), 0) as varchar) + 's';

				WHILE @fltWork >= @fltSec
					SELECT	@fltWork = @fltWork - @fltSec;

				IF @fltWork BETWEEN 2 AND 998
					SELECT	@strMs = CAST(NULLIF(FLOOR(@fltWork / @fltMS), 0) as varchar) + 'ms'
				--PRINT 'Seconds';
			END;
		ELSE IF @fltWork > @fltMS
			BEGIN
				SELECT	@strMs = CAST(NULLIF(FLOOR(@fltWork / @fltMS), 0) as varchar) + 'ms'
				--PRINT 'Milliseconds';
			END;
		ELSE
			BEGIN
				SELECT	@strResult = '0ms';
				--PRINT 'No Diff';
			END;

		IF @strResult IS NULL
			SELECT	@strResult	=	COALESCE(@strDay, '') 
								+	COALESCE(' ' + NULLIF(@strHr, ''), '') 
								+	COALESCE(' ' + NULLIF(@strMin, ''), '') 
								+	COALESCE(' ' + NULLIF(@strSec, ''), '') 
								+	COALESCE(' ' + NULLIF(@strMS, ''), '');

		RETURN @strResult;
	END;
GO