///|
pub(all) suberror MokaError {
  Parse(String)
  Runtime(String)
}

///|
pub impl Show for MokaError with output(self, logger) {
  match self {
    Parse(message) => {
      logger.write_string("parse error: ")
      logger.write_string(message)
    }
    Runtime(message) => {
      logger.write_string("runtime error: ")
      logger.write_string(message)
    }
  }
}
