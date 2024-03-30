import gleam/pgo
import gleam/option.{type Option, None, Some}
import gleam/result.{map_error, try}
import gleam/dynamic
import gleam/list
import pgo_driver

pub type TestQuery {
  TestQuery(
    bool_col: Option(Bool),
    bytea_col: Option(BitArray),
    float_col: Option(Float),
    id: Int,
    int_col: Option(Int),
    str_col: Option(String),
  )
}

pub fn test_query(conn: pgo.Connection, str_col: Option(String),id: Int) {
  let query = "select * from test_table where str_col = $1 and id = $2"

  let arg_str_col = case str_col {
    Some(a) -> pgo.text(a)
    None -> pgo.null() 
}
  let arg_id = pgo.int(id)

  let encoded_args = [arg_str_col,arg_id]

  use response <- try(
    pgo.execute(query, conn, encoded_args, dynamic.dynamic)
    |> map_error(pgo_driver.QueryError)
  )

  response.rows |> list.try_map(fn (row) {
    use col_id <- try(pgo_driver.parse_col(row, 0, dynamic.int))
    use col_str_col <- try(pgo_driver.parse_col(row, 1, dynamic.optional(dynamic.string)))
    use col_int_col <- try(pgo_driver.parse_col(row, 2, dynamic.optional(dynamic.int)))
    use col_bool_col <- try(pgo_driver.parse_col(row, 3, dynamic.optional(dynamic.bool)))
    use col_float_col <- try(pgo_driver.parse_col(row, 4, dynamic.optional(dynamic.float)))
    use col_bytea_col <- try(pgo_driver.parse_col(row, 5, dynamic.optional(dynamic.bit_array)))

    Ok(
      TestQuery(
        bool_col: col_bool_col,
        bytea_col: col_bytea_col,
        float_col: col_float_col,
        id: col_id,
        int_col: col_int_col,
        str_col: col_str_col
    ))
  })}                                                                                                                                                                  
