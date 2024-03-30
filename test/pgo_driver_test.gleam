import gleam/pgo
import gleeunit/should
import sql
import gleam/option.{Some}
import gleam/dict
import pgo_driver
import driver
import gleam/io

fn setup() -> pgo.Connection {
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
  let assert Ok(_) =
    pgo.execute("drop table if exists test_table", db, [], discard_result)
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
  db
}

pub fn query_cols_test() {
  let db = setup()

  let sql = "select * from test_table"
  let cols = pgo_driver.select_cols(db, sql)
  let assert Ok(cols) = cols
  let expected =
    dict.new()
    |> dict.insert(
      "id",
      sql.SqlCol(name: "id", type_: sql.SqlInt, nullable: True, pos: 0),
    )
    |> dict.insert(
      "str_col",
      sql.SqlCol(name: "str_col", type_: sql.SqlText, nullable: True, pos: 1),
    )
    |> dict.insert(
      "int_col",
      sql.SqlCol(name: "int_col", type_: sql.SqlInt, nullable: True, pos: 2),
    )
    |> dict.insert(
      "bool_col",
      sql.SqlCol(
        name: "bool_col",
        type_: sql.SqlBoolean,
        nullable: True,
        pos: 3,
      ),
    )
    |> dict.insert(
      "float_col",
      sql.SqlCol(name: "float_col", type_: sql.SqlFloat, nullable: True, pos: 4),
    )
    |> dict.insert(
      "bytea_col",
      sql.SqlCol(name: "bytea_col", type_: sql.SqlBytea, nullable: True, pos: 5),
    )
  should.equal(cols, expected)
}

pub fn generate_select_function_test() {
  let db = setup()

  let assert Ok(select_fn) =
    pgo_driver.generate_select_function(
      db,
      driver.SelectParams(
        name: "test_query",
        query: "select * from test_table where str_col = :str_col and id = :id",
        args: [
          sql.SqlCol(
            name: "str_col",
            type_: sql.SqlText,
            nullable: True,
            pos: 0,
          ),
          sql.SqlCol(
            name: "id",
            type_: sql.SqlInt,
            nullable: False,
            pos: 0,
          ),
        ],
        not_null: ["id"],
      ),
    )

  // best way to update this monster is to just write it out to terminal in a main function somewhere then paste here.
  let expected = "pub type TestQuery {\n  TestQuery(\n    bool_col: Option(Bool),\n    bytea_col: Option(BitArray),\n    float_col: Option(Float),\n    id: Int,\n    int_col: Option(Int),\n    str_col: Option(String),\n  )\n}\n\npub fn test_query(conn: pgo.Connection, str_col: Option(String),id: Int) {\n  let query = \"select * from test_table where str_col = $1 and id = $2\"\n\n  let arg_str_col = case str_col{\n    Some(a) -> pgo.text(a)\n    None -> pgo.null() \n}\n  let arg_id = pgo.int(id)\n\n  let encoded_args = [arg_str_col,arg_id]\n\n  use response <- try(\n    pgo.execute(query, conn, encoded_args, dynamic.dynamic)\n    |> map_error(pgo_driver.QueryError)\n  )\n\n  response.rows |> list.try_map(fn (row) {\n    use col_id <- try(pgo_driver.parse_col(row, 0, dynamic.int))\n    use col_str_col <- try(pgo_driver.parse_col(row, 1, dynamic.optional(dynamic.string)))\n    use col_int_col <- try(pgo_driver.parse_col(row, 2, dynamic.optional(dynamic.int)))\n    use col_bool_col <- try(pgo_driver.parse_col(row, 3, dynamic.optional(dynamic.bool)))\n    use col_float_col <- try(pgo_driver.parse_col(row, 4, dynamic.optional(dynamic.float)))\n    use col_bytea_col <- try(pgo_driver.parse_col(row, 5, dynamic.optional(dynamic.bit_array)))\n\n    Ok(\n      TestQuery(\n        bool_col: col_bool_col,\n        bytea_col: col_bytea_col,\n        float_col: col_float_col,\n        id: col_id,\n        int_col: col_int_col,\n        str_col: col_str_col\n    ))\n  })}"
  should.equal(select_fn, expected)
}
