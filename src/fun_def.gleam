import gleam/list
import gleam/result.{map_error, try}
import gleam/io
import glance.{NamedType}
import gleam/option.{Some, type Option}

pub type ArgType {
  ArgText
  ArgInt
  ArgBool
  ArgFloat
  ArgBitArray
}

pub type Arg {
  Arg(name: String, arg_type: ArgType, nullable: Bool)
}

pub type FunDef {
  FunDef(name: String, args: List(Arg))
}

pub type Error {
  InvalidArgType(String)
  ArgTypeParseError(glance.FunctionParameter)
  NoFunctionDefinition
  InvalidArgName(String)
  ParseError(glance.Error)
}

fn parse_basic_type(arg: glance.FunctionParameter, arg_type: Option(glance.Type)) -> Result(ArgType, Error) {
  case arg_type {
    Some(NamedType("String", _, _)) -> Ok(ArgText)
    Some(NamedType("Int", _, _)) -> Ok(ArgInt)
    Some(NamedType("Bool", _, _)) -> Ok(ArgBool)
    Some(NamedType("Float", _, _)) -> Ok(ArgFloat)
    Some(NamedType("BitArray", _, _)) -> Ok(ArgBitArray)
    Some(NamedType(x, _, _)) -> Error(InvalidArgType(x))
    _ -> Error(ArgTypeParseError(arg))
  }
}

fn parse_type(arg: glance.FunctionParameter, arg_type: Option(glance.Type)) -> Result(ArgType, Error) {
  case arg_type {
    Some(NamedType("Option", _, [param])) -> {
      use basic_type <- try(parse_basic_type(arg, Some(param)))
      Ok(basic_type)
    }
    x -> parse_basic_type(arg, x)
  }
}

fn parse_arg(arg: glance.FunctionParameter) -> Result(Arg, Error) {
  use type_ <- try(parse_type(arg, arg.type_))
  use name <- try(case arg.name {
    glance.Named(n) -> Ok(n)
    glance.Discarded(n) -> Error(InvalidArgName(n))
  })
  let is_null = case arg.type_ {
    Some(NamedType("Option", _, _)) -> True
    _ -> False
  }
  Ok(Arg(name, type_, is_null))
}

fn parse_args(
  args: List(glance.FunctionParameter),
) -> Result(List(Arg), Error) {
  case args {
    [arg, ..rest] -> {
      use parsed_arg <- try(parse_arg(arg))
      use ok_rest <- try(parse_args(rest))
      Ok([parsed_arg, ..ok_rest])
    }
    _ -> Ok([])
  }
}

pub fn parse(fun_def: String) -> Result(FunDef, Error) {
  use parsed <- try(
    glance.module(fun_def)
    |> map_error(ParseError),
  )
  use def <- try(
    parsed.functions
    |> list.at(0)
    |> map_error(fn(_) { NoFunctionDefinition }),
  )
  let fun = def.definition
  use args <- try(parse_args(fun.parameters))
  Ok(FunDef(name: fun.name, args: args))
}

pub fn main() {
  let assert Ok(parsed) =
    glance.module("fn hello_world(arg1: Type1, arg2: Option(Type2))")
  io.debug(parsed)
}
