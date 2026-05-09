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
    "return" => TkReturn
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
