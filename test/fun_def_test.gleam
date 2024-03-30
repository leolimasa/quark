import gleeunit/should
import fun_def
import sql

pub fn parse_test() {
  let result = fun_def.parse("fn test_query(str_arg: String, int_arg: Int, bool_arg: Bool, float_arg: Float, bit_array_arg: BitArray, nullable_arg: Option(Bool))")
  let expected = fun_def.FunDef(
    name: "test_query",
    args: [
      sql.SqlCol(name: "str_arg", type_: sql.SqlText, nullable: False, pos: 0),
      sql.SqlCol(name: "int_arg", type_: sql.SqlInt, nullable: False, pos: 1),
      sql.SqlCol(name: "bool_arg", type_: sql.SqlBoolean, nullable: False, pos: 2),
      sql.SqlCol(name: "float_arg", type_: sql.SqlFloat, nullable: False, pos: 3),
      sql.SqlCol(name: "bit_array_arg", type_: sql.SqlBytea, nullable: False, pos: 4),
      sql.SqlCol(name: "nullable_arg", type_: sql.SqlBoolean, nullable: True, pos: 5)
    ]
  )
  should.equal(result, Ok(expected))
}
