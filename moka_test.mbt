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
test "layout creates multi statement function blocks" {
  let source =
    #|fun pair_sum(x, y)
    #|  val total = x + y
    #|  total
    #|pair_sum(20, 22)
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="42")
}

///|
test "mutable vars and recursion work" {
  let source =
    #|fun fib(n)
    #|  if n <= 1 then n else fib(n - 1) + fib(n - 2)
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
test "with wraps all following statements in current scope" {
  let source =
    #|fun twice(f)
    #|  f()
    #|  f()
    #|var n = 0
    #|with twice
    #|n := n + 1
    #|n := n + 2
    #|n
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="6")
}

///|
test "nested with composes through layout" {
  let source =
    #|fun twice(f)
    #|  f()
    #|  f()
    #|var n = 0
    #|with twice
    #|with twice
    #|n := n + 1
    #|n
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="4")
}

///|
test "handler expression can be applied directly" {
  let source =
    #|val h = handler
    #|  val ask = 21
    #|h(fn() ask + ask)
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="42")
}

///|
test "with handler installs dynamic values" {
  let source =
    #|fun ask_twice()
    #|  ask + ask
    #|with handler
    #|  val ask = 21
    #|ask_twice()
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="42")
}

///|
test "with handler installs dynamic functions" {
  let source =
    #|fun hello()
    #|  emit("world")
    #|with handler
    #|  fun emit(msg) "hello, " + msg
    #|hello()
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="\"hello, world\"")
}

///|
test "with binding passes produced value into body" {
  let source =
    #|fun supply(f)
    #|  f(21)
    #|with x <- supply
    #|x + 21
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="42")
}

///|
test "with binding scopes over remaining statements" {
  let source =
    #|fun supply(f)
    #|  f(20)
    #|with x <- supply
    #|val y = x + 1
    #|x + y
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="41")
}

///|
test "match handles literals bindings and lists" {
  let source =
    #|match [1, 2]
    #|  [] -> 0
    #|  [x, y] -> x + y
    #|  _ -> 99
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="3")
}

///|
test "layout creates multi statement if branches" {
  let source =
    #|fun decide(flag)
    #|  if flag then
    #|    val x = 40
    #|    x + 2
    #|  else
    #|    0
    #|decide(true)
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="42")
}

///|
test "match accepts layout cases without explicit braces" {
  let source =
    #|match [1, 2]
    #|  [] -> 0
    #|  [x, y] -> x + y
    #|  _ -> 99
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
test "with val dynamically binds across function call boundaries" {
  let source =
    #|fun pretty(d)
    #|  str(width) + ":" + d
    #|fun pretty_thin(d)
    #|  with val width = 40
    #|  pretty(d)
    #|pretty_thin("doc")
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="\"40:doc\"")
}

///|
test "with val can shadow previous dynamic binding" {
  let source =
    #|fun read_width()
    #|  str(width)
    #|fun outer()
    #|  with val width = 40
    #|  inner()
    #|fun inner()
    #|  with val width = width + 2
    #|  read_width()
    #|outer()
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="\"42\"")
}

///|
test "with fun dynamically binds across function call boundaries" {
  let source =
    #|fun hello()
    #|  emit("world")
    #|fun hello_console()
    #|  with fun emit(msg) "hello, " + msg
    #|  hello()
    #|hello_console()
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="\"hello, world\"")
}

///|
test "with fun matches koka ask const style across helper function" {
  let source =
    #|fun add_twice()
    #|  ask() + ask()
    #|fun ask_const()
    #|  with fun ask() 21
    #|  add_twice()
    #|ask_const()
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="42")
}

///|
test "with override wraps previous dynamic function" {
  let source =
    #|fun hello()
    #|  emit("hi")
    #|fun emit_quoted(action)
    #|  with override emit(msg) emit("[" + msg + "]")
    #|  action()
    #|fun hello_console()
    #|  with fun emit(msg) "<" + msg + ">"
    #|  with emit_quoted
    #|  hello()
    #|hello_console()
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="\"<[hi]>\"")
}

///|
test "suspenders pass a trailing braced block as a zero arg lambda" {
  let source =
    #|fun twice(f)
    #|  f()
    #|  f()
    #|var n = 0
    #|twice {
    #|  n := n + 1
    #|}
    #|n
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="2")
}

///|
test "layout after a callee becomes a trailing block lambda" {
  let source =
    #|fun twice(f)
    #|  f()
    #|  f()
    #|var n = 0
    #|twice
    #|  n := n + 1
    #|n
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="2")
}

///|
test "trailing fn appends a lambda to an existing call" {
  let source =
    #|fun apply(x, f)
    #|  f(x)
    #|apply(21) fn(x)
    #|  x + 21
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="42")
}

///|
test "dot call sugar works with trailing fn lambdas" {
  let source =
    #|fun apply(x, f)
    #|  f(x)
    #|21.apply fn(x)
    #|  x + 21
  let result = @moka.eval(source) catch { _ => panic() }
  inspect(result, content="42")
}
