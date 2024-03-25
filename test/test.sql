
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
