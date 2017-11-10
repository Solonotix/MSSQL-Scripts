use Utility;
go

if exists(select * from sys.objects where [object_id] = OBJECT_ID(N'dbo.fn_indexDetails'))
	drop function dbo.fn_indexDetails;
go

create function dbo.fn_indexDetails
	(@object_id int, @index_id int)
returns table
return
	with cteIndexColumns
	as	(
		select
			[table_name] = concat(quotename(s.[name]), N'.', quotename(o.[name])),
			[index_name] = quotename(i.[name]),
			[column_list] = cast(c.[name] + case ic.is_descending_key when 1 then N' desc' else N'' end as varchar(max)),
			[include_list] = cast(null as varchar(max)),
			ic.[object_id],
			ic.[index_id],
			ic.key_ordinal,
			ca.final_key,
			ca.min_include,
			ca.max_include
		from
			sys.schemas s
			inner join sys.objects o on
				s.[schema_id] = o.[schema_id]
			inner join sys.indexes i on
				o.[object_id] = i.[object_id]
			inner join sys.index_columns ic on
				i.[object_id] = ic.[object_id] and
				i.index_id = ic.index_id
			inner join sys.columns c on
				ic.[object_id] = c.[object_id] and
				ic.column_id = c.column_id
			cross apply (
				select
					[start_key] = min(case sic.is_included_column when 0 then sic.key_ordinal end),
					[final_key] = max(sic.key_ordinal),
					[min_include] = min(case sic.is_included_column when 1 then sic.index_column_id end),
					[max_include] = max(case sic.is_included_column when 1 then sic.index_column_id end)
				from
					sys.index_columns sic
				where
					ic.[object_id] = sic.[object_id] and
					ic.index_id = sic.index_id
				) ca
		where
			o.[object_id] = @object_id and
			(@index_id is null or i.index_id = @index_id) and
			ic.key_ordinal = ca.start_key
			union all
		select
			cic.table_name,
			cic.index_name,
			[column_list] = cast(cic.column_list + N', ' + c.[name] + case ic.is_descending_key when 1 then N' desc' else N'' end as varchar(max)),
			cic.include_list,
			cic.[object_id],
			cic.[index_id],
			ic.key_ordinal,
			cic.final_key,
			cic.min_include,
			cic.max_include
		from
			cteIndexColumns cic
			inner join sys.index_columns ic on
				cic.[object_id] = ic.[object_id] and
				cic.index_id = ic.index_id and
				cic.key_ordinal + 1 = ic.key_ordinal
			inner join sys.columns c on
				ic.[object_id] = c.[object_id] and
				ic.column_id = c.column_id
			union all
		select
			cic.table_name,
			cic.index_name,
			cic.column_list,
			[include_list] = cast(coalesce(cic.include_list + N', ', N'') + c.[name] as varchar(max)),
			cic.[object_id],
			cic.index_id,
			cic.key_ordinal,
			cic.final_key,
			[min_include] = ic.index_column_id + 1,
			cic.max_include
		from
			cteIndexColumns cic
			inner join sys.index_columns ic on
				cic.[object_id] = ic.[object_id] and
				cic.index_id = ic.index_id
			inner join sys.columns c on
				ic.[object_id] = c.[object_id] and
				ic.[column_id] = c.[column_id]
		where
			cic.key_ordinal = cic.final_key and
			ic.is_included_column = 1 and
			ic.index_column_id between cic.min_include and cic.max_include
		)
	select
		table_name,
		index_name,
		[indexed_columns] = column_list,
		[included_columns] = include_list
	from
		cteIndexColumns cic
	where
		cic.key_ordinal = cic.final_key;
go

select
	*
from
	dbo.fn_indexDetails(OBJECT_ID(N'qa.session_list_detail_keys'), null);

select
	case 1 
	when is_primary_key then concat(N'alter table ', quotename(s.[name]), N'.', quotename(o.[name]), N' add primary key ', lower(i.[type_desc]), N'(', id.indexed_columns, N');') 
	when is_unique | is_unique_constraint then N'create unique ' + lower(i.[type_desc]) + N' index ' + id.index_name + N' on ' + id.table_name + N' (' + id.indexed_columns + ')' + coalesce(' include (' + nullif(id.included_columns, '') + ');', ';')
	else N'create ' + lower(i.[type_desc]) + N' index ' + id.index_name + N' on ' + id.table_name + N' (' + id.indexed_columns + ')' + coalesce(' include (' + nullif(id.included_columns, '') + ');', ';') end collate Latin1_General_CI_AS_KS_WS,
	[table_name] = concat(quotename(s.[name]), N'.', quotename(o.[name])),
	[index_name] = quotename(i.[name]),
	[index_type] = i.[type_desc],
	[key_constraint_type] = k.[type_desc]
from
	sys.indexes i
	inner join sys.objects o on
		i.[object_id] = o.[object_id]
	inner join sys.schemas s on
		o.[schema_id] = s.[schema_id]
	left join sys.key_constraints k on
		i.[object_id] = k.parent_object_id and
		i.[name] = k.[name]
	cross apply dbo.fn_indexDetails(i.[object_id], i.[index_id]) id
where
	i.[object_id] = OBJECT_ID(N'qa.session_list_detail_keys');

--select * from RRS_DB20_DataMart.sys.index_columns where [object_id] = OBJECT_ID(N'RRS_DB20_DataMart.datamart.di_customer')
