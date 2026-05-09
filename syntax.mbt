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
