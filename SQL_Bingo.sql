IF EXISTS(
		SELECT	0
		FROM	sys.objects
		WHERE	[object_id] = OBJECT_ID(N'dbo.Bingo') AND
				OBJECTPROPERTY([object_id], 'isTable') = 1
		 )
	DROP TABLE dbo.Bingo
GO

IF EXISTS(
		SELECT	0
		FROM	sys.objects
		WHERE	[object_id] = OBJECT_ID(N'dbo.BingoCheck') AND
				OBJECTPROPERTY([object_id],'isProcedure') = 1
		 )
	DROP PROCEDURE dbo.BingoCheck
GO

IF EXISTS(
		SELECT	0
		FROM	sys.objects
		WHERE	[object_id] = OBJECT_ID(N'dbo.BingoCall') AND
				OBJECTPROPERTY([object_id],'isProcedure') = 1
		 )
	DROP PROCEDURE dbo.BingoCall
GO

CREATE TABLE dbo.Bingo
	(
	RowNum int IDENTITY(1,1) NOT NULL,
	B int NULL, 
	I int NULL, 
	N int NULL, 
	G int NULL, 
	O int NULL
	)
GO

CREATE PROCEDURE dbo.BingoCheck
	(@Column char(1), @Value int, @Row int OUTPUT)
AS
	SELECT	@Row = RowNum
	FROM	dbo.Bingo
	WHERE	B = @Value AND
			@Column = 'B'

	SELECT	@Row = RowNum
	FROM	dbo.Bingo
	WHERE	I = @Value AND
			@Column = 'I'

	SELECT	@Row = RowNum
	FROM	dbo.Bingo
	WHERE	N = @Value AND
			@Column = 'N'

	SELECT	@Row = RowNum
	FROM	dbo.Bingo
	WHERE	G = @Value AND
			@Column = 'G'

	SELECT	@Row = RowNum
	FROM	dbo.Bingo
	WHERE	O = @Value AND
			@Column = 'O'
GO

DECLARE	@Call varchar(1000),
		@Check varchar(1000),
		@Letter char(1),
		@RowNum int,
		@Row int,
		@Number int,
		@BValue int,
		@IValue int,
		@NValue int,
		@GValue int,
		@OValue int,
		@BSum int,
		@ISum int,
		@NSum int,
		@GSum int,
		@OSum int,
		@XSum1 int,
		@XSum2 int,
		@RowSum1 int,
		@RowSum2 int,
		@RowSum3 int,
		@RowSum4 int,
		@RowSum5 int
WHILE (SELECT COUNT(0) FROM dbo.Bingo) < 5
	BEGIN
		SELECT	@BValue = ABS(CHECKSUM(NEWID()) % 99) + 1,
				@IValue = ABS(CHECKSUM(NEWID()) % 99) + 1,
				@NValue = ABS(CHECKSUM(NEWID()) % 99) + 1,
				@GValue = ABS(CHECKSUM(NEWID()) % 99) + 1,
				@OValue = ABS(CHECKSUM(NEWID()) % 99) + 1
		INSERT INTO dbo.Bingo
			(B, I, N, G, O)
		SELECT	@BValue, @IValue, @NValue, @GValue, @OValue
		WHERE NOT EXISTS(
						SELECT	0
						FROM	dbo.Bingo
						WHERE	dbo.Bingo.B = @BValue OR
								dbo.Bingo.I = @IValue OR
								dbo.Bingo.N = @NValue OR
								dbo.Bingo.G = @GValue OR
								dbo.Bingo.O = @OValue
						)
	END

UPDATE	dbo.Bingo
SET		N = 0
WHERE	RowNum = 3

SELECT	@BSum = SUM(B),
		@ISum = SUM(I),
		@NSum = SUM(N),
		@GSum = SUM(G),
		@OSum = SUM(O),
		@RowSum1 = (SELECT B + I + N + G + O FROM dbo.Bingo WHERE dbo.Bingo.RowNum = 1),
		@RowSum2 = (SELECT B + I + N + G + O FROM dbo.Bingo WHERE dbo.Bingo.RowNum = 2),
		@RowSum3 = (SELECT B + I + N + G + O FROM dbo.Bingo WHERE dbo.Bingo.RowNum = 3),
		@RowSum4 = (SELECT B + I + N + G + O FROM dbo.Bingo WHERE dbo.Bingo.RowNum = 4),
		@RowSum5 = (SELECT B + I + N + G + O FROM dbo.Bingo WHERE dbo.Bingo.RowNum = 5)
FROM	dbo.Bingo

SELECT	@XSum1 = SUM(X1), 
		@XSum2 = SUM(X2)
FROM	(
		SELECT	CASE RowNum
					WHEN 1 THEN B
					WHEN 2 THEN I
					WHEN 3 THEN N
					WHEN 4 THEN G
					WHEN 5 THEN O
					END X1,
				CASE RowNum
					WHEN 1 THEN O
					WHEN 2 THEN G
					WHEN 3 THEN N
					WHEN 4 THEN I
					WHEN 5 THEN B
					END X2
		FROM	dbo.Bingo
		) Table1


WHILE	@BSum > 0 AND
		@ISum > 0 AND
		@NSum > 0 AND
		@GSum > 0 AND
		@OSum > 0 AND
		@RowSum1 > 0 AND
		@RowSum2 > 0 AND
		@RowSum3 > 0 AND
		@RowSum4 > 0 AND
		@RowSum5 > 0 AND
		@XSum1 > 0 AND
		@XSum2 > 0
	BEGIN
		SELECT	@Letter = CASE ABS(CHECKSUM(NEWID()) % 5) + 1
							 WHEN 1 THEN 'B'
							 WHEN 2 THEN 'I'
							 WHEN 3 THEN 'N'
							 WHEN 4 THEN 'G'
							 WHEN 5 THEN 'O'
							 END,
				@Number = ABS(CHECKSUM(NEWID()) % 99) + 1

		EXEC dbo.BingoCheck @Letter, @Number, @Row OUTPUT
		SELECT	@RowNum = @Row
		SELECT	@Call =
		'
		UPDATE	dbo.Bingo
		SET		' + @Letter + ' = 0 
		WHERE	RowNum = ' + CAST(@RowNum as varchar(1))
		EXEC	(@Call)

		SELECT	@BSum = SUM(B),
				@ISum = SUM(I),
				@NSum = SUM(N),
				@GSum = SUM(G),
				@OSum = SUM(O),
				@RowSum1 = (SELECT B + I + N + G + O FROM dbo.Bingo WHERE dbo.Bingo.RowNum = 1),
				@RowSum2 = (SELECT B + I + N + G + O FROM dbo.Bingo WHERE dbo.Bingo.RowNum = 2),
				@RowSum3 = (SELECT B + I + N + G + O FROM dbo.Bingo WHERE dbo.Bingo.RowNum = 3),
				@RowSum4 = (SELECT B + I + N + G + O FROM dbo.Bingo WHERE dbo.Bingo.RowNum = 4),
				@RowSum5 = (SELECT B + I + N + G + O FROM dbo.Bingo WHERE dbo.Bingo.RowNum = 5)
		FROM	dbo.Bingo

		SELECT	@XSum1 = SUM(X1), 
				@XSum2 = SUM(X2)
		FROM	(
				SELECT	CASE RowNum
							WHEN 1 THEN B
							WHEN 2 THEN I
							WHEN 3 THEN N
							WHEN 4 THEN G
							WHEN 5 THEN O
							END X1,
						CASE RowNum
							WHEN 1 THEN O
							WHEN 2 THEN G
							WHEN 3 THEN N
							WHEN 4 THEN I
							WHEN 5 THEN B
							END X2
				FROM	dbo.Bingo
				) Table1
	END

SELECT	*
FROM	dbo.Bingo