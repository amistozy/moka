///|
priv enum Value {
  Null
  Bool(Bool)
  Int(Int)
  String(String)
  List(Array[Value])
  Function(FunctionValue)
}

///|
priv enum FunctionValue {
  User(UserClosure)
  Handler(HandlerValue)
  Native(NativeFn)
}

///|
priv struct UserClosure {
  name : String?
  params : Array[String]
  body : Expr
  env : Int
}

///|
priv struct HandlerValue {
  clauses : Array[HandlerClause]
  return_clause : ReturnClause?
  env : Int
}

///|
priv struct NativeFn {
  name : String
  arity : Int
  call : (Runtime, Array[Value]) -> Value raise MokaError
}

///|
priv struct Cell {
  mutable_ : Bool
  mut value : Value
}

///|
priv struct EnvFrame {
  parent : Int
  bindings : Map[String, Int]
}

///|
priv struct Runtime {
  cells : Array[Cell]
  envs : Array[EnvFrame]
  dynamic_envs : Array[Int]
  global_env : Int
}

///|
fn[T] runtime_error(message : String) -> T raise MokaError {
  raise Runtime(message)
}

///|
fn Runtime::new() -> Runtime {
  let runtime = { cells: [], envs: [], dynamic_envs: [], global_env: 0 }
  let global_env = runtime.new_env(-1)
  runtime.install_native(global_env, {
    name: "len",
    arity: 1,
    call: (runtime : Runtime, args : Array[Value]) => builtin_len(runtime, args),
  })
  runtime.install_native(global_env, {
    name: "type",
    arity: 1,
    call: (_runtime : Runtime, args : Array[Value]) => {
      Value::String(type_name(args[0]))
    },
  })
  runtime.install_native(global_env, {
    name: "str",
    arity: 1,
    call: (_runtime : Runtime, args : Array[Value]) => {
      Value::String(value_to_plain_string(args[0]))
    },
  })
  runtime.install_native(global_env, {
    name: "finally",
    arity: 2,
    call: (runtime : Runtime, args : Array[Value]) => {
      builtin_finally(runtime, args)
    },
  })
  { ..runtime, global_env, }
}

///|
fn Runtime::new_env(self : Runtime, parent : Int) -> Int {
  let env_id = self.envs.length()
  self.envs.push({ parent, bindings: {} })
  env_id
}

///|
fn Runtime::new_cell(self : Runtime, value : Value, mutable_ : Bool) -> Int {
  let cell_id = self.cells.length()
  self.cells.push({ value, mutable_ })
  cell_id
}

///|
fn Runtime::bind_value(
  self : Runtime,
  env_id : Int,
  name : String,
  value : Value,
  mutable_ : Bool,
) -> Unit {
  let cell_id = self.new_cell(value, mutable_)
  self.envs[env_id].bindings[name] = cell_id
}

///|
fn Runtime::install_native(
  self : Runtime,
  env_id : Int,
  native : NativeFn,
) -> Unit {
  self.bind_value(
    env_id,
    native.name,
    Value::Function(FunctionValue::Native(native)),
    false,
  )
}

///|
fn Runtime::lookup_cell(self : Runtime, env_id : Int, name : String) -> Int? {
  let mut current = env_id
  while current >= 0 {
    match self.envs[current].bindings.get(name) {
      Some(cell_id) => return Some(cell_id)
      None => current = self.envs[current].parent
    }
  }
  None
}

///|
fn Runtime::get_value(
  self : Runtime,
  env_id : Int,
  name : String,
) -> Value raise MokaError {
  if self.lookup_cell(env_id, name) is Some(cell_id) {
    return self.cells[cell_id].value
  }
  let mut i = self.dynamic_envs.length() - 1
  while i >= 0 {
    let dynamic_env = self.dynamic_envs[i]
    if self.lookup_cell(dynamic_env, name) is Some(cell_id) {
      return self.cells[cell_id].value
    }
    i = i - 1
  }
  runtime_error("undefined name '\{name}'")
}

///|
fn Runtime::assign(
  self : Runtime,
  env_id : Int,
  name : String,
  value : Value,
) -> Value raise MokaError {
  guard self.lookup_cell(env_id, name) is Some(cell_id) else {
    runtime_error("undefined variable '\{name}'")
  }
  guard self.cells[cell_id].mutable_ else {
    runtime_error("cannot assign to immutable value '\{name}'")
  }
  self.cells[cell_id].value = value
  value
}

///|
fn is_truthy(value : Value) -> Bool {
  match value {
    Value::Null => false
    Value::Bool(flag) => flag
    _ => true
  }
}

///|
fn type_name(value : Value) -> String {
  match value {
    Value::Null => "null"
    Value::Bool(_) => "bool"
    Value::Int(_) => "int"
    Value::String(_) => "string"
    Value::List(_) => "list"
    Value::Function(_) => "function"
  }
}

///|
fn value_equal(left : Value, right : Value) -> Bool {
  match left {
    Value::Null =>
      match right {
        Value::Null => true
        _ => false
      }
    Value::Bool(a) =>
      match right {
        Value::Bool(b) => a == b
        _ => false
      }
    Value::Int(a) =>
      match right {
        Value::Int(b) => a == b
        _ => false
      }
    Value::String(a) =>
      match right {
        Value::String(b) => a == b
        _ => false
      }
    Value::List(a) =>
      match right {
        Value::List(b) => {
          guard a.length() == b.length() else { return false }
          for i in 0..<a.length() {
            guard value_equal(a[i], b[i]) else { return false }
          }
          true
        }
        _ => false
      }
    Value::Function(_) => false
  }
}

///|
fn render_value(value : Value) -> String {
  match value {
    Value::Null => "null"
    Value::Bool(flag) => if flag { "true" } else { "false" }
    Value::Int(number) => number.to_string()
    Value::String(text) => "\"\{text}\""
    Value::List(items) => {
      let parts = items.map(render_value)
      let body = parts.join(", ")
      "[\{body}]"
    }
    Value::Function(FunctionValue::User(closure)) =>
      if closure.name is Some(name) {
        "<fun \{name}>"
      } else {
        "<fn>"
      }
    Value::Function(FunctionValue::Handler(_)) => "<handler>"
    Value::Function(FunctionValue::Native(native)) => "<native \{native.name}>"
  }
}

///|
fn value_to_plain_string(value : Value) -> String {
  match value {
    Value::String(text) => text
    _ => render_value(value)
  }
}

///|
fn builtin_len(
  _runtime : Runtime,
  args : Array[Value],
) -> Value raise MokaError {
  match args[0] {
    Value::String(text) => Value::Int(text.length())
    Value::List(items) => Value::Int(items.length())
    _ => runtime_error("len expects a string or list")
  }
}

///|
fn builtin_finally(
  runtime : Runtime,
  args : Array[Value],
) -> Value raise MokaError {
  let cleanup = args[0]
  let action = args[1]
  let result = apply_function(runtime, action, []) catch {
    err => {
      apply_function(runtime, cleanup, []) |> ignore
      raise err
    }
  }
  apply_function(runtime, cleanup, []) |> ignore
  result
}

///|
fn eval_program(program : Array[Stmt]) -> Value raise MokaError {
  let runtime = Runtime::new()
  eval_statements(runtime, runtime.global_env, program)
}

///|
fn eval_statements(
  runtime : Runtime,
  env_id : Int,
  stmts : Array[Stmt],
) -> Value raise MokaError {
  let mut last = Value::Null
  for stmt in stmts {
    last = eval_stmt(runtime, env_id, stmt)
  }
  last
}

///|
fn eval_stmt(
  runtime : Runtime,
  env_id : Int,
  stmt : Stmt,
) -> Value raise MokaError {
  match stmt {
    Stmt::Val(name, expr) => {
      runtime.bind_value(env_id, name, eval_expr(runtime, env_id, expr), false)
      Value::Null
    }
    Stmt::Var(name, expr) => {
      runtime.bind_value(env_id, name, eval_expr(runtime, env_id, expr), true)
      Value::Null
    }
    Stmt::Fun(name, params, body) => {
      let closure = UserClosure::{ name: Some(name), params, body, env: env_id }
      runtime.bind_value(
        env_id,
        name,
        Value::Function(FunctionValue::User(closure)),
        false,
      )
      Value::Null
    }
    Stmt::WithOverride(name, params, fun_body, body) =>
      eval_with_override(runtime, env_id, name, params, fun_body, body)
    Stmt::Expr(expr) => eval_expr(runtime, env_id, expr)
  }
}

///|
fn eval_expr(
  runtime : Runtime,
  env_id : Int,
  expr : Expr,
) -> Value raise MokaError {
  match expr {
    Expr::Null => Value::Null
    Expr::Bool(flag) => Value::Bool(flag)
    Expr::Int(number) => Value::Int(number)
    Expr::String(text) => Value::String(text)
    Expr::Var(name) => runtime.get_value(env_id, name)
    Expr::List(items) =>
      Value::List(items.map(item => eval_expr(runtime, env_id, item)))
    Expr::Unary(op, inner) => eval_unary(op, eval_expr(runtime, env_id, inner))
    Expr::Binary(op, left, right) =>
      eval_binary(runtime, env_id, op, left, right)
    Expr::If(condition, then_branch, else_branch) =>
      if is_truthy(eval_expr(runtime, env_id, condition)) {
        eval_expr(runtime, env_id, then_branch)
      } else {
        eval_expr(runtime, env_id, else_branch)
      }
    Expr::Lambda(params, body) =>
      Value::Function(
        FunctionValue::User(UserClosure::{
          name: None,
          params,
          body,
          env: env_id,
        }),
      )
    Expr::Call(callee, args) =>
      apply_function(
        runtime,
        eval_expr(runtime, env_id, callee),
        args.map(arg => eval_expr(runtime, env_id, arg)),
      )
    Expr::Index(target, index) =>
      eval_index(
        eval_expr(runtime, env_id, target),
        eval_expr(runtime, env_id, index),
      )
    Expr::Assign(name, value) =>
      runtime.assign(env_id, name, eval_expr(runtime, env_id, value))
    Expr::Match(subject, cases) =>
      eval_match_expr(runtime, env_id, subject, cases)
    Expr::Handler(clauses, return_clause) =>
      Value::Function(
        FunctionValue::Handler({ clauses, return_clause, env: env_id }),
      )
    Expr::Block(stmts) => {
      let block_env = runtime.new_env(env_id)
      eval_statements(runtime, block_env, stmts)
    }
  }
}

///|
fn install_handler_clauses(
  runtime : Runtime,
  handler_env : Int,
  clauses : Array[HandlerClause],
) -> Unit raise MokaError {
  for clause in clauses {
    match clause {
      HandlerClause::Val(name, expr) =>
        runtime.bind_value(
          handler_env,
          name,
          eval_expr(runtime, handler_env, expr),
          false,
        )
      HandlerClause::Fun(name, params, body) =>
        runtime.bind_value(
          handler_env,
          name,
          Value::Function(
            FunctionValue::User(UserClosure::{
              name: Some(name),
              params,
              body,
              env: handler_env,
            }),
          ),
          false,
        )
    }
  }
}

///|
fn eval_return_clause(
  runtime : Runtime,
  handler_env : Int,
  clause : ReturnClause,
  value : Value,
) -> Value raise MokaError {
  let return_env = runtime.new_env(handler_env)
  runtime.bind_value(return_env, clause.param, value, false)
  eval_expr(runtime, return_env, clause.body)
}

///|
fn eval_with_override(
  runtime : Runtime,
  env_id : Int,
  name : String,
  params : Array[String],
  fun_body : Expr,
  body : Stmt,
) -> Value raise MokaError {
  let previous = runtime.get_value(env_id, name)
  let previous_env = runtime.new_env(env_id)
  runtime.bind_value(previous_env, name, previous, false)
  let override_value = Value::Function(
    FunctionValue::User(UserClosure::{
      name: None,
      params,
      body: fun_body,
      env: previous_env,
    }),
  )
  let with_env = runtime.new_env(env_id)
  runtime.bind_value(with_env, name, override_value, false)
  runtime.dynamic_envs.push(with_env)
  let result = eval_stmt(runtime, env_id, body) catch {
    err => {
      runtime.dynamic_envs.pop() |> ignore
      raise err
    }
  }
  runtime.dynamic_envs.pop() |> ignore
  result
}

///|
fn eval_match_expr(
  runtime : Runtime,
  env_id : Int,
  subject : Expr,
  cases : Array[MatchCase],
) -> Value raise MokaError {
  let value = eval_expr(runtime, env_id, subject)
  for case_ in cases {
    let case_env = runtime.new_env(env_id)
    if pattern_matches(runtime, case_env, case_.pattern, value) {
      return eval_expr(runtime, case_env, case_.body)
    }
  }
  runtime_error("non-exhaustive match")
}

///|
fn pattern_matches(
  runtime : Runtime,
  env_id : Int,
  pattern : Pattern,
  value : Value,
) -> Bool {
  match pattern {
    Pattern::Wildcard => true
    Pattern::Binding(name) => {
      runtime.bind_value(env_id, name, value, false)
      true
    }
    Pattern::Null => value_equal(value, Value::Null)
    Pattern::Bool(flag) => value_equal(value, Value::Bool(flag))
    Pattern::Int(number) => value_equal(value, Value::Int(number))
    Pattern::String(text) => value_equal(value, Value::String(text))
    Pattern::List(patterns) =>
      match value {
        Value::List(items) => {
          guard patterns.length() == items.length() else { return false }
          for i in 0..<patterns.length() {
            guard pattern_matches(runtime, env_id, patterns[i], items[i]) else {
              return false
            }
          }
          true
        }
        _ => false
      }
  }
}

///|
fn eval_unary(op : String, value : Value) -> Value raise MokaError {
  match op {
    "!" => Value::Bool(!is_truthy(value))
    "-" =>
      match value {
        Value::Int(number) => Value::Int(-number)
        _ => runtime_error("unary '-' expects an int")
      }
    _ => runtime_error("unknown unary operator '\{op}'")
  }
}

///|
fn eval_binary(
  runtime : Runtime,
  env_id : Int,
  op : String,
  left_expr : Expr,
  right_expr : Expr,
) -> Value raise MokaError {
  if op == "&&" {
    let left = eval_expr(runtime, env_id, left_expr)
    if is_truthy(left) {
      Value::Bool(is_truthy(eval_expr(runtime, env_id, right_expr)))
    } else {
      Value::Bool(false)
    }
  } else if op == "||" {
    let left = eval_expr(runtime, env_id, left_expr)
    if is_truthy(left) {
      Value::Bool(true)
    } else {
      Value::Bool(is_truthy(eval_expr(runtime, env_id, right_expr)))
    }
  } else {
    let left = eval_expr(runtime, env_id, left_expr)
    let right = eval_expr(runtime, env_id, right_expr)
    eval_binary_values(op, left, right)
  }
}

///|
fn eval_binary_values(
  op : String,
  left : Value,
  right : Value,
) -> Value raise MokaError {
  match op {
    "+" =>
      match left {
        Value::Int(a) =>
          match right {
            Value::Int(b) => Value::Int(a + b)
            Value::String(b) => Value::String(a.to_string() + b)
            _ => runtime_error("unsupported operands for '+'")
          }
        Value::String(a) => Value::String(a + value_to_plain_string(right))
        _ =>
          match right {
            Value::String(b) => Value::String(value_to_plain_string(left) + b)
            _ => runtime_error("unsupported operands for '+'")
          }
      }
    "-" =>
      match left {
        Value::Int(a) =>
          match right {
            Value::Int(b) => Value::Int(a - b)
            _ => runtime_error("unsupported operands for '-'")
          }
        _ => runtime_error("unsupported operands for '-'")
      }
    "*" =>
      match left {
        Value::Int(a) =>
          match right {
            Value::Int(b) => Value::Int(a * b)
            _ => runtime_error("unsupported operands for '*'")
          }
        _ => runtime_error("unsupported operands for '*'")
      }
    "/" =>
      match left {
        Value::Int(a) =>
          match right {
            Value::Int(0) => runtime_error("division by zero")
            Value::Int(b) => Value::Int(a / b)
            _ => runtime_error("unsupported operands for '/'")
          }
        _ => runtime_error("unsupported operands for '/'")
      }
    "%" =>
      match left {
        Value::Int(a) =>
          match right {
            Value::Int(0) => runtime_error("modulo by zero")
            Value::Int(b) => Value::Int(a % b)
            _ => runtime_error("unsupported operands for '%'")
          }
        _ => runtime_error("unsupported operands for '%'")
      }
    "==" => Value::Bool(value_equal(left, right))
    "!=" => Value::Bool(!value_equal(left, right))
    "<" => compare_values(left, right, (a, b) => a < b)
    "<=" => compare_values(left, right, (a, b) => a <= b)
    ">" => compare_values(left, right, (a, b) => a > b)
    ">=" => compare_values(left, right, (a, b) => a >= b)
    _ => runtime_error("unknown binary operator '\{op}'")
  }
}

///|
fn compare_values(
  left : Value,
  right : Value,
  cmp : (Int, Int) -> Bool,
) -> Value raise MokaError {
  match left {
    Value::Int(a) =>
      match right {
        Value::Int(b) => Value::Bool(cmp(a, b))
        _ => runtime_error("comparison expects matching operands")
      }
    Value::String(a) =>
      match right {
        Value::String(b) => Value::Bool(cmp(a.compare(b), 0))
        _ => runtime_error("comparison expects matching operands")
      }
    _ => runtime_error("comparison expects ints or strings")
  }
}

///|
fn eval_index(target : Value, index : Value) -> Value raise MokaError {
  guard index is Value::Int(position) else {
    runtime_error("index must be an int")
  }
  guard position >= 0 else { runtime_error("index must be non-negative") }
  match target {
    Value::List(items) => {
      guard items.get(position) is Some(value) else {
        runtime_error("list index out of bounds")
      }
      value
    }
    Value::String(text) => {
      guard position < text.length() else {
        runtime_error("string index out of bounds")
      }
      Value::String(text.unsafe_get(position).to_string())
    }
    _ => runtime_error("only lists and strings can be indexed")
  }
}

///|
fn apply_function(
  runtime : Runtime,
  callee : Value,
  args : Array[Value],
) -> Value raise MokaError {
  guard callee is Value::Function(function) else {
    runtime_error("attempted to call a non-function")
  }
  match function {
    FunctionValue::Native(native) => {
      guard args.length() == native.arity else {
        runtime_error(
          "function '\{native.name}' expected \{native.arity} arguments but got \{args.length()}",
        )
      }
      (native.call)(runtime, args)
    }
    FunctionValue::User(closure) => {
      guard args.length() == closure.params.length() else {
        let name = closure.name.unwrap_or("<fn>")
        runtime_error(
          "function '\{name}' expected \{closure.params.length()} arguments but got \{args.length()}",
        )
      }
      let local_env = runtime.new_env(closure.env)
      for i in 0..<closure.params.length() {
        runtime.bind_value(local_env, closure.params[i], args[i], false)
      }
      eval_expr(runtime, local_env, closure.body)
    }
    FunctionValue::Handler(handler) => {
      guard args.length() == 1 else {
        runtime_error("handler expected 1 argument but got \{args.length()}")
      }
      let handler_env = runtime.new_env(handler.env)
      install_handler_clauses(runtime, handler_env, handler.clauses)
      runtime.dynamic_envs.push(handler_env)
      let result = apply_function(runtime, args[0], []) catch {
        err => {
          runtime.dynamic_envs.pop() |> ignore
          raise err
        }
      }
      let final_result = if handler.return_clause is Some(clause) {
        eval_return_clause(runtime, handler_env, clause, result)
      } else {
        result
      }
      runtime.dynamic_envs.pop() |> ignore
      final_result
    }
  }
}

///|
pub fn eval(source : String) -> String raise MokaError {
  parse(source) |> eval_program() |> render_value()
}
