///|
pub(all) suberror MokaError {
  Parse(String)
  Runtime(String)
}

///|
pub impl Show for MokaError with output(self, logger) {
  match self {
    Parse(message) => {
      logger.write_string("parse error: ")
      logger.write_string(message)
    }
    Runtime(message) => {
      logger.write_string("runtime error: ")
      logger.write_string(message)
    }
  }
}

///|
priv enum TokenKind {
  TkEof
  TkSemi
  TkComma
  TkDot
  TkLParen
  TkRParen
  TkLBrace
  TkRBrace
  TkLBracket
  TkRBracket
  TkPlus
  TkMinus
  TkStar
  TkSlash
  TkPercent
  TkBang
  TkBangEqual
  TkEqualEqual
  TkLess
  TkLessEqual
  TkGreater
  TkGreaterEqual
  TkAndAnd
  TkOrOr
  TkEqual
  TkColonEqual
  TkIdent(String)
  TkInt(Int)
  TkString(String)
  TkVal
  TkVar
  TkFun
  TkFn
  TkHandler
  TkIf
  TkMatch
  TkWith
  TkOverride
  TkThen
  TkElif
  TkElse
  TkLeftArrow
  TkRightArrow
  TkTrue
  TkFalse
  TkNull
} derive(Eq)

///|
priv struct Token {
  kind : TokenKind
  line : Int
  column : Int
  inserted : Bool
}

///|
priv enum Expr {
  Null
  Bool(Bool)
  Int(Int)
  String(String)
  Var(String)
  List(Array[Expr])
  Unary(String, Expr)
  Binary(String, Expr, Expr)
  If(Expr, Expr, Expr)
  Lambda(Array[String], Expr)
  Call(Expr, Array[Expr])
  Index(Expr, Expr)
  Assign(String, Expr)
  Match(Expr, Array[MatchCase])
  Handler(Array[HandlerClause])
  Block(Array[Stmt])
}

///|
priv struct MatchCase {
  pattern : Pattern
  body : Expr
}

///|
priv enum Pattern {
  Wildcard
  Binding(String)
  Null
  Bool(Bool)
  Int(Int)
  String(String)
  List(Array[Pattern])
}

///|
priv enum HandlerClause {
  Val(String, Expr)
  Fun(String, Array[String], Expr)
}

///|
priv enum Stmt {
  Val(String, Expr)
  Var(String, Expr)
  Fun(String, Array[String], Expr)
  WithOverride(String, Array[String], Expr, Stmt)
  With(WithBinding, Expr, Stmt)
  Expr(Expr)
}

///|
priv enum WithBinding {
  None
  Bind(String)
}

///|
priv struct Lexer {
  chars : Array[Char]
  mut index : Int
  mut line : Int
  mut column : Int
}

///|
fn Lexer::new(source : String) -> Lexer {
  { chars: source.iter().to_array(), index: 0, line: 1, column: 0 }
}

///|
fn Lexer::at_end(self : Lexer) -> Bool {
  self.index >= self.chars.length()
}

///|
fn Lexer::peek(self : Lexer) -> Char? {
  if self.at_end() {
    None
  } else {
    Some(self.chars[self.index])
  }
}

///|
fn Lexer::peek_next(self : Lexer) -> Char? {
  if self.index + 1 >= self.chars.length() {
    None
  } else {
    Some(self.chars[self.index + 1])
  }
}

///|
fn Lexer::advance(self : Lexer) -> Char {
  let ch = self.chars[self.index]
  self.index += 1
  if ch == '\n' {
    self.line += 1
    self.column = 0
  } else {
    self.column += 1
  }
  ch
}

///|
fn Lexer::match_char(self : Lexer, expected : Char) -> Bool {
  guard self.peek() == Some(expected) else { return false }
  self.advance() |> ignore
  true
}

///|
fn is_ident_start(ch : Char) -> Bool {
  ch.is_ascii_alphabetic() || ch == '_'
}

///|
fn is_ident_continue(ch : Char) -> Bool {
  is_ident_start(ch) || ch.is_digit(10)
}

///|
fn[T] parse_error(
  line : Int,
  column : Int,
  message : String,
) -> T raise MokaError {
  raise Parse("[line \{line}, column \{column}] \{message}")
}

///|
fn keyword_or_ident(name : String) -> TokenKind {
  match name {
    "val" => TkVal
    "var" => TkVar
    "fun" => TkFun
    "fn" => TkFn
    "handler" => TkHandler
    "if" => TkIf
    "match" => TkMatch
    "with" => TkWith
    "override" => TkOverride
    "then" => TkThen
    "elif" => TkElif
    "else" => TkElse
    "true" => TkTrue
    "false" => TkFalse
    "null" => TkNull
    _ => TkIdent(name)
  }
}

///|
fn make_token(kind : TokenKind, line : Int, column : Int) -> Token {
  { kind, line, column, inserted: false }
}

///|
fn make_inserted_token(kind : TokenKind, line : Int, column : Int) -> Token {
  { kind, line, column, inserted: true }
}

///|
fn Lexer::skip_line_comment(self : Lexer) -> Unit {
  while self.peek() is Some(ch) && ch != '\n' {
    self.advance() |> ignore
  }
}

///|
fn Lexer::read_number(self : Lexer, line : Int, column : Int) -> Token {
  let mut value = 0
  while self.peek() is Some(ch) && ch.is_digit(10) {
    value = value * 10 + (self.advance().to_int() - '0'.to_int())
  }
  make_token(TkInt(value), line, column)
}

///|
fn Lexer::read_ident(self : Lexer, line : Int, column : Int) -> Token {
  let start = self.index
  self.advance() |> ignore
  while self.peek() is Some(ch) && is_ident_continue(ch) {
    self.advance() |> ignore
  }
  let name = String::from_iter(self.chars[start:self.index].iter())
  make_token(keyword_or_ident(name), line, column)
}

///|
fn Lexer::read_string(
  self : Lexer,
  line : Int,
  column : Int,
) -> Token raise MokaError {
  self.advance() |> ignore
  let buffer : Array[Char] = []
  while self.peek() is Some(ch) {
    if ch == '"' {
      self.advance() |> ignore
      return make_token(TkString(String::from_array(buffer)), line, column)
    }
    if ch == '\\' {
      self.advance() |> ignore
      guard self.peek() is Some(escaped) else {
        parse_error(line, column, "unterminated string literal")
      }
      match escaped {
        'n' => {
          self.advance() |> ignore
          buffer.push('\n')
        }
        't' => {
          self.advance() |> ignore
          buffer.push('\t')
        }
        '"' => {
          self.advance() |> ignore
          buffer.push('"')
        }
        '\\' => {
          self.advance() |> ignore
          buffer.push('\\')
        }
        _ => parse_error(line, column, "unsupported escape sequence")
      }
    } else {
      buffer.push(self.advance())
    }
  }
  parse_error(line, column, "unterminated string literal")
}

///|
fn lex_tokens(source : String) -> Array[Token] raise MokaError {
  let lexer = Lexer::new(source)
  let tokens : Array[Token] = []
  while !lexer.at_end() {
    let line = lexer.line
    let column = lexer.column
    match lexer.peek() {
      None => break
      Some(ch) if ch == ' ' || ch == '\t' || ch == '\r' =>
        lexer.advance() |> ignore
      Some('\n') => lexer.advance() |> ignore
      Some('/') if lexer.peek_next() == Some('/') => lexer.skip_line_comment()
      Some('"') => tokens.push(lexer.read_string(line, column))
      Some(ch) if ch.is_digit(10) =>
        tokens.push(lexer.read_number(line, column))
      Some(ch) if is_ident_start(ch) =>
        tokens.push(lexer.read_ident(line, column))
      Some('(') => {
        lexer.advance() |> ignore
        tokens.push(make_token(TkLParen, line, column))
      }
      Some(')') => {
        lexer.advance() |> ignore
        tokens.push(make_token(TkRParen, line, column))
      }
      Some('{') => {
        lexer.advance() |> ignore
        tokens.push(make_token(TkLBrace, line, column))
      }
      Some('}') => {
        lexer.advance() |> ignore
        tokens.push(make_token(TkRBrace, line, column))
      }
      Some('[') => {
        lexer.advance() |> ignore
        tokens.push(make_token(TkLBracket, line, column))
      }
      Some(']') => {
        lexer.advance() |> ignore
        tokens.push(make_token(TkRBracket, line, column))
      }
      Some(',') => {
        lexer.advance() |> ignore
        tokens.push(make_token(TkComma, line, column))
      }
      Some(';') => {
        lexer.advance() |> ignore
        tokens.push(make_token(TkSemi, line, column))
      }
      Some('.') => {
        lexer.advance() |> ignore
        tokens.push(make_token(TkDot, line, column))
      }
      Some('+') => {
        lexer.advance() |> ignore
        tokens.push(make_token(TkPlus, line, column))
      }
      Some('-') => {
        lexer.advance() |> ignore
        let kind = if lexer.match_char('>') { TkRightArrow } else { TkMinus }
        tokens.push(make_token(kind, line, column))
      }
      Some('*') => {
        lexer.advance() |> ignore
        tokens.push(make_token(TkStar, line, column))
      }
      Some('/') => {
        lexer.advance() |> ignore
        tokens.push(make_token(TkSlash, line, column))
      }
      Some('%') => {
        lexer.advance() |> ignore
        tokens.push(make_token(TkPercent, line, column))
      }
      Some('!') => {
        lexer.advance() |> ignore
        let kind = if lexer.match_char('=') { TkBangEqual } else { TkBang }
        tokens.push(make_token(kind, line, column))
      }
      Some('=') => {
        lexer.advance() |> ignore
        let kind = if lexer.match_char('=') { TkEqualEqual } else { TkEqual }
        tokens.push(make_token(kind, line, column))
      }
      Some(':') => {
        lexer.advance() |> ignore
        guard lexer.match_char('=') else {
          parse_error(line, column, "expected '=' after ':'")
        }
        tokens.push(make_token(TkColonEqual, line, column))
      }
      Some('<') => {
        lexer.advance() |> ignore
        let kind = if lexer.match_char('=') {
          TkLessEqual
        } else if lexer.match_char('-') {
          TkLeftArrow
        } else {
          TkLess
        }
        tokens.push(make_token(kind, line, column))
      }
      Some('>') => {
        lexer.advance() |> ignore
        let kind = if lexer.match_char('=') {
          TkGreaterEqual
        } else {
          TkGreater
        }
        tokens.push(make_token(kind, line, column))
      }
      Some('&') => {
        lexer.advance() |> ignore
        guard lexer.match_char('&') else {
          parse_error(line, column, "expected second '&'")
        }
        tokens.push(make_token(TkAndAnd, line, column))
      }
      Some('|') => {
        lexer.advance() |> ignore
        guard lexer.match_char('|') else {
          parse_error(line, column, "expected second '|'")
        }
        tokens.push(make_token(TkOrOr, line, column))
      }
      Some(other) =>
        parse_error(line, column, "unexpected character '\{other}'")
    }
  }
  tokens.push(make_token(TkEof, lexer.line, lexer.column))
  tokens
}

///|
priv struct LayoutContext {
  open : Token
  column : Int
}

///|
fn is_semi_token(token : Token) -> Bool {
  token.kind == TkSemi
}

///|
fn is_open_brace_token(token : Token) -> Bool {
  token.kind == TkLBrace
}

///|
fn is_close_brace_token(token : Token) -> Bool {
  token.kind == TkRBrace
}

///|
fn is_start_continuation_token(kind : TokenKind) -> Bool {
  match kind {
    TkRParen
    | TkRBracket
    | TkComma
    | TkLBrace
    | TkRBrace
    | TkThen
    | TkElse
    | TkElif
    | TkRightArrow
    | TkEqual
    | TkColonEqual
    | TkDot
    | TkPlus
    | TkMinus
    | TkStar
    | TkSlash
    | TkPercent
    | TkEqualEqual
    | TkBangEqual
    | TkLess
    | TkLessEqual
    | TkGreater
    | TkGreaterEqual
    | TkAndAnd
    | TkOrOr => true
    _ => false
  }
}

///|
fn is_end_continuation_token(kind : TokenKind) -> Bool {
  match kind {
    TkLParen
    | TkLBracket
    | TkComma
    | TkLBrace
    | TkDot
    | TkPlus
    | TkMinus
    | TkStar
    | TkSlash
    | TkPercent
    | TkEqualEqual
    | TkBangEqual
    | TkLess
    | TkLessEqual
    | TkGreater
    | TkGreaterEqual
    | TkAndAnd
    | TkOrOr => true
    _ => false
  }
}

///|
fn is_expr_continuation(prev : Token, next : Token) -> Bool {
  is_start_continuation_token(next.kind) || is_end_continuation_token(prev.kind)
}

///|
fn insert_semi(tokens : Array[Token], prev : Token) -> Unit {
  if !is_semi_token(prev) {
    tokens.push(make_inserted_token(TkSemi, prev.line, prev.column))
  }
}

///|
fn layout_tokens(raw_tokens : Array[Token]) -> Array[Token] raise MokaError {
  guard raw_tokens.length() > 0 else { return [] }
  let eof = raw_tokens[raw_tokens.length() - 1]
  let result : Array[Token] = []
  if raw_tokens.length() == 1 {
    result.push(eof)
    return result
  }
  let first = raw_tokens[0]
  let start = make_inserted_token(TkSemi, first.line, -1)
  let layouts : Array[LayoutContext] = []
  let mut current = { open: start, column: 0 }
  let mut prev = start
  let mut index = 0
  while index < raw_tokens.length() - 1 {
    let token = raw_tokens[index]
    let newline = token.line > prev.line
    let indent = token.column
    if newline && indent > current.column && !is_expr_continuation(prev, token) {
      let inserted = make_inserted_token(TkLBrace, prev.line, prev.column)
      result.push(inserted)
      layouts.push(current)
      current = { open: inserted, column: indent }
      prev = inserted
      continue
    }
    if newline &&
      indent < current.column &&
      !(is_close_brace_token(token) &&
      !token.inserted &&
      current.open.kind == TkLBrace &&
      !current.open.inserted) {
      insert_semi(result, prev)
      let inserted = make_inserted_token(TkRBrace, prev.line, prev.column)
      result.push(inserted)
      guard layouts.pop() is Some(layout) else {
        raise Parse(
          "[line \{token.line}, column \{token.column}] invalid indentation",
        )
      }
      current = layout
      prev = inserted
      continue
    }
    if is_open_brace_token(token) {
      result.push(token)
      let next_indent = if index + 1 < raw_tokens.length() - 1 {
        raw_tokens[index + 1].column
      } else {
        current.column + 1
      }
      layouts.push(current)
      current = { open: token, column: next_indent }
      prev = token
      index += 1
      continue
    }
    if is_close_brace_token(token) {
      insert_semi(result, prev)
      result.push(token)
      guard layouts.pop() is Some(layout) else {
        raise Parse(
          "[line \{token.line}, column \{token.column}] unmatched closing brace",
        )
      }
      current = layout
      prev = token
      index += 1
      continue
    }
    if newline && indent == current.column && !is_expr_continuation(prev, token) {
      insert_semi(result, prev)
    }
    result.push(token)
    prev = token
    index += 1
  }
  while layouts.length() > 0 {
    insert_semi(result, prev)
    let inserted = make_inserted_token(TkRBrace, prev.line, prev.column)
    result.push(inserted)
    prev = inserted
    guard layouts.pop() is Some(layout) else { break }
    current = layout
  }
  result.push(eof)
  result
}

///|
fn tokenize(source : String) -> Array[Token] raise MokaError {
  layout_tokens(lex_tokens(source))
}

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
  env : Int
}

///|
priv struct NativeFn {
  name : String
  arity : Int
  call : (Array[Value]) -> Value raise MokaError
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
    call: (args : Array[Value]) => builtin_len(args),
  })
  runtime.install_native(global_env, {
    name: "type",
    arity: 1,
    call: (args : Array[Value]) => Value::String(type_name(args[0])),
  })
  runtime.install_native(global_env, {
    name: "str",
    arity: 1,
    call: (args : Array[Value]) => Value::String(value_to_plain_string(args[0])),
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
fn builtin_len(args : Array[Value]) -> Value raise MokaError {
  match args[0] {
    Value::String(text) => Value::Int(text.length())
    Value::List(items) => Value::Int(items.length())
    _ => runtime_error("len expects a string or list")
  }
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
    Stmt::With(binding, handler, body) =>
      eval_with_stmt(runtime, env_id, binding, handler, body)
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
    Expr::Handler(clauses) =>
      Value::Function(FunctionValue::Handler({ clauses, env: env_id }))
    Expr::Block(stmts) => {
      let block_env = runtime.new_env(env_id)
      eval_statements(runtime, block_env, stmts)
    }
  }
}

///|
fn stmt_to_block_expr(stmt : Stmt) -> Expr {
  Expr::Block([stmt])
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
fn eval_with_stmt(
  runtime : Runtime,
  env_id : Int,
  binding : WithBinding,
  handler : Expr,
  body : Stmt,
) -> Value raise MokaError {
  let fn_value = match binding {
    WithBinding::None =>
      Value::Function(
        FunctionValue::User(UserClosure::{
          name: None,
          params: [],
          body: stmt_to_block_expr(body),
          env: env_id,
        }),
      )
    WithBinding::Bind(name) =>
      Value::Function(
        FunctionValue::User(UserClosure::{
          name: None,
          params: [name],
          body: stmt_to_block_expr(body),
          env: env_id,
        }),
      )
  }
  apply_function(runtime, eval_expr(runtime, env_id, handler), [fn_value])
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
      (native.call)(args)
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
      runtime.dynamic_envs.pop() |> ignore
      result
    }
  }
}

///|
pub fn eval(source : String) -> String raise MokaError {
  parse(source) |> eval_program() |> render_value()
}
