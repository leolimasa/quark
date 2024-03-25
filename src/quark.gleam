import gleam/io
import glance

pub fn generate_function_body(def: String, query: String) {
    
}

pub fn main() {
  let assert Ok(parsed) = glance.module("fn employees(arg1: String, arg2: String)")
  io.debug(parsed)
}
