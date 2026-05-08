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

///|
test "with supports trailing lambda style composition" {
  let source =
    #|fun twice(f) { f(); f() }
    #|var n = 0
    #|with twice
    #|with twice
    #|{ n := n + 1 }
    #|n
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="4")
}

///|
test "with wraps all following statements in current scope" {
  let source =
    #|fun twice(f) { f(); f() }
    #|var n = 0
    #|with twice
    #|n := n + 1
    #|n := n + 2
    #|n
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="6")
}

///|
test "with binding passes produced value into body" {
  let source =
    #|fun supply(f) { f(21) }
    #|with x <- supply
    #|x + 21
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="42")
}

///|
test "with binding scopes over remaining statements" {
  let source =
    #|fun supply(f) { f(20) }
    #|with x <- supply
    #|val y = x + 1
    #|x + y
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="41")
}

///|
test "match handles literals bindings and lists" {
  let source =
    #|match [1, 2] {
    #|  [] -> 0
    #|  [x, y] -> x + y
    #|  _ -> 99
    #|}
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="3")
}

///|
test "elif follows koka style branching" {
  let source =
    #|fun fib_tag(n)
    #|  if n <= 0 then "zero"
    #|  elif n == 1 then "one"
    #|  else "many"
    #|fib_tag(1)
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="\"one\"")
}

///|
test "with val provides dynamic style scoped binding" {
  let source =
    #|fun pretty(d)
    #|  str(width) + ":" + d
    #|with val width = 40
    #|pretty("doc")
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="\"40:doc\"")
}

///|
test "with val can shadow previous binding" {
  let source =
    #|with val width = 40
    #|with val width = width + 2
    #|str(width)
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="\"42\"")
}
