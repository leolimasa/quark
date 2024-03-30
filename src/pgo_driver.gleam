import sql
import gleam/pgo
import gleam/dict.{type Dict}
import gleam/result.{map_error, try}
import gleam/dynamic
import gleam/list
import gleam/string
import gleam/int
import justin
import gleam/io
import gleam/option
import driver.{type GenerateError, type SelectParams, SetNotNullError, SqlError}

// Used during runtime
pub type PgoFunctionError {
  QueryError(pgo.QueryError)
  DecodeError(List(dynamic.DecodeError))
}

// Used during runtime
pub fn parse_col(row, pos, type_) {
  dynamic.element(pos, type_)(row)
  |> map_error(DecodeError)
}

fn col_to_pgo(col: sql.SqlCol) {
  case col.type_ {
    sql.SqlBoolean -> "pgo.bool(" <> col.name <> ")"
    sql.SqlInt -> "pgo.int(" <> col.name <> ")"
    sql.SqlBytea -> "pgo.bytea(" <> col.name <> ")"
    sql.SqlFloat -> "pgo.float(" <> col.name <> ")"
    sql.SqlText -> "pgo.text(" <> col.name <> ")"
  }
}

fn return_type_name(name: String) {
  name
  |> string.replace("_", " ")
  |> justin.pascal_case
}

fn select_function_return_type(name: String, cols: List(sql.SqlCol)) {
  let name = return_type_name(name)

  let fields =
    cols
    |> list.map(fn(col) {
      let type_ = sql.col_to_gleam_type(col)
      "    " <> col.name <> ": " <> type_ <> ",\n"
    })
    |> string.join("")

  "pub type "
  <> name
  <> " {\n"
  <> "  "
  <> name
  <> "(\n"
  <> fields
  <> "  )\n"
  <> "}\n"
}

fn select_function_body(
  fun_name: String,
  query: String,
  args: List(sql.SqlCol),
  returns: Dict(String, sql.SqlCol),
) {
  // Generates the function arguments and their types
  let fun_args =
    args
    |> list.map(fn(arg) { arg.name <> ": " <> sql.col_to_gleam_type(arg) })
    |> string.join(",")

  // Generates the variables that will decode the columns returned by the query
  let field_decoder =
    dict.values(returns)
    |> list.sort(fn(a, b) { int.compare(a.pos, b.pos) })
    |> list.map(fn(field) {
      let type_ = sql.col_to_dynamic_string(field)
      "    use col_"
      <> field.name
      <> " <- try(pgo_driver.parse_col(row, "
      <> int.to_string(field.pos)
      <> ", "
      <> type_
      <> "))"
    })
    |> string.join("\n")

  // Generates the encoders that will encode the arguments passed to the function
  // to their respective pgo types.
  let encode_args =
    args
    |> list.map(fn(arg) {
      let encoder = case arg.nullable {
        True ->
          "case "
          <> arg.name
          <> "{\n    Some(a) -> "
          <> col_to_pgo(sql.SqlCol(..arg, name: "a"))
          <> "\n"
          <> "    None -> pgo.null() "
          <> "\n}"
        False -> col_to_pgo(arg)
      }
      "  let arg_" <> arg.name <> " = " <> encoder <> "\n"
    })
    |> string.join("")
  let encoded_args_var =
    args
    |> list.map(fn(arg) { "arg_" <> arg.name })
  let encoded_args_var =
    "let encoded_args = [" <> string.join(encoded_args_var, ",") <> "]\n"

  // Generate the fields that associate the returned columns to
  // the fields in the function's return type.
  let result_mapping =
    dict.values(returns)
    |> list.map(fn(field) { "        " <> field.name <> ": col_" <> field.name })
    |> string.join(",\n")
  // The function template 
  "pub fn "
  <> fun_name
  <> "(conn: pgo.Connection, "
  <> fun_args
  <> ") {\n"
  <> "  let query = \""
  <> query
  <> "\"\n"
  <> "\n"
  <> encode_args
  <> "\n  "
  <> encoded_args_var
  <> "\n"
  <> "  use response <- try(\n"
  <> "    pgo.execute(query, conn, encoded_args, dynamic.dynamic)\n"
  <> "    |> map_error(pgo_driver.QueryError)\n"
  <> "  )\n\n"
  <> "  response.rows |> list.try_map(fn (row) {\n"
  <> field_decoder
  <> "\n\n"
  <> "    Ok(\n      "
  <> return_type_name(fun_name)
  <> "(\n"
  <> result_mapping
  <> "\n    ))\n"
  <> "  })"
  <> "}"
}

fn table_cols(conn: pgo.Connection, table: String) {
  let sql = "
    SELECT column_name::text, data_type::text, is_nullable::boolean, ordinal_position
    FROM information_schema.columns 
    WHERE table_name = '" <> table <> "' order by column_name"
  let decoder =
    dynamic.tuple4(dynamic.string, dynamic.string, dynamic.bool, dynamic.int)
  use view_types <- try(
    pgo.execute(sql, conn, [], decoder)
    |> map_error(fn(e) { driver.SqlError(sql, string.inspect(e)) }),
  )
  view_types.rows
  |> list.try_fold(dict.new(), fn(result, row) {
    let #(name, sql_type, nullable, pos) = row
    use type_ <- try(sql.parse_sql_type(name, sql_type))

    // Position in sql is 1 based, so we subtract 1 to make 0 based
    dict.insert(result, name, sql.SqlCol(name, type_, nullable, pos - 1))
    |> Ok
  })
  |> map_error(driver.ParseSqlTypeError)
}

// Returns the columns calculated from a select statement
pub fn select_cols(
  conn: pgo.Connection,
  query: String,
) -> Result(dict.Dict(String, sql.SqlCol), GenerateError) {
  // TODO: do all this in a transaction once PGO has support for it

  // Create view
  let sql = "create view _query_cols as " <> query
  let discard_result = fn(_) { Ok(Nil) }
  use _ <- try(
    pgo.execute(sql, conn, [], discard_result)
    |> driver.map_sql_error(sql),
  )

  let cols = table_cols(conn, "_query_cols")

  // Delete the view
  let sql = "drop view _query_cols"
  use _ <- try(
    pgo.execute(sql, conn, [], discard_result)
    |> driver.map_sql_error(sql),
  )

  cols
}

pub fn generate_select_function(
  conn: pgo.Connection,
  select_params: SelectParams,
) -> Result(String, GenerateError) {
  // Generates the final query
  let args_list = select_params.args
  let query = sql.replace_with_dollar(select_params.query, args_list)

  // Gets the columns generated by the query by creating a view
  // with dummy values.
  use returned_cols <- try(select_cols(
    conn,
    sql.replace_with_dummy(select_params.query, args_list),
  ))
  // Applies the not null rules. If it's a single "*", then
  // that means set ALL columns to not null
  let returned_cols = case select_params.not_null {
    ["*"] -> sql.set_not_null(returned_cols, dict.keys(returned_cols))
    vars -> sql.set_not_null(returned_cols, vars)
  }
  use returned_cols <- try(
    returned_cols
    |> map_error(SetNotNullError),
  )

  // Generates the final function body
  let return_type =
    select_function_return_type(select_params.name, dict.values(returned_cols))
  let fun_body =
    select_function_body(select_params.name, query, args_list, returned_cols)

  Ok(return_type <> "\n" <> fun_body)
}

fn file_header() {
  "import gleam/pgo"
  <> "import gleam/option.{type Option, None, Some}"
  <> "import gleam/result.{map_error, try}"
  <> "import gleam/dynamic"
  <> "import gleam/list"
  <> "import pgo_driver"
}
