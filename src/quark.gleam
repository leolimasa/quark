import gleam/io
import glance


pub fn generate_select(header: String, body: String) {
    
}

pub fn main() {
  let assert Ok(parsed) = glance.module("fn employees(arg1: String, arg2: String)")
  io.debug(parsed)
}
