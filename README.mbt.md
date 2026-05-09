# Moka

Moka is a small dynamic language interpreter written in MoonBit.
Its surface syntax is inspired by [Koka](https://koka-lang.github.io/), while the implementation stays intentionally compact and easy to modify.

Moka is not a Koka implementation.
It borrows a few familiar ideas, especially layout and dynamic binding, but keeps the runtime model lightweight and experimental.

## Goals

Moka currently aims to be:

- small enough to understand in one sitting
- expressive enough to explore language ideas quickly
- structured enough to grow without collapsing into one giant file

The project is especially focused on:

- a compact interpreter core
- Koka-style layout-sensitive syntax
- dynamic binding through `with` and `handler`
- a codebase that is pleasant to extend

## Current Features

Moka currently supports:

- values: `null`, `bool`, `int`, `string`, `list`, and functions
- lexical scope and closures
- recursive functions
- mutable variables with `:=`
- layout-based blocks and separators inferred from indentation
- optional explicit braces and semicolons
- `if` / `elif` / `else`
- `match` expressions
- `handler` expressions
- `with`, `with val`, `with fun`, `with handler`, and `with override`
- a small builtin set: `len`, `type`, and `str`

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

Single-expression functions fit naturally into layout-based syntax:

```moka
fun add1(x)
  x + 1
```

Multi-statement bodies also use indentation:

```moka
fun pair_sum(x, y)
  val total = x + y
  total
```

Anonymous functions use `fn`:

```moka
val add = fn(x, y) x + y
```

Braces remain available when you want a more explicit shape:

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

Branches can themselves be multi-statement blocks:

```moka
fun classify(flag)
  if flag then
    val x = 40
    x + 2
  else
    0
```

### Match

`match` currently supports:

- literal patterns
- `_`
- name bindings
- fixed-length list patterns

Typical layout style:

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

Moka prefers Koka-style layout.

In practice:

- a newline at the same indentation usually inserts a virtual `;`
- a deeper indentation usually opens a virtual block
- a dedent usually closes that virtual block
- continuation lines such as `.method()`, `else`, `elif`, or operator-led lines do not end the current expression
- explicit `{ ... }` and `;` are still supported

Typical style:

```moka
fun work()
  val x = 10
  val y = 20
  x + y
```

More explicit style is also valid:

```moka
fun work() {
  val x = 10;
  val y = 20;
  x + y
}
```

## Dynamic Binding

One of the most Koka-like parts of Moka is dynamic binding.

### `with`

`with` wraps the remaining statements in the current scope into a trailing function body:

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

### `handler`

Moka also has a minimal `handler` expression.
Handlers currently support `val` and `fun` clauses and are applied to a zero-argument action function.

```moka
val h = handler
  val ask = 21

h(fn() ask + ask)
```

### `with handler`

`with handler` is the statement form of the same idea:

```moka
fun ask_twice()
  ask + ask

with handler
  val ask = 21
ask_twice()
```

### `with val`

`with val` is sugar for a single-clause handler that installs a dynamic value:

```moka
fun pretty(doc)
  str(width) + ":" + doc

fun pretty_thin(doc)
  with val width = 40
  pretty(doc)
```

### `with fun`

`with fun` is sugar for a single-clause handler that installs a dynamic function:

```moka
fun hello()
  emit("world")

fun hello_console()
  with fun emit(msg) "hello, " + msg
  hello()
```

### `with override`

`with override` wraps the previous dynamic binding instead of replacing it outright:

```moka
fun hello()
  emit("hi")

fun emit_quoted(action)
  with override emit(msg) emit("[" + msg + "]")
  action()
```

Inside the override body, calling the same function name refers to the previous dynamic binding rather than the override itself.

## Project Structure

The interpreter is now split by responsibility:

- [errors.mbt](./errors.mbt): public error type and rendering
- [syntax.mbt](./syntax.mbt): tokens, AST nodes, and shared internal data types
- [lexer.mbt](./lexer.mbt): lexer and layout token insertion
- [parser.mbt](./parser.mbt): parser and internal syntax construction
- [runtime.mbt](./runtime.mbt): runtime values, evaluation, and public `eval`
- [moka_test.mbt](./moka_test.mbt): black-box language tests
- [moka_wbtest.mbt](./moka_wbtest.mbt): white-box tests for internal behavior
- [cmd/main/main.mbt](./cmd/main/main.mbt): simple CLI entry point

## Development

Useful commands:

```bash
moon info
moon fmt
moon test
```

`moon info` updates [pkg.generated.mbti](./pkg.generated.mbti) when the public package surface changes.

If you are extending the language, a practical workflow is:

1. update the lexer, parser, or runtime in the relevant split file
2. add or adjust tests in [moka_test.mbt](./moka_test.mbt) or [moka_wbtest.mbt](./moka_wbtest.mbt)
3. run `moon test`
4. run `moon info && moon fmt`

## References

This repository also includes a [reference](./reference) directory with upstream-style MoonBit code and parser implementations that are useful when evolving Moka's structure and style.
