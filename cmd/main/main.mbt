///|
fn main {
  let args = @env.args()
  let source = if args.length() > 1 {
    args[1:].join(" ")
  } else {
    let sample =
      #|fun greet(name) { "hello, " + name }
      #|greet("moka")
    sample
  }
  let result = @moka.eval(source) catch { err => err.to_string() }
  println(result)
}
