USE Utility;
GO

IF OBJECT_ID(N'dbo.fn_splitByDelim') IS NOT NULL
	DROP FUNCTION dbo.fn_splitByDelim;
GO

CREATE FUNCTION dbo.fn_splitByDelim
	(
	@strSplit varchar(MAX)
	,@strDelim varchar(10)
	)
RETURNS TABLE
AS
RETURN	(
		WITH cteSplit
		AS	(
			SELECT	[intBegin] = 1
					,[intEnd] = CAST(COALESCE(NULLIF(CHARINDEX(strDelim, strSplit, 1), 0), intLength) as int)
					,[strValue] = SUBSTRING(strSplit, 1, COALESCE(NULLIF(CHARINDEX(strDelim, strSplit, 1), 0), intLength) - 1)
					,tbl.intLength
					,tbl.intDelim
					,tbl.strDelim
					,tbl.strSplit
					,[intId] = 1
			FROM	(
					SELECT	[intLength] = DATALENGTH(@strSplit) + 1
							,[intDelim] = 1
							,[strDelim] = @strDelim
							,[strSplit] = @strSplit
					) tbl
						UNION ALL
			SELECT	[intBegin] = cS.intEnd + cS.intDelim
					,[intEnd] = CAST(COALESCE(NULLIF(CHARINDEX(cS.strDelim, cS.strSplit, cS.intEnd + cS.intDelim), 0), cS.intLength) as int)
					,[strValue] = SUBSTRING(cS.strSplit, cS.intEnd + cS.intDelim, COALESCE(NULLIF(CHARINDEX(cS.strDelim, cS.strSplit, cS.intEnd + cS.intDelim), 0), cS.intLength) - cS.intEnd - cS.intDelim)
					,cS.intLength
					,cS.intDelim
					,cS.strDelim
					,cS.strSplit
					,[intId] = cS.intId + 1
			FROM	cteSplit cS
			WHERE	cS.intEnd < cS.intLength
			)
		SELECT	strValue
				,intId
		FROM	cteSplit
		);

GO