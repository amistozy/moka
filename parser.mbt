///|
priv struct Parser {
  tokens : Array[Token]
  mut index : Int
}

///|
fn Parser::new(tokens : Array[Token]) -> Parser {
  { tokens, index: 0 }
}

///|
fn Parser::peek(self : Parser) -> Token {
  self.tokens[self.index]
}

///|
fn Parser::advance(self : Parser) -> Token {
  let token = self.peek()
  if self.index < self.tokens.length() - 1 {
    self.index += 1
  }
  token
}

///|
fn Parser::at_end(self : Parser) -> Bool {
  self.peek().kind == TkEof
}

///|
fn is_token_kind(kind : TokenKind, target : TokenKind) -> Bool {
  kind == target
}

///|
fn Parser::skip_separators(self : Parser) -> Unit {
  while is_token_kind(self.peek().kind, TkSemi) {
    self.advance() |> ignore
  }
}

///|
fn[T] parser_error(token : Token, message : String) -> T raise MokaError {
  raise Parse("[line \{token.line}, column \{token.column}] \{message}")
}

///|
fn Parser::consume_ident(
  self : Parser,
  context : String,
) -> String raise MokaError {
  let token = self.advance()
  match token.kind {
    TkIdent(name) => name
    _ => parser_error(token, "expected identifier for \{context}")
  }
}

///|
fn Parser::expect_kind(
  self : Parser,
  kind : TokenKind,
  message : String,
) -> Unit raise MokaError {
  let token = self.peek()
  guard token.kind == kind else { parser_error(token, message) }
  self.advance() |> ignore
}

///|
fn Parser::parse_program(self : Parser) -> Array[Stmt] raise MokaError {
  let stmts = self.parse_stmt_list(false)
  guard self.at_end() else {
    parser_error(self.peek(), "unexpected closing brace")
  }
  stmts
}

///|
fn Parser::parse_stmt_list(
  self : Parser,
  until_rbrace : Bool,
) -> Array[Stmt] raise MokaError {
  let stmts : Array[Stmt] = []
  self.skip_separators()
  while !self.at_end() && self.peek().kind != TkRBrace {
    if self.peek().kind == TkWith {
      stmts.push(self.parse_with_statement(until_rbrace))
      self.skip_separators()
      break
    }
    stmts.push(self.parse_plain_statement())
    self.skip_separators()
  }
  stmts
}

///|
fn Parser::parse_plain_statement(self : Parser) -> Stmt raise MokaError {
  match self.peek().kind {
    TkVal => {
      self.advance() |> ignore
      let name = self.consume_ident("value binding")
      self.expect_kind(TkEqual, "expected '=' after value name")
      Stmt::Val(name, self.parse_expr())
    }
    TkVar => {
      self.advance() |> ignore
      let name = self.consume_ident("variable binding")
      self.expect_kind(TkEqual, "expected '=' after variable name")
      Stmt::Var(name, self.parse_expr())
    }
    TkFun => {
      self.advance() |> ignore
      let name = self.consume_ident("function name")
      let params = self.parse_params()
      self.skip_separators()
      Stmt::Fun(name, params, self.parse_expr())
    }
    _ => Stmt::Expr(self.parse_expr())
  }
}

///|
fn Parser::parse_with_statement(
  self : Parser,
  until_rbrace : Bool,
) -> Stmt raise MokaError {
  self.expect_kind(TkWith, "expected 'with'")
  if self.peek().kind == TkOverride {
    self.advance() |> ignore
    let name = self.consume_ident("override binding")
    let params = self.parse_params()
    self.skip_separators()
    let fun_body = self.parse_expr()
    self.skip_separators()
    guard !self.at_end() && !(until_rbrace && self.peek().kind == TkRBrace) else {
      raise Parse("`with override` expects a following statement or block")
    }
    let body = Stmt::Expr(Expr::Block(self.parse_stmt_list(until_rbrace)))
    return Stmt::WithOverride(name, params, fun_body, body)
  }
  if self.peek().kind == TkFun {
    self.advance() |> ignore
    let name = self.consume_ident("dynamic function binding")
    let params = self.parse_params()
    self.skip_separators()
    let fun_body = self.parse_expr()
    self.skip_separators()
    guard !self.at_end() && !(until_rbrace && self.peek().kind == TkRBrace) else {
      raise Parse("`with fun` expects a following statement or block")
    }
    let body = Stmt::Expr(Expr::Block(self.parse_stmt_list(until_rbrace)))
    return Stmt::With(
      WithBinding::None,
      Expr::Handler([HandlerClause::Fun(name, params, fun_body)]),
      body,
    )
  }
  if self.peek().kind == TkVal {
    self.advance() |> ignore
    let name = self.consume_ident("dynamic value binding")
    self.expect_kind(TkEqual, "expected '=' after dynamic value name")
    let value = self.parse_expr()
    self.skip_separators()
    guard !self.at_end() && !(until_rbrace && self.peek().kind == TkRBrace) else {
      raise Parse("`with val` expects a following statement or block")
    }
    let body = Stmt::Expr(Expr::Block(self.parse_stmt_list(until_rbrace)))
    return Stmt::With(
      WithBinding::None,
      Expr::Handler([HandlerClause::Val(name, value)]),
      body,
    )
  }
  let binding = match self.peek().kind {
    TkIdent(name) =>
      if self.index + 1 < self.tokens.length() &&
        self.tokens[self.index + 1].kind == TkLeftArrow {
        self.advance() |> ignore
        self.advance() |> ignore
        WithBinding::Bind(name)
      } else {
        WithBinding::None
      }
    _ => WithBinding::None
  }
  let handler = self.parse_expr()
  self.skip_separators()
  guard !self.at_end() && !(until_rbrace && self.peek().kind == TkRBrace) else {
    raise Parse("`with` expects a following statement or block")
  }
  let body = Stmt::Expr(Expr::Block(self.parse_stmt_list(until_rbrace)))
  Stmt::With(binding, handler, body)
}

///|
fn Parser::finish_handler(self : Parser) -> Expr raise MokaError {
  self.skip_separators()
  self.expect_kind(TkLBrace, "expected an indented handler block or '{'")
  self.skip_separators()
  let clauses : Array[HandlerClause] = []
  while self.peek().kind != TkRBrace {
    clauses.push(self.parse_handler_clause())
    self.skip_separators()
  }
  self.expect_kind(TkRBrace, "expected '}' after handler clauses")
  Expr::Handler(clauses)
}

///|
fn Parser::parse_handler_clause(self : Parser) -> HandlerClause raise MokaError {
  match self.peek().kind {
    TkVal => {
      self.advance() |> ignore
      let name = self.consume_ident("handler value clause")
      self.expect_kind(TkEqual, "expected '=' after handler value name")
      HandlerClause::Val(name, self.parse_expr())
    }
    TkFun => {
      self.advance() |> ignore
      let name = self.consume_ident("handler function clause")
      let params = self.parse_params()
      self.skip_separators()
      HandlerClause::Fun(name, params, self.parse_expr())
    }
    _ => parser_error(self.peek(), "expected `val` or `fun` in handler")
  }
}

///|
fn Parser::parse_params(self : Parser) -> Array[String] raise MokaError {
  self.expect_kind(TkLParen, "expected '('")
  let params : Array[String] = []
  if self.peek().kind != TkRParen {
    while true {
      params.push(self.consume_ident("parameter"))
      guard self.peek().kind == TkComma else { break }
      self.advance() |> ignore
    }
  }
  self.expect_kind(TkRParen, "expected ')' after parameters")
  params
}

///|
fn Parser::parse_expr(self : Parser) -> Expr raise MokaError {
  self.parse_assignment()
}

///|
fn Parser::parse_assignment(self : Parser) -> Expr raise MokaError {
  let expr = self.parse_or()
  if self.peek().kind == TkColonEqual {
    let token = self.advance()
    let value = self.parse_assignment()
    match expr {
      Expr::Var(name) => Expr::Assign(name, value)
      _ => parser_error(token, "invalid assignment target")
    }
  } else {
    expr
  }
}

///|
fn Parser::parse_or(self : Parser) -> Expr raise MokaError {
  let mut expr = self.parse_and()
  while self.peek().kind == TkOrOr {
    self.advance() |> ignore
    expr = Expr::Binary("||", expr, self.parse_and())
  }
  expr
}

///|
fn Parser::parse_and(self : Parser) -> Expr raise MokaError {
  let mut expr = self.parse_equality()
  while self.peek().kind == TkAndAnd {
    self.advance() |> ignore
    expr = Expr::Binary("&&", expr, self.parse_equality())
  }
  expr
}

///|
fn Parser::parse_equality(self : Parser) -> Expr raise MokaError {
  let mut expr = self.parse_comparison()
  while true {
    match self.peek().kind {
      TkEqualEqual => {
        self.advance() |> ignore
        expr = Expr::Binary("==", expr, self.parse_comparison())
      }
      TkBangEqual => {
        self.advance() |> ignore
        expr = Expr::Binary("!=", expr, self.parse_comparison())
      }
      _ => break
    }
  }
  expr
}

///|
fn Parser::parse_comparison(self : Parser) -> Expr raise MokaError {
  let mut expr = self.parse_term()
  while true {
    match self.peek().kind {
      TkLess => {
        self.advance() |> ignore
        expr = Expr::Binary("<", expr, self.parse_term())
      }
      TkLessEqual => {
        self.advance() |> ignore
        expr = Expr::Binary("<=", expr, self.parse_term())
      }
      TkGreater => {
        self.advance() |> ignore
        expr = Expr::Binary(">", expr, self.parse_term())
      }
      TkGreaterEqual => {
        self.advance() |> ignore
        expr = Expr::Binary(">=", expr, self.parse_term())
      }
      _ => break
    }
  }
  expr
}

///|
fn Parser::parse_term(self : Parser) -> Expr raise MokaError {
  let mut expr = self.parse_factor()
  while true {
    match self.peek().kind {
      TkPlus => {
        self.advance() |> ignore
        expr = Expr::Binary("+", expr, self.parse_factor())
      }
      TkMinus => {
        self.advance() |> ignore
        expr = Expr::Binary("-", expr, self.parse_factor())
      }
      _ => break
    }
  }
  expr
}

///|
fn Parser::parse_factor(self : Parser) -> Expr raise MokaError {
  let mut expr = self.parse_unary()
  while true {
    match self.peek().kind {
      TkStar => {
        self.advance() |> ignore
        expr = Expr::Binary("*", expr, self.parse_unary())
      }
      TkSlash => {
        self.advance() |> ignore
        expr = Expr::Binary("/", expr, self.parse_unary())
      }
      TkPercent => {
        self.advance() |> ignore
        expr = Expr::Binary("%", expr, self.parse_unary())
      }
      _ => break
    }
  }
  expr
}

///|
fn Parser::parse_unary(self : Parser) -> Expr raise MokaError {
  match self.peek().kind {
    TkBang => {
      self.advance() |> ignore
      Expr::Unary("!", self.parse_unary())
    }
    TkMinus => {
      self.advance() |> ignore
      Expr::Unary("-", self.parse_unary())
    }
    _ => self.parse_postfix()
  }
}

///|
fn Parser::parse_postfix(self : Parser) -> Expr raise MokaError {
  let mut expr = self.parse_primary()
  while true {
    match self.peek().kind {
      TkLParen => {
        let args = self.parse_arguments()
        expr = Expr::Call(expr, args)
      }
      TkLBrace if can_take_suspender(expr) =>
        expr = Expr::Call(expr, [self.parse_suspender()])
      TkLBracket => {
        self.advance() |> ignore
        let index = self.parse_expr()
        self.expect_kind(TkRBracket, "expected ']' after index")
        expr = Expr::Index(expr, index)
      }
      TkDot => {
        self.advance() |> ignore
        let name = self.consume_ident("dot call")
        let args = if self.peek().kind == TkLParen {
          [expr] + self.parse_arguments()
        } else {
          [expr]
        }
        expr = Expr::Call(Expr::Var(name), args)
      }
      _ => break
    }
  }
  expr
}

///|
fn can_take_suspender(expr : Expr) -> Bool {
  match expr {
    Expr::Var(_) | Expr::Call(_, _) | Expr::Index(_, _) => true
    _ => false
  }
}

///|
fn Parser::parse_suspender(self : Parser) -> Expr raise MokaError {
  self.expect_kind(TkLBrace, "expected '{' to start a suspender block")
  Expr::Lambda([], Expr::Block(self.finish_block()))
}

///|
fn Parser::parse_arguments(self : Parser) -> Array[Expr] raise MokaError {
  self.expect_kind(TkLParen, "expected '('")
  let args : Array[Expr] = []
  if self.peek().kind != TkRParen {
    while true {
      args.push(self.parse_expr())
      guard self.peek().kind == TkComma else { break }
      self.advance() |> ignore
    }
  }
  self.expect_kind(TkRParen, "expected ')' after arguments")
  args
}

///|
fn Parser::parse_primary(self : Parser) -> Expr raise MokaError {
  let token = self.advance()
  match token.kind {
    TkInt(value) => Expr::Int(value)
    TkString(value) => Expr::String(value)
    TkTrue => Expr::Bool(true)
    TkFalse => Expr::Bool(false)
    TkNull => Expr::Null
    TkIdent(name) => Expr::Var(name)
    TkLParen => {
      let expr = self.parse_expr()
      self.expect_kind(TkRParen, "expected ')' after expression")
      expr
    }
    TkLBracket => self.finish_list()
    TkMatch => self.finish_match()
    TkHandler => self.finish_handler()
    TkLBrace => Expr::Block(self.finish_block())
    TkIf => self.finish_if()
    TkFn => {
      let params = self.parse_params()
      self.skip_separators()
      Expr::Lambda(params, self.parse_expr())
    }
    _ => parser_error(token, "unexpected token in expression")
  }
}

///|
fn Parser::finish_match(self : Parser) -> Expr raise MokaError {
  let subject = self.parse_expr()
  self.skip_separators()
  self.expect_kind(TkLBrace, "expected '{' after match subject")
  self.skip_separators()
  let cases : Array[MatchCase] = []
  while self.peek().kind != TkRBrace {
    let pattern = self.parse_pattern()
    self.expect_kind(
      TkRightArrow,
      "expected '->' between match pattern and body",
    )
    let body = self.parse_expr()
    cases.push({ pattern, body })
    self.skip_separators()
  }
  self.expect_kind(TkRBrace, "expected '}' after match cases")
  Expr::Match(subject, cases)
}

///|
fn Parser::parse_pattern(self : Parser) -> Pattern raise MokaError {
  let token = self.advance()
  match token.kind {
    TkNull => Pattern::Null
    TkTrue => Pattern::Bool(true)
    TkFalse => Pattern::Bool(false)
    TkInt(value) => Pattern::Int(value)
    TkString(value) => Pattern::String(value)
    TkIdent(name) =>
      if name == "_" {
        Pattern::Wildcard
      } else {
        Pattern::Binding(name)
      }
    TkLBracket => self.finish_list_pattern()
    _ => parser_error(token, "unsupported match pattern")
  }
}

///|
fn Parser::finish_list_pattern(self : Parser) -> Pattern raise MokaError {
  let items : Array[Pattern] = []
  if self.peek().kind != TkRBracket {
    while true {
      items.push(self.parse_pattern())
      guard self.peek().kind == TkComma else { break }
      self.advance() |> ignore
    }
  }
  self.expect_kind(TkRBracket, "expected ']' after list pattern")
  Pattern::List(items)
}

///|
fn Parser::finish_list(self : Parser) -> Expr raise MokaError {
  let items : Array[Expr] = []
  if self.peek().kind != TkRBracket {
    while true {
      items.push(self.parse_expr())
      guard self.peek().kind == TkComma else { break }
      self.advance() |> ignore
    }
  }
  self.expect_kind(TkRBracket, "expected ']' after list literal")
  Expr::List(items)
}

///|
fn Parser::finish_block(self : Parser) -> Array[Stmt] raise MokaError {
  let stmts = self.parse_stmt_list(true)
  guard !self.at_end() else { raise Parse("unterminated block") }
  self.expect_kind(TkRBrace, "expected '}' after block")
  stmts
}

///|
fn Parser::finish_if(self : Parser) -> Expr raise MokaError {
  let condition = self.parse_expr()
  self.skip_separators()
  if self.peek().kind == TkThen {
    self.advance() |> ignore
  }
  let then_branch = self.parse_expr()
  self.skip_separators()
  let else_branch = if self.peek().kind == TkElif {
    self.advance() |> ignore
    self.finish_if()
  } else {
    self.expect_kind(TkElse, "expected 'else' in if expression")
    self.skip_separators()
    self.parse_expr()
  }
  Expr::If(condition, then_branch, else_branch)
}

///|
fn parse(source : String) -> Array[Stmt] raise MokaError {
  Parser::new(tokenize(source)).parse_program()
}
