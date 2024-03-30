
-- @quark.select 
-- fun employees_by_dept(dept_id: Int)
select * from company.employee where dept_id = :dept_id
-- @end

create table test_table (
   id bigserial primary key,
   str_col text not null,
   int_col int,
   bool_col boolean,
   float_col float,
   bytea_col bytea 
);

begin;

create table _query_types as
   select * from test_table;

SELECT column_name::text, data_type::text, ordinal_position, is_nullable
FROM information_schema.columns 
WHERE table_name = '_query_types'
order by ordinal_position;
BEGIN
SELECT 0
 column_name |    data_type     | ordinal_position | is_nullable 
-------------+------------------+------------------+-------------
 id          | bigint           |                1 | YES
 str_col     | text             |                2 | YES
 int_col     | integer          |                3 | YES
 bool_col    | boolean          |                4 | YES
 float_col   | double precision |                5 | YES
 bytea_col   | bytea            |                6 | YES
(6 rows)

