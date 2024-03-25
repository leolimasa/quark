import gleam/pgo
import gleam/result.{map_error, try}
import gleam/dynamic
import gleam/list
import gleam/dict.{type Dict}
import gleam/string
import gleam/int

pub type SqlType {
  SqlText
  SqlInt
  SqlBoolean
  SqlFloat
  SqlBytea
}

pub type SqlCol {
  SqlCol(name: String, type_: SqlType, nullable: Bool, pos: Int)
}

pub type SqlError {
  CreateViewError(String, pgo.QueryError)
  ViewColsError(String, pgo.QueryError)
  DropViewError(String, pgo.QueryError)
  UnsupportedResultType(column: String, type_: String)
}

pub fn dummy_value(type_: SqlType) -> pgo.Value {
  case type_ {
    SqlBoolean -> pgo.bool(False)
    SqlInt -> pgo.int(0)
    SqlBytea -> pgo.null()
    SqlFloat -> pgo.float(0.0)
    SqlText -> pgo.text("")
  }
}

fn convert_type(col_name: String, sql_type: String) {
  case sql_type {
    "text" -> Ok(SqlText)
    "bigint" -> Ok(SqlInt)
    "integer" -> Ok(SqlInt)
    "boolean" -> Ok(SqlBoolean)
    "double precision" -> Ok(SqlFloat)
    "bytea" -> Ok(SqlBytea)
    x -> Error(UnsupportedResultType(col_name, x))
  }
}

fn table_cols(conn: pgo.Connection, table: String) {
  let sql = "
    SELECT column_name::text, data_type::text, is_nullable::boolean, ordinal_position
    FROM information_schema.columns 
    WHERE table_name = '" <> table <> "' order by column_name"
  let decoder = dynamic.tuple4(dynamic.string, dynamic.string, dynamic.bool, dynamic.int)
  use view_types <- try(
    pgo.execute(sql, conn, [], decoder)
    |> map_error(ViewColsError(sql, _)),
  )
  view_types.rows
  |> list.try_fold(dict.new(), fn(result, row) {
    let #(name, sql_type, nullable, pos) = row
    use type_ <- try(convert_type(name, sql_type))

    // Position in sql is 1 based, so we subtract 1 to make 0 based
    dict.insert(result, name, SqlCol(name, type_, nullable, pos - 1))
    |> Ok
  })
}

pub type SetNotNullError {
  ColDoesntExist(String)
}

pub fn set_not_null(cols: Dict(String, SqlCol), not_null: List(String)) {
  list.try_fold(not_null, cols, fn(result, col_name) {
    use col <- try(
      dict.get(result, col_name)
      |> map_error(fn(_) { ColDoesntExist(col_name) }),
    )
    result
    |> dict.insert(col_name, SqlCol(..col, nullable: False))
    |> Ok
  })
}

// Replaces the variables in the form of ":COLNAME" in the query with sequential dollar signs (e.g. $1, $2...)
// according to the order of columns specified.
pub fn replace_vars(query: String, cols: List(SqlCol)) {
  let result =
    cols
    |> list.fold(#(0, query), fn(state, col) {
      let #(i, query) = state
      let query =
        string.replace(query, ":" <> col.name, "$" <> int.to_string(i))
      #(i + 1, query)
    })
  result.1
}

// Returns the columns calculated from a select statement
pub fn select_cols(
  conn: pgo.Connection,
  query: String,
  args: List(pgo.Value),
) -> Result(dict.Dict(String, SqlCol), SqlError) {
  // TODO: do all this in a transaction once PGO has support for it

  // Create view
  let sql = "create view _query_cols as " <> query
  let discard_result = fn(_) { Ok(Nil) }
  use _ <- try(
    pgo.execute(sql, conn, args, discard_result)
    |> map_error(CreateViewError(sql, _)),
  )

  let cols = table_cols(conn, "_query_cols")

  // Delete the view
  let sql = "drop view _query_cols"
  use _ <- try(
    pgo.execute(sql, conn, [], discard_result)
    |> map_error(DropViewError(sql, _)),
  )

  cols
}
