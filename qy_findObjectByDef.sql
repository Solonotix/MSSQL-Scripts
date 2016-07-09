SET NOCOUNT ON;

DECLARE	@strSQL varchar(MAX) = ''
		--Object Types (U for Table, P for Procedure, etc)
		,@strObjectTypes varchar(100) = ''
		--Schema name patterns, comma-delimited
		,@strSchemaPats varchar(MAX) = ''
		--Object name patterns, comma-delimited
		,@strObjectPats varchar(MAX) = ''
		--Column name patterns, comma-delimited
		,@strColumnPats varchar(MAX) = ''
		--Stored Procedure Contains Text
		,@strContainsDef varchar(MAX) = ''
		--Replace all synonyms with Fully-qualified names
		,@boolSynCleanse bit = 0
		--Database Name (if known)
		,@strDBName varchar(128) = '';

DECLARE	@tblSplit TABLE
	(
	intPosition int
	,intLength int
	,strPosition char(1)
	);

DECLARE	@tblObjectPats TABLE
	(
	intId int NOT NULL IDENTITY(1,1) PRIMARY KEY NONCLUSTERED
	,strOriginal sysname NOT NULL
	,strSchema sysname NULL
	,strObject sysname NOT NULL
	,UNIQUE CLUSTERED(strOriginal, intId)
	);

DECLARE	@tblResults TABLE
	(
	[Database] sysname NOT NULL
	,[Object] sysname NOT NULL
	,[parentObject] sysname NOT NULL
	,[ObjectType] nchar(2) NOT NULL
	,strDefinition nvarchar(MAX) NULL
	,PRIMARY KEY CLUSTERED([Database], [Object], [parentObject])
	);

SELECT	@strObjectTypes = REPLACE(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(@strObjectTypes, ',', ' '), ' ', '><'), '<>', ''), '><', ' '))), ''), ' ', ',')
		,@strSchemaPats = REPLACE(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(@strSchemaPats, ',', ' '), ' ', '><'), '<>', ''), '><', ' '))), ''), ' ', ',')
		,@strObjectPats = REPLACE(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(@strObjectPats, ',', ' '), ' ', '><'), '<>', ''), '><', ' '))), ''), ' ', ',')
		,@strColumnPats = REPLACE(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(@strColumnPats, ',', ' '), ' ', '><'), '<>', ''), '><', ' '))), ''), ' ', ',')
		,@strContainsDef = REPLACE(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(@strContainsDef, ',', ' '), ' ', '><'), '<>', ''), '><', ' '))), ''), ' ', ',')
		,@strDBName = REPLACE(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(@strDBName, ',', ' '), ' ', '><'), '<>', ''), '><', ' '))), ''), ' ', ',')

SELECT	@strSql = '
USE [?];

DECLARE	@strSyn nvarchar(255)
		,@strSynDef nvarchar(255);

CREATE TABLE #sqlModules
	(
	[object_id] int NOT NULL PRIMARY KEY
	,[definition] nvarchar(MAX) NULL
	);

##SynCleanse##

WITH cteUniqueConstDef
AS	(
	SELECT	o.[object_id]
			,[unique_constraint] = ''CONSTRAINT '' + QUOTENAME(o.name) + CASE o.[type] WHEN N''PK'' THEN '' PRIMARY KEY ('' WHEN N''UQ'' THEN '' UNIQUE ('' END + (SELECT CASE ROW_NUMBER() OVER (ORDER BY ic.key_ordinal) WHEN 1 THEN '''' ELSE '', '' END + c.name FROM sys.index_columns ic JOIN sys.columns c ON ic.[object_id] = c.[object_id] AND ic.column_id = c.column_id WHERE o.[parent_object_id] = c.[object_id] AND ic.index_id = i.index_id AND ic.is_included_column = 0 FOR XML PATH('''')) + '')''
	FROM	sys.objects o
	JOIN	sys.indexes i ON o.parent_object_id = i.[object_id]
	WHERE	o.[type] IN (N''UQ'', ''PK'')
	AND		i.name = o.name
	),
	cteDefaultConstDef
AS	(
	SELECT		o.[object_id]
				,[default_constraint] = c.name + '' '' + t.name + ca1.data_type + '' DEFAULT '' + dc.[definition]
	FROM		sys.objects o
	JOIN		sys.default_constraints dc ON o.[object_id] = dc.[object_id]
	JOIN		sys.columns c ON o.[parent_object_id] = c.[object_id] AND dc.parent_column_id = c.column_id
	JOIN		sys.types t ON c.[user_type_id] = t.[user_type_id]
	CROSS APPLY	(
				SELECT	[data_type] = CASE t.name
										WHEN ''binary'' THEN ''('' + CAST(c.max_length as varchar) + '') ''
										WHEN ''char'' THEN ''('' + CAST(c.max_length as varchar) + '') ''
										WHEN ''decimal'' THEN ''('' + CAST(c.[precision] as varchar) + ''~comma '' + CAST(c.[scale] as varchar) + '') ''
										WHEN ''nchar'' THEN ''('' + CAST((c.max_length / 2) as varchar) + '') ''
										WHEN ''ntext'' THEN ''('' + CAST((c.max_length / 2) as varchar) + '') ''
										WHEN ''numeric'' THEN ''('' + CAST(c.[precision] as varchar) + ''~comma '' + CAST(c.[scale] as varchar) + '') ''
										WHEN ''nvarchar'' THEN ''('' + CAST((c.max_length / 2) as varchar) + '') ''
										WHEN ''real'' THEN ''('' + CAST(c.[precision] as varchar) + ''~comma '' + CAST(c.[scale] as varchar) + '') ''
										WHEN ''varbinary'' THEN ''('' + CAST(c.max_length as varchar) + '') ''
										WHEN ''varchar'' THEN ''('' + CAST(c.max_length as varchar) + '') ''
										ELSE '''' END
									+ CASE t.name
										WHEN ''char'' THEN ''COLLATE '' + COALESCE(c.collation_name, t.collation_name, '''')
										WHEN ''nchar'' THEN ''COLLATE '' + COALESCE(c.collation_name, t.collation_name, '''') 
										WHEN ''ntext'' THEN ''COLLATE '' + COALESCE(c.collation_name, t.collation_name, '''')
										WHEN ''nvarchar'' THEN ''COLLATE '' + COALESCE(c.collation_name, t.collation_name, '''')
										WHEN ''varchar'' THEN ''COLLATE '' + COALESCE(c.collation_name, t.collation_name, '''')
										ELSE '''' END
									+ CASE c.is_nullable
										WHEN 1 THEN '' NULL''
										ELSE '' NOT NULL'' END
									+ CASE c.is_identity 
										WHEN 1 THEN '' PRIMARY KEY NONCLUSTERED'' 
										ELSE '''' END
				) ca1
	WHERE		o.[type] = N''D''
	), 
	cteTableDef
AS	(
	SELECT		c.[object_id]
				,c.[column_id]
				,c.[definition]
	FROM		sys.schemas s
	JOIN		sys.objects o ON s.[schema_id] = o.[schema_id]
	JOIN		(
				SELECT		c.[object_id]
							,c.[column_id]
							,[definition] = c.name + '' '' + t.name + ca1.data_type
				FROM		sys.columns c
				JOIN		sys.types t ON c.user_type_id = t.user_type_id 
				LEFT JOIN	(
							SELECT		i.[object_id]
										,[column_id] = MAX(ic.column_id)
										,[index_type] = MAX(i.[type])
							FROM		sys.indexes i
							JOIN		sys.index_columns ic ON i.[object_id] = ic.[object_id] AND i.index_id = ic.index_id
							JOIN		sys.columns c ON i.[object_id] = c.[object_id] AND ic.column_id = c.column_id
							WHERE		i.is_primary_key = 1
							GROUP BY	i.[object_id]
							HAVING		COUNT(DISTINCT c.column_id) = 1
							) i ON c.[object_id] = i.[object_id] AND c.[column_id] = i.[column_id]
				CROSS APPLY	(
							SELECT	[data_type] = CASE t.name
													WHEN ''binary'' THEN ''('' + CAST(c.max_length as varchar) + '') ''
													WHEN ''char'' THEN ''('' + CAST(c.max_length as varchar) + '') ''
													WHEN ''decimal'' THEN ''('' + CAST(c.[precision] as varchar) + ''~comma '' + CAST(c.[scale] as varchar) + '') ''
													WHEN ''nchar'' THEN ''('' + CAST((c.max_length / 2) as varchar) + '') ''
													WHEN ''ntext'' THEN ''('' + CAST((c.max_length / 2) as varchar) + '') ''
													WHEN ''numeric'' THEN ''('' + CAST(c.[precision] as varchar) + ''~comma '' + CAST(c.[scale] as varchar) + '') ''
													WHEN ''nvarchar'' THEN ''('' + CAST((c.max_length / 2) as varchar) + '') ''
													WHEN ''real'' THEN ''('' + CAST(c.[precision] as varchar) + ''~comma '' + CAST(c.[scale] as varchar) + '') ''
													WHEN ''varbinary'' THEN ''('' + CAST(c.max_length as varchar) + '') ''
													WHEN ''varchar'' THEN ''('' + CAST(c.max_length as varchar) + '') ''
													ELSE '''' END
												+ CASE t.name
													WHEN ''char'' THEN ''COLLATE '' + COALESCE(c.collation_name, t.collation_name, '''')
													WHEN ''nchar'' THEN ''COLLATE '' + COALESCE(c.collation_name, t.collation_name, '''') 
													WHEN ''ntext'' THEN ''COLLATE '' + COALESCE(c.collation_name, t.collation_name, '''')
													WHEN ''nvarchar'' THEN ''COLLATE '' + COALESCE(c.collation_name, t.collation_name, '''')
													WHEN ''varchar'' THEN ''COLLATE '' + COALESCE(c.collation_name, t.collation_name, '''')
													ELSE '''' END
												+ CASE c.is_nullable
													WHEN 1 THEN '' NULL''
													ELSE '' NOT NULL'' END
												+ CASE c.column_id 
													WHEN i.column_id THEN	CASE i.index_type
																			WHEN 1 THEN '' PRIMARY KEY CLUSTERED'' 
																			ELSE '' PRIMARY KEY NONCLUSTERED'' END
													ELSE '''' END
							) ca1
					UNION ALL
				SELECT	cc.[object_id]
						,cc.[column_id]
						,[definition] = cc.name + '' as '' + REPLACE(cc.[definition], '','', ''~comma'')
				FROM	sys.computed_columns cc
				) c ON o.[object_id] = c.[object_id]
	)
SELECT		[Database] = DB_NAME()
			,[Object] = s.name + N''.'' + o.name
			,[parentObject] = COALESCE(p.strParent, N'''')
			,[Type] = o.[type]			
			,[strDefinition] = COALESCE(sY.base_object_name, uCD.unique_constraint, dCD.[default_constraint], sM.cleansed_definition, sM.[definition], oa1.column_definition, OBJECT_DEFINITION(o.[object_id]))
FROM		sys.schemas s
JOIN		sys.objects o ON s.[schema_id] = o.[schema_id]
LEFT JOIN	sys.synonyms sY ON o.[object_id] = sY.[object_id]
LEFT JOIN	cteUniqueConstDef uCD ON o.[object_id] = uCD.[object_id]
LEFT JOIN	cteDefaultConstDef dCD ON o.[object_id] = dCD.[object_id]
LEFT JOIN	(
			SELECT	o.[object_id]
					,[strParent] = s.name + N''.'' + o.name
					,[schema_name] = s.name
					,[object_name] = o.name
			FROM	sys.schemas s
			JOIN	sys.objects o ON s.[schema_id] = o.[schema_id]
			) p ON o.[parent_object_id] = p.[object_id]
LEFT JOIN	(
			SELECT		sM.[object_id]
						,[definition] = OBJECT_DEFINITION(sM.[object_id])
						,[cleansed_definition] = MAX(sM1.[definition])
						,[intContains] = COUNT(*)
			FROM		sys.sql_modules sM
			LEFT JOIN	#sqlModules sM1 ON sM.[object_id] = sM1.[object_id]
			##strContainsDef##
			WHERE		(
							(
								sM1.[object_id] IS NULL
							AND	CHARINDEX(ca5.strContainsDef, sM.[definition]) > 0
							)
						OR	(
								sM.[object_id] = sM1.[object_id]
							AND	CHARINDEX(ca5.strContainsDef, sM1.[definition]) > 0
							)
						)
			GROUP BY	sM.[object_id]
			HAVING		COUNT(*) >= (SELECT COUNT(*) FROM (VALUES(0)) tbl(intVal) ##strContainsDef##)
			) sM ON o.[object_id] = sM.[object_id]
LEFT JOIN	(
			SELECT		c.[object_id]
						,[intColumns] = COUNT(*)
			FROM		sys.columns c
			##strColumnPats##
			WHERE		c.name LIKE ca4.strColumnPats
			GROUP BY	c.[object_id]
			HAVING		COUNT(*) >= (SELECT COUNT(*) FROM (VALUES(0)) tbl(intVal) ##strColumnPats##)
			) c ON o.[object_id] = c.[object_id]
##strObjectTypes##
##strSchemaPats##
##strObjectPats##
CROSS APPLY	(
			SELECT	COUNT(*)
			FROM	(VALUES(0)) tbl(intVal)
			##strColumnPats##
			WHERE	ca4.strColumnPats <> N''%''
			) ca6(intColumns)
CROSS APPLY	(
			SELECT	COUNT(*)
			FROM	(VALUES(0)) tbl(intVal)
			##strContainsDef##
			WHERE	ca5.strContainsDef <> N''%''
			) ca7(intContains)
OUTER APPLY	(
			SELECT	[column_definition] = ''CREATE TABLE '' + s.name + ''.'' + o.name + CHAR(13) + CHAR(9) + ''('' + CHAR(13) + CHAR(9) + 
							+ REPLACE(REPLACE(
							STUFF((
									SELECT	CASE ROW_NUMBER() OVER (ORDER BY cTD.column_id)
											WHEN 1 THEN ''''
											ELSE '','' END + cTD.[definition]
									FROM	cteTableDef cTD
									WHERE	o.[object_id] = cTD.[object_id]
									FOR XML PATH(''''), TYPE
										).value(''.'', ''nvarchar(MAX)''), 1, 0, ''''), '','', CHAR(13) + CHAR(9) + '','') + CHAR(13) + CHAR(9) + '');'', ''~comma'', '','')

			) oa1
WHERE		o.[type] LIKE ca1.strObjectTypes
AND			o.[type] <> N''PK''
AND			(
				(
					s.name LIKE ca2.strSchemaPats
				AND	o.name LIKE ca3.strObjectPats
				)
			OR	(
					p.[schema_name] LIKE ca2.strSchemaPats
				AND	p.[object_name] LIKE ca3.strObjectPats
				)
			)
AND			(
				ca6.intColumns = 0
			OR	c.intColumns >= ca6.intColumns
			)
AND			(
				ca7.intContains = 0
			OR	sM.intContains >= ca7.intContains
			)
	UNION
SELECT		[Database] = DB_NAME()
			,[Index] = i.name
			,[parentTable] = s.name + N''.'' + o.name
			,[indexType] = caVals.indexType
			,[strDefinition] =	caVals.strBeginDef +
								(
								SELECT	CASE ROW_NUMBER() OVER (PARTITION BY ic.[object_id] ORDER BY ic.key_ordinal)
										WHEN 1 THEN ''''
										ELSE N'', '' END 
									+	c.name
									+	CASE ic.is_descending_key
										WHEN CAST(1 as bit) THEN N'' DESC''
										ELSE N'''' END
								FROM	sys.index_columns ic
								JOIN	sys.columns c ON ic.[object_id] = c.[object_id] AND ic.column_id = c.column_id
								WHERE	o.[object_id] = ic.[object_id]
								AND		i.index_id = ic.index_id
								AND		ic.is_included_column = CAST(0 as bit)
								FOR XML PATH('''')
								) + N'')'' + COALESCE(NCHAR(13) + N''INCLUDE('' +
								(
								SELECT	CASE ROW_NUMBER() OVER (PARTITION BY ic.[object_id] ORDER BY ic.key_ordinal)
										WHEN 1 THEN N''''
										ELSE N'', '' END 
									+	c.name
									+	CASE ic.is_descending_key
										WHEN CAST(1 as bit) THEN N'' DESC''
										ELSE N'''' END
								FROM	sys.index_columns ic
								JOIN	sys.columns c ON ic.[object_id] = c.[object_id] AND ic.column_id = c.column_id
								WHERE	o.[object_id] = ic.[object_id]
								AND		i.index_id = ic.index_id
								AND		ic.is_included_column = CAST(1 as bit)
								FOR XML PATH('''')
								) + N'')'', N'''')
FROM		sys.indexes i
JOIN		sys.objects o ON i.[object_id] = o.[object_id]
JOIN		sys.schemas s ON o.[schema_id] = s.[schema_id]
LEFT JOIN	sys.objects pk ON o.[object_id] = pk.parent_object_id
						  AND i.name = pk.name
						  AND pk.[type] = N''PK''
LEFT JOIN	(
			SELECT		ic.[object_id]
						,ic.index_id
						,[intColumns] = COUNT(*)
			FROM		sys.index_columns ic
			JOIN		sys.columns c ON ic.[object_id] = c.[object_id] AND ic.column_id = c.column_id
			##strColumnPats##
			WHERE		c.name LIKE ca4.strColumnPats
			GROUP BY	ic.[object_id]
						,ic.index_id
			HAVING		COUNT(*) >= (SELECT COUNT(*) FROM (VALUES(0)) tbl(intVal) CROSS APPLY (VALUES(N''%'')) ca4(strColumnPats))
			) c ON o.[object_id] = c.[object_id] AND i.index_id = c.index_id
CROSS APPLY	(
			SELECT	[indexType] =	CASE 
									WHEN pk.[object_id] IS NOT NULL THEN ''PK'' 
									WHEN i.is_unique = CAST(1 as bit) 
									AND  i.type_desc = N''CLUSTERED'' THEN N''UC'' 
									WHEN i.type_desc = N''CLUSTERED'' THEN N''NC''
									WHEN i.is_unique = CAST(1 as bit)  THEN N''UN''
									ELSE N''NN'' END
					,[strBeginDef] = CAST(CASE
									 WHEN pk.[object_id] IS NOT NULL 
									 THEN N''ALTER TABLE '' 
										+ s.name + N''.'' + o.name 
										+ N'' ADD CONSTRAINT '' + QUOTENAME(pk.name)
										+ N'' PRIMARY KEY ''
										+ i.type_desc
										+ N''(''
									 ELSE N''CREATE '' +	CASE i.is_unique 
														WHEN CAST(1 as bit) THEN N''UNIQUE'' 
														ELSE N'''' END 
													 + N'' '' 
													 + i.type_desc + N'' INDEX '' + QUOTENAME(i.name)
													 + NCHAR(13) 
													 + N''ON '' 
													 + s.name + N''.'' + o.name 
													 + N''('' 
									 END as nvarchar(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS
			) caVals
##strSchemaPats##
##strObjectPats##
CROSS APPLY	(
			SELECT	COUNT(*)
			FROM	(VALUES(0)) tbl(intVal)
			##strColumnPats##
			WHERE	ca4.strColumnPats <> N''%''
			) ca6(intColumns)
WHERE		s.name LIKE ca2.strSchemaPats
AND			o.name LIKE ca3.strObjectPats
AND			i.index_id > 0
AND			(
				ca6.intColumns = 0
			OR	c.intColumns >= ca6.intColumns
			OR	i.type_desc = N''CLUSTERED''
			)
AND   EXISTS(
			SELECT	0 
			FROM	(VALUES(0))tbl(intVal) 
			##strObjectTypes##
			WHERE	N''IX'' LIKE ca1.strObjectTypes
			OR		o.[type] LIKE ca1.strObjectTypes
			OR		pk.[type] LIKE ca1.strObjectTypes
			)
ORDER BY	1, 2;

DROP TABLE #sqlModules;
';

IF @strDBName > ''
	BEGIN
		WITH cteSplit
		AS	(
			SELECT	[strLength] = DATALENGTH(@strDBName)
					,[curPosition] = 0
					,[strDBName] = @strDBName
					,[strLetter] = CAST(NULL as char(1))
				UNION ALL
			SELECT	cS.strLength
					,cS.curPosition + 1
					,cS.strDBName
					,CAST(SUBSTRING(cS.strDBName, cS.curPosition + 1, 1) as char(1))
			FROM	cteSplit cS
			WHERE	cS.curPosition < cS.strLength
			)
		INSERT INTO @tblSplit
		SELECT	cS.curPosition, cS.strLength, cS.strLetter
		FROM	cteSplit cS
		WHERE	cS.curPosition BETWEEN 1 AND strLength;

		SELECT	@strDBName = d.name
		FROM	[master].sys.databases d
		WHERE	(
					d.name LIKE @strDBName
				OR	d.database_id IN 
					(
					SELECT		TOP 1 sD.database_id
					FROM		[master].sys.databases sD
					JOIN		@tblSplit tS ON CHARINDEX(tS.strPosition, sD.name) BETWEEN (tS.intPosition - (tS.intLength / 2)) AND (tS.intPosition + (tS.intLength / 2))
					GROUP BY	sD.database_id
					ORDER BY	COUNT(DISTINCT tS.strPosition) DESC, ABS((DATALENGTH(MIN(sD.name)) - MIN(tS.intLength)))
					)
				);
	END

PRINT @strDBName;

IF @boolSynCleanse = 1
	SELECT	@strSql = REPLACE(@strSql, '##SynCleanse##', tbl.strSynCleanse)
	FROM	(VALUES('INSERT INTO #sqlModules
SELECT		sM.[object_id]
			,COALESCE(OBJECT_DEFINITION(o.[object_id]), sM.[definition])
FROM		sys.schemas s
JOIN		sys.objects o ON s.[schema_id] = o.[schema_id]
LEFT JOIN	(
			SELECT		sM.[object_id]
						,[definition] = OBJECT_DEFINITION(sM.[object_id])
						,[intContains] = COUNT(*)
			FROM		sys.sql_modules sM
			##strContainsDef##
			WHERE		CHARINDEX(ca5.strContainsDef, sM.[definition]) > 0
			GROUP BY	sM.[object_id]
			HAVING		COUNT(*) >= (SELECT COUNT(*) FROM (VALUES(0)) tbl(intVal) ##strContainsDef##)
			) sM ON o.[object_id] = sM.[object_id]
##strObjectTypes##
##strSchemaPats##
##strObjectPats##
CROSS APPLY	(
			SELECT	COUNT(*)
			FROM	(VALUES(0)) tbl(intVal)
			##strContainsDef##
			WHERE	ca5.strContainsDef <> N''%''
			) ca7(intContains)
WHERE		o.[type] LIKE ca1.strObjectTypes
AND			s.name LIKE ca2.strSchemaPats
AND			o.name LIKE ca3.strObjectPats
AND			(
				ca7.intContains = 0
			OR	sM.intContains >= ca7.intContains
			)
AND   EXISTS(
			SELECT	0
			FROM	sys.synonyms sY
			JOIN	sys.schemas sC ON sY.[schema_id] = sC.[schema_id]
			WHERE	CHARINDEX(sC.name + N''.'' + sY.name, sM.[definition]) > 0
			);

DECLARE	lstSynCleanse CURSOR LOCAL READ_ONLY FAST_FORWARD
FOR	SELECT	sC.name + N''.'' + sY.name
			,sY.base_object_name
	FROM	sys.synonyms sY
	JOIN	sys.schemas sC ON sY.[schema_id] = sC.[schema_id]
	WHERE EXISTS(
				SELECT	0
				FROM	#sqlModules sM
				WHERE	CHARINDEX(sC.name + N''.'' + sY.name, sM.[definition]) > 0
				);

OPEN lstSynCleanse;
FETCH NEXT FROM lstSynCleanse
INTO @strSyn
	,@strSynDef;

WHILE @@FETCH_STATUS = 0
	BEGIN
		UPDATE	sM
		SET		[definition] = REPLACE([definition], @strSyn, @strSynDef)
		FROM	#sqlModules sM
		WHERE	CHARINDEX(@strSyn, sM.[definition]) > 0;
		
		FETCH NEXT FROM lstSynCleanse
		INTO @strSyn
			,@strSynDef;
	END;

CLOSE lstSynCleanse;
DEALLOCATE lstSynCleanse;')
		) tbl(strSynCleanse);
ELSE
	SELECT	@strSql = REPLACE(@strSql, '##SynCleanse##', '');


WITH cteSplit
AS	(
	SELECT	[intBegin] = 1
			,[intEnd] = CAST(COALESCE(NULLIF(CHARINDEX(strDelim, strSplit, 1), 0), intLength) as int)
			,[strValue] = SUBSTRING(strSplit, 1, COALESCE(NULLIF(CHARINDEX(strDelim, strSplit, 1), 0), intLength) - 1)
			,tbl.intLength
			,tbl.intDelim
			,tbl.strDelim
			,tbl.strSplit
			,[curPosition] = 1
	FROM	(
			SELECT	[intLength] = DATALENGTH(@strObjectTypes) + 1
					,[intDelim] = 1
					,[strDelim] = ','
					,[strSplit] = @strObjectTypes
			) tbl
				UNION ALL
	SELECT	[intBegin] = cS.intEnd + cS.intDelim
			,[intEnd] = CAST(COALESCE(NULLIF(CHARINDEX(cS.strDelim, cS.strSplit, cS.intEnd + cS.intDelim), 0), cS.intLength) as int)
			,[strValue] = SUBSTRING(cS.strSplit, cS.intEnd + cS.intDelim, COALESCE(NULLIF(CHARINDEX(cS.strDelim, cS.strSplit, cS.intEnd + cS.intDelim), 0), cS.intLength) - cS.intEnd - cS.intDelim)
			,cS.intLength
			,cS.intDelim
			,cS.strDelim
			,cS.strSplit
			,cS.curPosition + 1
	FROM	cteSplit cS
	WHERE	cS.intEnd < cS.intLength
	)
SELECT	@strSql = REPLACE(@strSql, '##strObjectTypes##', 
		'CROSS APPLY (VALUES'
	+	COALESCE(
		STUFF((
			SELECT	CASE ROW_NUMBER() OVER (ORDER BY cS.curPosition)
					WHEN 1 THEN '(N''' + cS.strValue + '%'')'
					ELSE ',(N''' + cS.strValue + '%'')' END 
			FROM	cteSplit cS
			WHERE	cS.strValue > ''
			FOR XML PATH('')
			), 1, 0, ''), '(N''%'')') + ') ca1(strObjectTypes)');

WITH cteSplit
AS	(
	SELECT	[intBegin] = 1
			,[intEnd] = CAST(COALESCE(NULLIF(CHARINDEX(strDelim, strSplit, 1), 0), intLength) as int)
			,[strValue] = SUBSTRING(strSplit, 1, COALESCE(NULLIF(CHARINDEX(strDelim, strSplit, 1), 0), intLength) - 1)
			,tbl.intLength
			,tbl.intDelim
			,tbl.strDelim
			,tbl.strSplit
			,[curPosition] = 1
	FROM	(
			SELECT	[intLength] = DATALENGTH(@strObjectPats) + 1
					,[intDelim] = 1
					,[strDelim] = ','
					,[strSplit] = @strObjectPats
			) tbl
				UNION ALL
	SELECT	[intBegin] = cS.intEnd + cS.intDelim
			,[intEnd] = CAST(COALESCE(NULLIF(CHARINDEX(cS.strDelim, cS.strSplit, cS.intEnd + cS.intDelim), 0), cS.intLength) as int)
			,[strValue] = SUBSTRING(cS.strSplit, cS.intEnd + cS.intDelim, COALESCE(NULLIF(CHARINDEX(cS.strDelim, cS.strSplit, cS.intEnd + cS.intDelim), 0), cS.intLength) - cS.intEnd - cS.intDelim)
			,cS.intLength
			,cS.intDelim
			,cS.strDelim
			,cS.strSplit
			,cS.curPosition + 1
	FROM	cteSplit cS
	WHERE	cS.intEnd < cS.intLength
	)
INSERT INTO @tblObjectPats
	(strOriginal, strSchema, strObject)
SELECT	cS.strValue
		,[strSchemaPat] = LEFT(cS.strValue, NULLIF(PATINDEX('%[A-Z0-9].%', cS.strValue), 0))
		,[strObjectPat] = RIGHT(cS.strValue, COALESCE(NULLIF(PATINDEX('%[A-Z0-9].%', REVERSE(cS.strValue)), 0), LEN(cS.strValue)))
FROM	cteSplit cS
WHERE	cS.strValue > '';

SELECT	@strSchemaPats = REPLACE(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(strSchemaPats, ',', ' '), ' ', '><'), '<>', ''), '><', ' '))), ''), ' ', ',')
		,@strObjectPats = REPLACE(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(strObjectPats, ',', ' '), ' ', '><'), '<>', ''), '><', ' '))), ''), ' ', ',')
FROM	(
		SELECT	strSchemaPats = COALESCE(@strSchemaPats, '') + COALESCE((SELECT DISTINCT ', ' + strSchema FROM @tblObjectPats WHERE strSchema > '' FOR XML PATH(''), TYPE).value('.', 'nvarchar(MAX)'), '')
				,strObjectPats = (SELECT DISTINCT ', ' + strObject FROM @tblObjectPats WHERE strObject > '' FOR XML PATH(''), TYPE).value('.', 'nvarchar(MAX)')
		) tbl(strSchemaPats, strObjectPats);

WITH cteSplit
AS	(
	SELECT	[intBegin] = 1
			,[intEnd] = CAST(COALESCE(NULLIF(CHARINDEX(strDelim, strSplit, 1), 0), intLength) as int)
			,[strValue] = SUBSTRING(strSplit, 1, COALESCE(NULLIF(CHARINDEX(strDelim, strSplit, 1), 0), intLength) - 1)
			,tbl.intLength
			,tbl.intDelim
			,tbl.strDelim
			,tbl.strSplit
			,[curPosition] = 1
	FROM	(
			SELECT	[intLength] = DATALENGTH(@strSchemaPats) + 1
					,[intDelim] = 1
					,[strDelim] = ','
					,[strSplit] = @strSchemaPats
			) tbl
				UNION ALL
	SELECT	[intBegin] = cS.intEnd + cS.intDelim
			,[intEnd] = CAST(COALESCE(NULLIF(CHARINDEX(cS.strDelim, cS.strSplit, cS.intEnd + cS.intDelim), 0), cS.intLength) as int)
			,[strValue] = SUBSTRING(cS.strSplit, cS.intEnd + cS.intDelim, COALESCE(NULLIF(CHARINDEX(cS.strDelim, cS.strSplit, cS.intEnd + cS.intDelim), 0), cS.intLength) - cS.intEnd - cS.intDelim)
			,cS.intLength
			,cS.intDelim
			,cS.strDelim
			,cS.strSplit
			,cS.curPosition + 1
	FROM	cteSplit cS
	WHERE	cS.intEnd < cS.intLength
	)
SELECT	@strSql = REPLACE(@strSql, '##strSchemaPats##', 
		'CROSS APPLY (VALUES'
	+	COALESCE(
		STUFF((
			SELECT	CASE ROW_NUMBER() OVER (ORDER BY cS.curPosition)
					WHEN 1 THEN '(N''' + cS.strValue + '%'')'
					ELSE ',(N''' + cS.strValue + '%'')' END 
			FROM	cteSplit cS
			WHERE	cS.strValue > ''
			FOR XML PATH('')
			), 1, 0, ''), '(N''%'')') + ') ca2(strSchemaPats)');

WITH cteSplit
AS	(
	SELECT	[intBegin] = 1
			,[intEnd] = CAST(COALESCE(NULLIF(CHARINDEX(strDelim, strSplit, 1), 0), intLength) as int)
			,[strValue] = SUBSTRING(strSplit, 1, COALESCE(NULLIF(CHARINDEX(strDelim, strSplit, 1), 0), intLength) - 1)
			,tbl.intLength
			,tbl.intDelim
			,tbl.strDelim
			,tbl.strSplit
			,[curPosition] = 1
	FROM	(
			SELECT	[intLength] = DATALENGTH(@strObjectPats) + 1
					,[intDelim] = 1
					,[strDelim] = ','
					,[strSplit] = @strObjectPats
			) tbl
				UNION ALL
	SELECT	[intBegin] = cS.intEnd + cS.intDelim
			,[intEnd] = CAST(COALESCE(NULLIF(CHARINDEX(cS.strDelim, cS.strSplit, cS.intEnd + cS.intDelim), 0), cS.intLength) as int)
			,[strValue] = SUBSTRING(cS.strSplit, cS.intEnd + cS.intDelim, COALESCE(NULLIF(CHARINDEX(cS.strDelim, cS.strSplit, cS.intEnd + cS.intDelim), 0), cS.intLength) - cS.intEnd - cS.intDelim)
			,cS.intLength
			,cS.intDelim
			,cS.strDelim
			,cS.strSplit
			,cS.curPosition + 1
	FROM	cteSplit cS
	WHERE	cS.intEnd < cS.intLength
	)
SELECT	@strSql = REPLACE(@strSql, '##strObjectPats##', 
		'CROSS APPLY (VALUES'
	+	COALESCE(
		STUFF((
			SELECT	CASE ROW_NUMBER() OVER (ORDER BY cS.curPosition)
					WHEN 1 THEN '(N''' + cS.strValue + '%'')'
					ELSE ',(N''' + cS.strValue + '%'')' END 
			FROM	cteSplit cS
			WHERE	cS.strValue > ''
			FOR XML PATH('')
			), 1, 0, ''), '(N''%'')') + ') ca3(strObjectPats)');

WITH cteSplit
AS	(
	SELECT	[intBegin] = 1
			,[intEnd] = CAST(COALESCE(NULLIF(CHARINDEX(strDelim, strSplit, 1), 0), intLength) as int)
			,[strValue] = SUBSTRING(strSplit, 1, COALESCE(NULLIF(CHARINDEX(strDelim, strSplit, 1), 0), intLength) - 1)
			,tbl.intLength
			,tbl.intDelim
			,tbl.strDelim
			,tbl.strSplit
			,[curPosition] = 1
	FROM	(
			SELECT	[intLength] = DATALENGTH(@strColumnPats) + 1
					,[intDelim] = 1
					,[strDelim] = ','
					,[strSplit] = @strColumnPats
			) tbl
				UNION ALL
	SELECT	[intBegin] = cS.intEnd + cS.intDelim
			,[intEnd] = CAST(COALESCE(NULLIF(CHARINDEX(cS.strDelim, cS.strSplit, cS.intEnd + cS.intDelim), 0), cS.intLength) as int)
			,[strValue] = SUBSTRING(cS.strSplit, cS.intEnd + cS.intDelim, COALESCE(NULLIF(CHARINDEX(cS.strDelim, cS.strSplit, cS.intEnd + cS.intDelim), 0), cS.intLength) - cS.intEnd - cS.intDelim)
			,cS.intLength
			,cS.intDelim
			,cS.strDelim
			,cS.strSplit
			,cS.curPosition + 1
	FROM	cteSplit cS
	WHERE	cS.intEnd < cS.intLength
	)
SELECT	@strSql = REPLACE(@strSql, '##strColumnPats##', 
		'CROSS APPLY (VALUES'
	+	COALESCE(
		STUFF((
			SELECT	CASE ROW_NUMBER() OVER (ORDER BY cS.curPosition)
					WHEN 1 THEN '(N''' + cS.strValue + '%'')'
					ELSE ',(N''' + cS.strValue + '%'')' END 
			FROM	cteSplit cS
			WHERE	cS.strValue > ''
			FOR XML PATH('')
			), 1, 0, ''), '(N''%'')') + ') ca4(strColumnPats)');

WITH cteSplit
AS	(
	SELECT	[intBegin] = 1
			,[intEnd] = CAST(COALESCE(NULLIF(CHARINDEX(strDelim, strSplit, 1), 0), intLength) as int)
			,[strValue] = SUBSTRING(strSplit, 1, COALESCE(NULLIF(CHARINDEX(strDelim, strSplit, 1), 0), intLength) - 1)
			,tbl.intLength
			,tbl.intDelim
			,tbl.strDelim
			,tbl.strSplit
			,[curPosition] = 1
	FROM	(
			SELECT	[intLength] = DATALENGTH(@strContainsDef) + 1
					,[intDelim] = 1
					,[strDelim] = ','
					,[strSplit] = @strContainsDef
			) tbl
				UNION ALL
	SELECT	[intBegin] = cS.intEnd + cS.intDelim
			,[intEnd] = CAST(COALESCE(NULLIF(CHARINDEX(cS.strDelim, cS.strSplit, cS.intEnd + cS.intDelim), 0), cS.intLength) as int)
			,[strValue] = SUBSTRING(cS.strSplit, cS.intEnd + cS.intDelim, COALESCE(NULLIF(CHARINDEX(cS.strDelim, cS.strSplit, cS.intEnd + cS.intDelim), 0), cS.intLength) - cS.intEnd - cS.intDelim)
			,cS.intLength
			,cS.intDelim
			,cS.strDelim
			,cS.strSplit
			,cS.curPosition + 1
	FROM	cteSplit cS
	WHERE	cS.intEnd < cS.intLength
	)
SELECT	@strSql = REPLACE(@strSql, '##strContainsDef##', 
		'CROSS APPLY (VALUES'
	+	COALESCE(
		STUFF((
			SELECT	CASE ROW_NUMBER() OVER (ORDER BY cS.curPosition)
					WHEN 1 THEN '(N''' + cS.strValue + ''')'
					ELSE ',(N''' + cS.strValue + ''')' END 
			FROM	cteSplit cS
			WHERE	cS.strValue > ''
			FOR XML PATH('')
			), 1, 0, ''), '(N''%'')') + ') ca5(strContainsDef)');

PRINT CAST(@strSql as ntext);

IF @strSQL <> '' AND COALESCE(@strDBName,'')  = ''
	BEGIN
		DECLARE lstDatabases CURSOR LOCAL READ_ONLY FAST_FORWARD
		FOR	SELECT d.name FROM sys.databases d WHERE d.name NOT IN (N'tempdb',N'master',N'model',N'msdb');

		OPEN lstDatabases;
		FETCH NEXT FROM lstDatabases
		INTO @strDBName;

		WHILE @@FETCH_STATUS = 0
			BEGIN
				SELECT	@strSql = REPLACE(@strSql, '?', @strDBName);

				BEGIN TRY
					INSERT INTO @tblResults
					EXEC(@strSql);
				END TRY

				BEGIN CATCH

				END CATCH

				SELECT	@strSql = REPLACE(@strSql, QUOTENAME(@strDBName), N'[?]');

				FETCH NEXT FROM lstDatabases
				INTO @strDBName;
			END

		CLOSE lstDatabases;
		DEALLOCATE lstDatabases;
	END
ELSE IF @strSQL <> ''
	BEGIN
		SELECT	@strSQL = REPLACE(@strSql,'[?]',QUOTENAME(@strDBName));
		INSERT INTO @tblResults
		EXEC (@strSQL);
	END

SELECT		[Database]
			,[Object]
			,[parentObject]
			,[Type] = tT.ObjectDesc
			,tR.strDefinition
			,[xmlDefinition] = (SELECT [processing-instruction(q)] = ':' + NCHAR(13) + tR.strDefinition + NCHAR(13) FOR XML PATH(''), TYPE)
FROM		@tblResults tR
LEFT JOIN	(
			VALUES	('C', 'Check Constraint')
					,('D', 'Default Constraint')
					,('F', 'Foreign Key Constraint')
					,('FN', 'Scalar Function')
					,('IF', 'Inline Table-Valued Function')
					,('IT', 'Internal Table')
					,('NC', 'Non-Unique Clustered Index')
					,('NN', 'Non-Unique Nonclustered Index')
					,('P', 'Stored Procedure')
					,('PK', 'Primary Key')
					,('S', 'System Table')
					,('SN', 'Synonym')
					,('SQ', 'Service Queue')
					,('TF', 'Table-Valued Function')
					,('TR', 'SQL Trigger')
					,('TT', 'Type Table')
					,('U', 'User Table')
					,('UC', 'Unique Clustered Index')
					,('UN', 'Unique Non-Clustered Index')
					,('UQ', 'Unique Constraint')
					,('V', 'View')
			) tT(ObjectType, ObjectDesc) ON tR.ObjectType = tT.ObjectType;

SET NOCOUNT OFF;