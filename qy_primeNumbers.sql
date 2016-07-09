SET NOCOUNT ON;

DECLARE	@numValue numeric(17,0) = 2;

DECLARE	@tblPrimes TABLE
	(
	intId int IDENTITY(1,1)
	,numPrime numeric(17,0)
	);

INSERT INTO @tblPrimes
VALUES(@numValue);

WHILE @@IDENTITY < 1000
	BEGIN
		SET @numValue = @numValue + 1;

		IF NOT EXISTS(SELECT 0 FROM @tblPrimes tP WHERE @numValue % numPrime = 0)
			INSERT INTO @tblPrimes
			SELECT	@numValue
	END

SELECT	*
FROM	@tblPrimes
ORDER BY numPrime