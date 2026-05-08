# Moka

Moka is a small dynamic interpreter written in MoonBit and inspired by the surface style of [Koka](https://koka-lang.github.io/). It is intentionally much smaller than Koka, but it borrows familiar ideas such as `fun`, `fn`, `val`, `var`, `if ... then ... else ...`, `match`, and `with`.

The current implementation focuses on being easy to experiment with and easy to extend. It is not a full Koka implementation.

## Status

Moka currently supports:

- Dynamic values: `null`, `bool`, `int`, `string`, `list`, and function values
- Lexical scope and closures
- Recursive functions
- Mutable variables with `:=`
- Blocks with explicit braces
- `if` / `elif` / `else`
- `match` expressions
- `with`, `with val`, `with fun`, and `with override fun`
- A few built-ins: `len`, `type`, and `str`

## Running

Run the tests:

```bash
moon test
```

Run the sample CLI:

```bash
moon run ./cmd/main
```

Pass a program on the command line:

```bash
moon run ./cmd/main -- "fun greet(name) \"hello, \" + name greet(\"moka\")"
```

## Language Overview

### Values

```moka
null
true
42
"hello"
[1, 2, 3]
```

### Functions

Single-expression functions can omit braces:

```moka
fun add1(x)
  x + 1
```

Multi-statement functions must use explicit braces:

```moka
fun pair_sum(x, y) {
  val total = x + y
  total
}
```

Anonymous functions use `fn`:

```moka
val add = fn(x, y) x + y
```

### Variables

Use `val` for immutable bindings and `var` for mutable bindings:

```moka
val name = "moka"
var count = 0
count := count + 1
```

### Conditionals

```moka
fun fib_tag(n)
  if n <= 0 then "zero"
  elif n == 1 then "one"
  else "many"
```

If a branch needs multiple statements, use braces explicitly:

```moka
if ok then {
  val x = 1
  x + 2
} else 0
```

### Match

`match` currently supports literal patterns, `_`, name bindings, and fixed-length list patterns:

```moka
match [1, 2] {
  [] -> 0
  [x, y] -> x + y
  _ -> 99
}
```

### Dot Call Sugar

Like Koka, `x.f(y)` desugars to `f(x, y)`:

```moka
"moka".str
xs.len
```

## Layout Rule

Moka currently uses a very simple rule:

- A newline is treated like a statement separator
- An explicit `;` is also a statement separator
- Only explicit `{ ... }` creates a block

This means Moka does **not** currently implement Koka- or Haskell-style indentation layout. Indentation improves readability, but it does not create blocks by itself.

In practice:

- This is valid:

```moka
fun add1(x)
  x + 1
```

- This is also valid:

```moka
fun work() {
  val x = 10
  x + 1
}
```

- But multi-statement bodies must still use braces:

```moka
fun work() {
  val x = 10
  val y = 20
  x + y
}
```

## Dynamic Binding with `with`

One of the more Koka-like features in Moka is dynamic binding.

### `with`

`with` passes the following statements as the trailing function body:

```moka
fun twice(f) { f(); f() }

var n = 0
with twice
n := n + 1
n := n + 2
n
```

### `with val`

`with val` installs a dynamic value binding for the remaining statements in the current scope:

```moka
fun pretty(doc)
  str(width) + ":" + doc

fun pretty_thin(doc) {
  with val width = 40
  pretty(doc)
}
```

### `with fun`

`with fun` dynamically installs a function binding:

```moka
fun hello()
  emit("world")

fun hello_console() {
  with fun emit(msg) "hello, " + msg
  hello()
}
```

### `with override fun`

`with override fun` wraps an existing dynamic function binding instead of replacing it outright:

```moka
fun hello()
  emit("hi")

fun emit_quoted(action) {
  with override fun emit(msg) emit("[" + msg + "]")
  action()
}
```

Inside the override body, calling the same function name refers to the previous dynamic binding, not the override itself.

## Project Structure

- [moka.mbt](C:/Users/lenovo/Documents/moonbit/moka/moka.mbt): interpreter implementation
- [moka_test.mbt](C:/Users/lenovo/Documents/moonbit/moka/moka_test.mbt): black-box tests
- [cmd/main/main.mbt](C:/Users/lenovo/Documents/moonbit/moka/cmd/main/main.mbt): simple CLI entry point
- [reference](C:/Users/lenovo/Documents/moonbit/moka/reference): reference material, including Koka documentation and grammar sources

## Development Notes

Useful commands during development:

```bash
moon info
moon fmt
moon test
```

When changing the public package surface, `moon info` will update `pkg.generated.mbti`.
