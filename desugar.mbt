///|
fn desugar_program(program : Array[SurfaceStmt]) -> Array[Stmt] {
  program.map(desugar_stmt)
}

///|
fn desugar_stmt(stmt : SurfaceStmt) -> Stmt {
  match stmt {
    SurfaceStmt::Val(name, expr) => Stmt::Val(name, desugar_expr(expr))
    SurfaceStmt::Var(name, expr) => Stmt::Var(name, desugar_expr(expr))
    SurfaceStmt::Fun(name, params, body) =>
      Stmt::Fun(name, params, desugar_expr(body))
    SurfaceStmt::WithOverride(name, params, fun_body, body) =>
      Stmt::WithOverride(
        name,
        params,
        desugar_expr(fun_body),
        Stmt::Expr(Expr::Block(desugar_program(body))),
      )
    SurfaceStmt::WithExpr(binding, handler, body) =>
      Stmt::Expr(desugar_expr(append_with_body(handler, binding, body)))
    SurfaceStmt::WithFun(name, params, fun_body, body) =>
      Stmt::Expr(
        desugar_expr(
          append_with_body(
            SurfaceExpr::Handler(
              [SurfaceHandlerClause::Fun(name, params, fun_body)],
              None,
            ),
            SurfaceWithBinding::None,
            body,
          ),
        ),
      )
    SurfaceStmt::WithVal(name, value, body) =>
      Stmt::Expr(
        desugar_expr(
          append_with_body(
            SurfaceExpr::Handler([SurfaceHandlerClause::Val(name, value)], None),
            SurfaceWithBinding::None,
            body,
          ),
        ),
      )
    SurfaceStmt::Expr(expr) => Stmt::Expr(desugar_expr(expr))
  }
}

///|
fn append_with_body(
  handler : SurfaceExpr,
  binding : SurfaceWithBinding,
  body : Array[SurfaceStmt],
) -> SurfaceExpr {
  let lambda_arg = match binding {
    SurfaceWithBinding::None => SurfaceArg::Block(body)
    SurfaceWithBinding::Bind(name) =>
      SurfaceArg::Lambda([name], SurfaceExpr::Block(body))
  }
  append_surface_arg(handler, lambda_arg)
}

///|
fn desugar_expr(expr : SurfaceExpr) -> Expr {
  match expr {
    SurfaceExpr::Null => Expr::Null
    SurfaceExpr::Bool(flag) => Expr::Bool(flag)
    SurfaceExpr::Int(number) => Expr::Int(number)
    SurfaceExpr::String(text) => Expr::String(text)
    SurfaceExpr::Var(name) => Expr::Var(name)
    SurfaceExpr::List(items) => Expr::List(items.map(desugar_expr))
    SurfaceExpr::Unary(op, inner) => Expr::Unary(op, desugar_expr(inner))
    SurfaceExpr::Binary(op, left, right) =>
      Expr::Binary(op, desugar_expr(left), desugar_expr(right))
    SurfaceExpr::If(condition, then_branch, else_branch) =>
      Expr::If(
        desugar_expr(condition),
        desugar_expr(then_branch),
        desugar_expr(else_branch),
      )
    SurfaceExpr::Lambda(params, body) =>
      Expr::Lambda(params, desugar_expr(body))
    SurfaceExpr::Apply(callee, args) =>
      Expr::Call(desugar_expr(callee), args.map(desugar_arg))
    SurfaceExpr::DotCall(target, name, args) =>
      Expr::Call(
        Expr::Var(name),
        [desugar_expr(target)] + args.map(desugar_arg),
      )
    SurfaceExpr::Index(target, index) =>
      Expr::Index(desugar_expr(target), desugar_expr(index))
    SurfaceExpr::Assign(name, value) => Expr::Assign(name, desugar_expr(value))
    SurfaceExpr::Match(subject, cases) =>
      Expr::Match(
        desugar_expr(subject),
        cases.map(fn(case_) {
          { pattern: case_.pattern, body: desugar_expr(case_.body) }
        }),
      )
    SurfaceExpr::Handler(clauses, return_clause) =>
      Expr::Handler(
        clauses.map(desugar_handler_clause),
        return_clause.map(fn(c) {
          { param: c.param, body: desugar_expr(c.body) }
        }),
      )
    SurfaceExpr::Block(stmts) => Expr::Block(desugar_program(stmts))
  }
}

///|
fn desugar_arg(arg : SurfaceArg) -> Expr {
  match arg {
    SurfaceArg::Expr(expr) => desugar_expr(expr)
    SurfaceArg::Lambda(params, body) => Expr::Lambda(params, desugar_expr(body))
    SurfaceArg::Block(stmts) =>
      Expr::Lambda([], Expr::Block(desugar_program(stmts)))
  }
}

///|
fn desugar_handler_clause(clause : SurfaceHandlerClause) -> HandlerClause {
  match clause {
    SurfaceHandlerClause::Val(name, expr) =>
      HandlerClause::Val(name, desugar_expr(expr))
    SurfaceHandlerClause::Fun(name, params, body) =>
      HandlerClause::Fun(name, params, desugar_expr(body))
  }
}
