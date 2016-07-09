SET NOCOUNT ON;

DECLARE	@numNum numeric(9,2) = 4179
		,@numDen numeric(9,2) = 321
		,@numDiv numeric(9,2)
		,@numStep numeric(9,2) = 0
		,@numValue numeric(17,0) = 2
		,@intMod int = 0;

DECLARE	@tblDivisors TABLE
	(
	intId int IDENTITY(1,1)
	,numValue numeric(9,2) PRIMARY KEY
	);

DECLARE	@tblSteps TABLE
	(
	numNum numeric(9,2)
	,numDen numeric(9,2)
	,numDiv numeric(9,2)
	,intStep int PRIMARY KEY
	);

WHILE @numNum <> CAST(@numNum as int)
	SELECT	@numNum = @numNum * 10
			,@numDen = @numDen * 10;
WHILE @numDen <> CAST(@numDen as int)
	SELECT	@numNum = @numNum * 10
			,@numDen = @numDen * 10;

INSERT INTO @tblDivisors
VALUES(@numValue);

WHILE @@IDENTITY < 1000
	BEGIN
		SET @numValue = @numValue + 1;

		IF NOT EXISTS(SELECT 0 FROM @tblDivisors tP WHERE @numValue % numValue = 0)
			INSERT INTO @tblDivisors
			SELECT	@numValue
	END

INSERT INTO @tblSteps
VALUES(@numNum, @numDen, @numDiv, @numStep);

WHILE EXISTS(SELECT 0 FROM @tblDivisors tD WHERE @numNum % numValue = 0 AND @numDen % numValue = 0)
	BEGIN
		SET	@numDiv = NULL;
		SET	@numStep = @numStep + 1;
		
		SELECT	@numDiv = numValue
		FROM	(
				SELECT	*
						,[rowNum] = ROW_NUMBER() OVER (ORDER BY numValue DESC)
				FROM	@tblDivisors tD
				WHERE	@numNum % numValue = 0
				AND		@numDen % numValue = 0
				) tD
		WHERE	tD.rowNum = 1;

		SELECT	@numNum = (CAST(@numNum as int) / CAST(@numDiv as int))
				,@numDen = (CAST(@numDen as int) / CAST(@numDiv as int));

		INSERT INTO @tblSteps
		VALUES(@numNum, @numDen, @numDiv, @numStep);
	END

SELECT	*
FROM	@tblSteps