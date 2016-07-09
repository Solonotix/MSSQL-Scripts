IF EXISTS(
		SELECT	0
		FROM	sys.objects
		WHERE	[object_id] = OBJECT_ID(N'dbo.NewSeqID') AND
				OBJECTPROPERTY([object_id],'isScalarFunction') = 1
		 )
	DROP FUNCTION dbo.NewSeqID
GO

CREATE FUNCTION dbo.NewSeqID
	(@inputSeed uniqueidentifier = '00000000-0000-0000-0000-000000000000')
RETURNS uniqueidentifier
AS
	BEGIN
		DECLARE	--@inputSeed uniqueidentifier,
				@outputSeed uniqueidentifier,
				@iSegment1 varbinary(4),
				@iSegment2 varbinary(2),
				@iSegment3 varbinary(2),
				@iSegment4 varbinary(2),
				@iSegment5 varbinary(2),
				@iSegment6 varbinary(4),
				@oSegment1 varbinary(4),
				@oSegment2 varbinary(2),
				@oSegment3 varbinary(2),
				@oSegment4 varbinary(2),
				@oSegment5 varbinary(2),
				@oSegment6 varbinary(4)

		SELECT	@iSegment1 = CONVERT(varbinary(4),LEFT(CONVERT(varchar(60),@inputSeed,2),8),2),
				@iSegment2 = CONVERT(varbinary(2),SUBSTRING(CONVERT(varchar(60),@inputSeed,2),10,4),2),
				@iSegment3 = CONVERT(varbinary(2),SUBSTRING(CONVERT(varchar(60),@inputSeed,2),15,4),2),
				@iSegment4 = CONVERT(varbinary(2),SUBSTRING(CONVERT(varchar(60),@inputSeed,2),20,4),2),
				@iSegment5 = CONVERT(varbinary(2),SUBSTRING(CONVERT(varchar(60),@inputSeed,2),25,4),2),
				@iSegment6 = CONVERT(varbinary(4),RIGHT(CONVERT(varchar(60),@inputSeed,2),8),2)

		SELECT	@oSegment6 = CAST(@iSegment6 + 1 as varbinary(4))
		SELECT	@oSegment5 = CASE WHEN @iSegment6 <> 0x00000000 AND @oSegment6 = 0x00000000
								  THEN CAST(@iSegment5 + 1 as varbinary(2))
								  ELSE @iSegment5 END
		SELECT	@oSegment4 = CASE WHEN @iSegment5 <> 0x0000 AND @oSegment5 = 0x0000
								  THEN CAST(@iSegment4 + 1 as varbinary(2))
								  ELSE @iSegment4 END
		SELECT	@oSegment3 = CASE WHEN @iSegment4 <> 0x0000 AND @oSegment4 = 0x0000
								  THEN CAST(@iSegment3 + 1 as varbinary(2))
								  ELSE @iSegment3 END
		SELECT	@oSegment2 = CASE WHEN @iSegment3 <> 0x0000 AND @oSegment3 = 0x0000
								  THEN CAST(@iSegment2 + 1 as varbinary(2))
								  ELSE @iSegment2 END
		SELECT	@oSegment1 = CASE WHEN @iSegment2 <> 0x0000 AND @oSegment2 = 0x0000
								  THEN CAST(@iSegment1 + 1 as varbinary(4))
								  ELSE @iSegment1 END

		SELECT	@outputSeed = CONCAT(
									 CONVERT(varchar(8),@oSegment1,2),'-',CONVERT(varchar(4),@oSegment2,2),'-',
									 CONVERT(varchar(4),@oSegment3,2),'-',CONVERT(varchar(4),@oSegment4,2),'-',
									 CONVERT(varchar(4),@oSegment5,2),CONVERT(varchar(8),@oSegment6,2)
									)

		RETURN	@outputSeed
	END
GO