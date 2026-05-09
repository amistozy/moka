# Moka

Moka is a small dynamic language interpreter written in MoonBit.
Its surface syntax is inspired by [Koka](https://koka-lang.github.io/), but the implementation is intentionally much smaller and easier to experiment with.

The project currently focuses on:

- a compact interpreter core
- Koka-style layout syntax
- dynamic binding through `with`
- a codebase that is easy to extend

Moka is not a Koka implementation. It borrows some familiar syntax and ideas, but keeps the runtime and language model intentionally lightweight.

## Status

Moka currently supports:

- dynamic values: `null`, `bool`, `int`, `string`, `list`, and functions
- lexical scope and closures
- recursive functions
- mutable variables with `:=`
- Koka-style layout that inserts virtual statement separators and blocks from indentation
- explicit braces and semicolons as optional syntax
- `if` / `elif` / `else`
- `match` expressions
- `with`, `with val`, `with fun`, and `with override`
- a small set of built-ins: `len`, `type`, and `str`

## Running

Run the test suite:

```bash
moon test
```

Run the CLI:

```bash
moon run ./cmd/main
```

Evaluate a program from the command line:

```bash
moon run ./cmd/main -- "fun greet(name) \"hello, \" + name greet(\"moka\")"
```

## Language Tour

### Values

```moka
null
true
42
"hello"
[1, 2, 3]
```

### Bindings

Use `val` for immutable bindings and `var` for mutable bindings:

```moka
val name = "moka"
var count = 0
count := count + 1
```

### Functions

Single-expression functions are written naturally with layout:

```moka
fun add1(x)
  x + 1
```

Multi-statement functions also prefer layout:

```moka
fun pair_sum(x, y)
  val total = x + y
  total
```

Anonymous functions use `fn`:

```moka
val add = fn(x, y) x + y
```

Explicit braces still work when you want them:

```moka
fun pair_sum(x, y) {
  val total = x + y;
  total
}
```

### Conditionals

```moka
fun fib_tag(n)
  if n <= 0 then "zero"
  elif n == 1 then "one"
  else "many"
```

Branches can be indentation blocks:

```moka
fun classify(flag)
  if flag then
    val x = 40
    x + 2
  else
    0
```

Explicit braces are also accepted:

```moka
if ok then {
  val x = 1;
  x + 2
} else 0
```

### Match

`match` currently supports:

- literal patterns
- `_`
- name bindings
- fixed-length list patterns

Preferred layout style:

```moka
match [1, 2]
  [] -> 0
  [x, y] -> x + y
  _ -> 99
```

Explicit braces also work:

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
[1, 2, 3].len
"moka".type
```

## Layout Rules

Moka now prefers Koka-style layout.

In practice:

- a newline at the same indentation usually inserts a virtual `;`
- a deeper indentation usually opens a virtual block
- a dedent usually closes that virtual block
- continuation lines such as `.method()`, `else`, `elif`, or operator-led lines do not break the expression
- explicit `{ ... }` and `;` are still supported

Typical style:

```moka
fun work()
  val x = 10
  val y = 20
  x + y
```

More explicit style is still valid:

```moka
fun work() {
  val x = 10;
  val y = 20;
  x + y
}
```

## Dynamic Binding with `with`

One of the most Koka-like parts of Moka is dynamic binding.

### `with`

`with` wraps the remaining statements in the current scope into a trailing function body.
This follows the same overall shape as the `with` examples in Koka's `learn/with` sample.

```moka
fun twice(f)
  f()
  f()

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

fun pretty_thin(doc)
  with val width = 40
  pretty(doc)
```

### `with fun`

`with fun` installs a dynamic function binding:

```moka
fun hello()
  emit("world")

fun hello_console()
  with fun emit(msg) "hello, " + msg
  hello()
```

### `with override`

`with override` wraps the previous dynamic binding instead of replacing it directly:

```moka
fun hello()
  emit("hi")

fun emit_quoted(action)
  with override emit(msg) emit("[" + msg + "]")
  action()
```

Inside the override body, calling the same function name refers to the previous dynamic binding, not the override itself.

## Project Structure

- [moka.mbt](./moka.mbt): lexer, parser, evaluator, and runtime
- [moka_test.mbt](./moka_test.mbt): black-box language tests
- [cmd/main/main.mbt](./cmd/main/main.mbt): simple CLI entry point

## Development

Useful commands:

```bash
moon info
moon fmt
moon test
```

If the public package surface changes, `moon info` updates `pkg.generated.mbti`.
