import gleam/result.{map_error, try}
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

pub fn col_to_gleam_type(col: SqlCol) {
  let type_ = case col.type_ {
    SqlBytea -> "BitArray"
    SqlText -> "String"
    SqlInt -> "Int"
    SqlFloat -> "Float"
    SqlBoolean -> "Bool"
  }

  case col.nullable {
    True -> "Option(" <> type_ <> ")"
    False -> type_
  }
}

pub fn col_to_dynamic_string(field: SqlCol) {
  let type_ = case field.type_ {
    SqlBytea -> "dynamic.bit_array"
    SqlText -> "dynamic.string"
    SqlInt -> "dynamic.int"
    SqlFloat -> "dynamic.float"
    SqlBoolean -> "dynamic.bool"
  }
  case field.nullable {
    True -> "dynamic.optional(" <> type_ <> ")"
    False -> type_
  }
}

pub type ParseSqlTypeError {
  UnsupportedResultType(column: String, type_: String)
}

pub fn parse_sql_type(col_name: String, sql_type: String) {
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

pub fn dummy_value(type_: SqlType) {
  case type_ {
    SqlBoolean -> "false"
    SqlInt -> "0"
    SqlBytea -> "null"
    SqlFloat -> "0.0"
    SqlText -> "''"
  }
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
pub fn replace_with_dollar(query: String, cols: List(SqlCol)) {
  let result =
    cols
    |> list.fold(#(1, query), fn(state, col) {
      let #(i, query) = state
      let query =
        string.replace(query, ":" <> col.name, "$" <> int.to_string(i))
      #(i + 1, query)
    })
  result.1
}

pub fn replace_with_dummy(query: String, cols: List(SqlCol)) {
  list.fold(cols, query, fn(q, col) {
    string.replace(q, ":" <> col.name, dummy_value(col.type_))
  })
}
