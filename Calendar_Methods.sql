/******************Recursive CTE Calendar***************************/
DECLARE @Start datetime = GETDATE()
DECLARE @StartDate date = DATEADD(yy, -40, GETDATE())
      , @EndDate date = DATEADD(yy, +40, GETDATE())
; WITH Calendar (Date_)
AS
       (
       SELECT @StartDate
              UNION ALL
       SELECT DATEADD(dd,1,Date_)
       FROM  Calendar
       WHERE  Date_ < @EndDate 
       )

SELECT COUNT(0)
FROM   Calendar
OPTION (MAXRECURSION 0)

PRINT DateDiff(ms,@Start, GETDATE())
GO 3
/******************WHILE LOOP Calendar***************************/

DECLARE	@Start datetime = GETDATE()
DECLARE	@StartDate date = DATEADD(yy, -40, GETDATE())
		,@EndDate date = DATEADD(yy, +40, GETDATE());

DECLARE @Calendar TABLE
	(Date_ date PRIMARY KEY CLUSTERED)

DECLARE @Count int;

INSERT INTO @Calendar
SELECT @StartDate 

WHILE NOT EXISTS (SELECT TOP 1 0 FROM @Calendar Where Date_ = @EndDate)
	BEGIN
		SELECT	@Count = COUNT(0) 
		FROM	@Calendar;
            
		INSERT INTO @Calendar
		SELECT	*
		FROM	(
			SELECT	DATEADD(dd, @Count, Date_) Date_
			FROM	@Calendar
			) A
		WHERE A.Date_ <= @EndDate 
	END

SELECT COUNT(0)
FROM   @Calendar;

PRINT DateDiff(ms,@Start, GETDATE());
GO 3
/******************WHILE LOOP w/ Identity Calendar***************************/
DECLARE	@Start datetime = GETDATE()
DECLARE	@StartDate date = DATEADD(yy, -40, GETDATE())
		,@EndDate date = DATEADD(yy, +40, GETDATE());

DECLARE @Calendar TABLE
	(Date_ date UNIQUE CLUSTERED, intId int IDENTITY(1,1) PRIMARY KEY NONCLUSTERED)

INSERT INTO @Calendar
	(Date_)
SELECT @StartDate 

WHILE NOT EXISTS (SELECT TOP 1 0 FROM @Calendar Where Date_ = @EndDate)
	INSERT INTO @Calendar
		(Date_)
	SELECT	*
	FROM	(
			SELECT	[Date_] = DATEADD(DD, @@IDENTITY, Date_) 
			FROM	@Calendar
			) A
	WHERE A.Date_ <= @EndDate 

SELECT COUNT(0)
FROM   @Calendar;

PRINT DateDiff(ms,@Start, GETDATE());
GO 3

/******************WHILE LOOP w/ Cross Apply Calendar***************************/
DECLARE	@Start datetime = GETDATE()
DECLARE	@StartDate date = DATEADD(yy, -40, GETDATE())
		,@EndDate date = DATEADD(yy, +40, GETDATE());

DECLARE @Calendar TABLE
	(Date_ date PRIMARY KEY CLUSTERED)

INSERT INTO @Calendar
	(Date_)
SELECT @StartDate 

WHILE NOT EXISTS (SELECT TOP 1 0 FROM @Calendar Where Date_ = @EndDate)
	INSERT INTO @Calendar
		(Date_)
	SELECT	A.*
	FROM	(SELECT [intCount] = COUNT(*) FROM @Calendar) tbl
	CROSS APPLY	(
				SELECT	[Date_] = DATEADD(DD, intCount, Date_) 
				FROM	@Calendar
				) A
	WHERE A.Date_ <= @EndDate 

SELECT COUNT(0)
FROM   @Calendar;

PRINT DateDiff(ms,@Start, GETDATE());
GO 3