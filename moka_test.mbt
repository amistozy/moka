///|
test "arithmetic respects precedence" {
  let result = @moka.eval("1 + 2 * 3") catch { _ => panic() }
  inspect(result, content="7")
}

///|
test "closures capture lexical scope" {
  let source =
    #|val base = 10
    #|fun make_adder(x)
    #|  fn(y) base + x + y
    #|val add5 = make_adder(5)
    #|add5(7)
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="22")
}

///|
test "mutable vars and recursion work" {
  let source =
    #|fun fib(n) {
    #|  if n <= 1 then n else fib(n - 1) + fib(n - 2)
    #|}
    #|var answer = fib(8)
    #|answer := answer + 1
    #|answer
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="22")
}

///|
test "lists indexing and builtins feel dynamic" {
  let source =
    #|val xs = [1, "two", 3]
    #|if len(xs) == 3 then xs[1] else null
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="\"two\"")
}
