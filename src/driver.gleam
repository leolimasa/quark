import sql
import gleam/result
import gleam/string


pub type GenerateError {
  SqlError(query: String, error: String)
  ParseSqlTypeError(sql.ParseSqlTypeError)
  SetNotNullError(sql.SetNotNullError)
}

pub type SelectParams {
  SelectParams(
    name: String,
    query: String,
    args: List(sql.SqlCol),
    not_null: List(String),
  )
}

pub fn map_sql_error(query) {
  result.map_error(_, fn (e) {
    SqlError(query, string.inspect(e))
  })
}
