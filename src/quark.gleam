import gleam/io
import glance
import test_output
import gleam/pgo
import gleam/option.{None, Some}

pub fn main() {
  let db =
    pgo.connect(
      pgo.Config(
        ..pgo.default_config(),
        host: "localhost",
        database: "testdb",
        user: "test",
        password: option.Some("test"),
        port: 55_123,
      ),
    )
  io.debug(test_output.test_query(db, Some("test"), 1))
}
