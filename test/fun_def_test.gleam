import gleeunit/should
import fun_def.{Arg}

pub fn parse_test() {
  let result = fun_def.parse("fn test_query(str_arg: String, int_arg: Int, bool_arg: Bool, float_arg: Float, bit_array_arg: BitArray, nullable_arg: Option(Bool))")
  let expected = fun_def.FunDef(
    name: "test_query",
    args: [
      Arg(name: "str_arg", arg_type: fun_def.ArgText, nullable: False),
      Arg(name: "int_arg", arg_type: fun_def.ArgInt, nullable: False),
      Arg(name: "bool_arg", arg_type: fun_def.ArgBool, nullable: False),
      Arg(name: "float_arg", arg_type: fun_def.ArgFloat, nullable: False),
      Arg(name: "bit_array_arg", arg_type: fun_def.ArgBitArray, nullable: False),
      Arg(name: "nullable_arg", arg_type: fun_def.ArgBool, nullable: True)
    ]
  )
  should.equal(result, Ok(expected))
}
