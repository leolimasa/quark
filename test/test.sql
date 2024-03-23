
-- @quark.select 
-- fun employees_by_dept(dept_id: Int)
select * from company.employee where dept_id = :dept_id
-- @end

-- @quark.insert
-- fn create_employee(name: String)
insert into employee (name) values (:name)

-- @quark.insert create_employees(a)
-- TODO

-- @quark update
-- @quark update-all


