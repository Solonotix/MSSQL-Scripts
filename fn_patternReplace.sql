use Utility;

if exists(select * from sys.objects where [object_id] = OBJECT_ID(N'dbo.fn_patternReplace'))
	drop function dbo.fn_patternReplace;
go

create function dbo.fn_patternReplace
	(@strInput varchar(max), @strPattern varchar(max), @strReplace varchar(max))
returns varchar(max)
as
	begin
		if charindex('%', @strPattern) != 1
			select
				@strPattern = '%' + @strPattern;

		if charindex('%', reverse(@strPattern)) != 1
			select
				@strPattern = @strPattern + '%';

		if @strPattern not like '[%][\[]%[\]][%]' escape '\'
			select
				@strInput = @strInput;
		else
			begin
				if charindex(@strReplace, @strPattern) = 0
					select
						@strPattern = stuff(@strPattern, len(@strPattern) - 1, 0, '^' + @strReplace);

				while patindex(@strPattern, @strInput) > 0
					select
						@strInput = stuff(@strInput, patindex(@strPattern, @strInput), 1, @strReplace);
				select
					@strInput = replace(replace(replace(@strInput, @strReplace, '!><!'), '<!!>', ''), '!><!', @strReplace);
			end;

		return
		--select
			@strInput;
	end;
go

select
	dbo.fn_patternReplace('This  Is <>>>< a Test', '%[^A-Z^0-9]%', '_');