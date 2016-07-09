--Must specify database context
USE RRS_USRP2
		--Object is the Schema and Table name for your lookup
DECLARE	@intObject int = OBJECT_ID(N'srp.campaign_vif_in'),
		--Column can be Begins With, Ends With or somewhere in between
		@strColumn varchar(100) = '',
		--Column list looks for match of most columns in list
		@strColumns varchar(8000) = '',
		--Delimiter utilized in @strColumns variable list
		@strDelim char(1) = ',',
		--Which order of the index a particular column should be
		@intPriority int = NULL,
		--Non-parameter; Used in the context of the script
		@intIndex int,
		--Non-parameter; Used for splitting delimited string parameter
		@intLength int,
		--Boolean variable; Should the column in @strColumn be required as an Indexed column
		@boolIndex bit = 1

--Validate Variables
SELECT	@intObject = NULLIF(@intObject, 0)
		,@strColumn = NULLIF(@strColumn, '')
		,@strColumns = NULLIF(@strColumns,'')
		,@intPriority = CASE WHEN @intPriority > 0 THEN @intPriority END;

--Used in identifying index with most matched columns by delimited string
DECLARE	@tblColumns TABLE
	(
	intObject int,
	intId int PRIMARY KEY,
	strName varchar(128)
	);

--Length of string + 1 for determining end of recursive loop
SET @intLength = DATALENGTH(@strColumns) + 1;

--Recursive-CTE for splitting string
WITH cte 
AS	(
	SELECT	[intBegin]	= 1
			,[intEnd]	= COALESCE(NULLIF(CHARINDEX(@strDelim, @strColumns, 1), 0), @intLength)
			,[strOutput]	= SUBSTRING(@strColumns, 1, COALESCE(NULLIF(CHARINDEX(@strDelim, @strColumns, 1), 0), @intLength) - 1)
		UNION ALL
	SELECT	[intBegin]	= [intEnd] + 1
			,[intEnd]	= COALESCE(NULLIF(CHARINDEX(@strDelim, @strColumns, [intEnd] + 1), 0), @intLength)
			,[strOutput]	= SUBSTRING(@strColumns, [intEnd] + 1, COALESCE(NULLIF(CHARINDEX(@strDelim, @strColumns, [intEnd] + 1), 0), @intLength) - [intEnd] - 1)
	FROM	cte
	WHERE	[intEnd] < @intLength
	)
INSERT INTO @tblColumns
SELECT		DISTINCT c.[object_id], c.column_id, c.name
FROM		sys.columns c
JOIN		cte ON	(--Pattern recognition algorithm
						c.name LIKE strOutput + '%'
					OR	CHARINDEX(strOutput, c.name) > 0
					)
--Find with specified table
WHERE		c.[object_id] = @intObject
--Only compare strings that aren't blank
AND			DATALENGTH(strOutput) > 0;

--Find index with most matched columns (if any)
SELECT		@intIndex = i.index_id
FROM		sys.indexes i
CROSS APPLY	(
			SELECT	TOP 1 ic.index_id, COUNT(*) [intMatch]
			FROM	@tblColumns tC
			JOIN	sys.columns c ON tC.intObject = c.[object_id]
								 AND tC.intId = c.column_id
			JOIN	sys.index_columns ic ON c.[object_id] = ic.[object_id]
										AND c.column_id = ic.column_id
			GROUP BY ic.index_id
			ORDER BY COUNT(*) DESC
			) caScore
WHERE		i.[object_id] = @intObject
AND			caScore.index_id = i.index_id;

--Unioned Result set; First is Indexed Columns
SELECT		[Type] = i.type_desc
			,[Index Name] = i.name 
			,[Column Name] = c.name
			,[Direction] =	CASE ic.is_descending_key
							WHEN 1 THEN 'DESC'
							ELSE 'ASC' END 
			,[ColRef] = 'Indexed'
			,[Ordinal] = ROW_NUMBER() OVER (PARTITION BY i.index_id, ic.is_included_column ORDER BY ic.key_ordinal)
FROM		sys.indexes i 
JOIN		sys.index_columns ic ON i.[object_id] = ic.[object_id] 
								AND i.index_id = ic.index_id 
JOIN		sys.columns c ON i.[object_id] = c.[object_id] 
						 AND ic.column_id = c.column_id
--Table specified at start of execution
WHERE		i.[object_id] = @intObject
--Index found by most-matched column names, if any
AND			(
				@intIndex IS NULL
			OR	@intIndex = i.index_id
			)
--Indexed results only
AND			ic.is_included_column = CAST(0 as bit)
--Must match column, if any specified, and be indexed if required
AND	  EXISTS(
			SELECT	0
			FROM	sys.index_columns sIC 
			JOIN	sys.columns sC ON sIC.[object_id] = sC.[object_id] 
								  AND sIC.column_id = sC.column_id
			WHERE	sIC.[object_id] = i.[object_id] 
			AND		sIC.index_id = i.index_id 
			AND		(
						@strColumn IS NULL
					OR	@strColumn LIKE sC.name
					OR	CHARINDEX(@strColumn, sC.name) > 0
					)
			AND		(
						@boolIndex IS NULL
					OR	@boolIndex = CAST(0 as bit)
					OR	(
							@boolIndex = CAST(1 as bit)
						AND sIC.is_included_column = CAST(0 as bit)
						)
					)
			--Key Ordinal priority for which position the column should take in the index
			AND		(
						@intPriority IS NULL
					OR	@intPriority < 1
					OR	@intPriority = sIC.key_ordinal
					)
			)
	UNION
--Unioned Result set; Second is Included columns within the Index
SELECT		[Type] = i.[type_desc]
			,[Index Name] = i.name 
			,[Column Name] = c.name
			,[Direction] = ''
			,[ColRef] = 'Included'
			,[Ordinal] = 0
FROM		sys.indexes i 
JOIN		sys.index_columns ic ON i.[object_id] = ic.[object_id] 
								AND i.index_id = ic.index_id 
JOIN		sys.columns c ON i.[object_id] = c.[object_id] 
						 AND ic.column_id = c.column_id
--Table specified at start of execution
WHERE		i.[object_id] = @intObject
--Index found by most-matched column names, if any
AND			(
				@intIndex IS NULL
			OR	@intIndex = i.index_id
			)
--Must be an included column for this result set
AND			ic.is_included_column = CAST(1 as bit)
AND   EXISTS(
			SELECT	0
			FROM	sys.index_columns sIC 
			JOIN	sys.columns sC ON sIC.[object_id] = sC.[object_id] 
								  AND sIC.column_id = sC.column_id
			WHERE	sIC.[object_id] = i.[object_id] 
			AND		sIC.index_id = i.index_id 
			AND		(
						@strColumn IS NULL
					OR	@strColumn LIKE sC.name
					OR	CHARINDEX(@strColumn, sC.name) > 0
					)
			AND		(
						@boolIndex IS NULL
					OR	@boolIndex = CAST(0 as bit)
					OR	(
							@boolIndex = CAST(1 as bit)
						AND sIC.is_included_column = CAST(0 as bit)
						)
					)
			--Key Ordinal priority for which position the column should take in the index
			AND		(
						@intPriority IS NULL
					OR	@intPriority < 1
					OR	@intPriority = sIC.key_ordinal
					)
			)
ORDER BY	[Type], [Index Name], [ColRef] DESC, [Ordinal], [Column Name]