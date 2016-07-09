DECLARE @i int
DECLARE @tblFormats TABLE
	(
	id int PRIMARY KEY CLUSTERED,
	strFormat varchar(200)
	)
SET @i = 0
WHILE @i < 200
	BEGIN
		SET @i = @i + 1

		BEGIN TRY
		INSERT INTO @tblFormats
		SELECT	@i, CONVERT(varchar(200),GETDATE(),@i)
		END TRY
		BEGIN CATCH
		END CATCH
	END
SELECT	*
FROM	@tblFormats
