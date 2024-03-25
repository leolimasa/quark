import gleam/pgo
import gleeunit/should
import sql
import gleam/option.{Some}
import gleam/dict

pub fn query_cols_test() {
  let db =
    pgo.connect(
      pgo.Config(
        ..pgo.default_config(),
        host: "localhost",
        database: "testdb",
        user: "test",
        password: Some("test"),
        port: 55_123,
      ),
    )

  let discard_result = fn(_) { Ok(Nil) }
  let assert Ok(_) = pgo.execute("drop table if exists test_table", db, [], discard_result)
  let sql =
    "
    create table test_table (
       id bigserial primary key,
       str_col text not null,
       int_col int,
       bool_col boolean,
       float_col float,
       bytea_col bytea 
    )
  "

  let assert Ok(_) = pgo.execute(sql, db, [], discard_result)

  let sql = "select * from test_table"
  let assert Ok(cols) = sql.select_cols(db, sql, [])
  let expected = dict.new()
    |> dict.insert("bool_col", sql.SqlCol(name: "bool_col", type_: sql.SqlBoolean, nullable: True, pos: 1))
    |> dict.insert("bytea_col", sql.SqlCol(name: "bytea_col", type_: sql.SqlBytea, nullable: True, pos: 2))
    |> dict.insert("float_col", sql.SqlCol(name: "float_col", type_: sql.SqlFloat, nullable: True, pos: 3))
    |> dict.insert("id", sql.SqlCol(name: "id", type_: sql.SqlInt, nullable: True, pos: 4))
    |> dict.insert("int_col", sql.SqlCol(name: "int_col", type_: sql.SqlInt, nullable: True, pos: 5))
    |> dict.insert("str_col", sql.SqlCol(name: "str_col", type_: sql.SqlText, nullable: False, pos: 6))
  should.equal(cols, expected)    
}
