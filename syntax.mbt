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
  TkReturn
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
priv enum SurfaceArg {
  Expr(SurfaceExpr)
  Lambda(Array[String], SurfaceExpr)
  Block(Array[SurfaceStmt])
}

///|
priv enum SurfaceExpr {
  Null
  Bool(Bool)
  Int(Int)
  String(String)
  Var(String)
  List(Array[SurfaceExpr])
  Unary(String, SurfaceExpr)
  Binary(String, SurfaceExpr, SurfaceExpr)
  If(SurfaceExpr, SurfaceExpr, SurfaceExpr)
  Lambda(Array[String], SurfaceExpr)
  Apply(SurfaceExpr, Array[SurfaceArg])
  DotCall(SurfaceExpr, String, Array[SurfaceArg])
  Index(SurfaceExpr, SurfaceExpr)
  Assign(String, SurfaceExpr)
  Match(SurfaceExpr, Array[SurfaceMatchCase])
  Handler(Array[SurfaceHandlerClause], SurfaceReturnClause?)
  Block(Array[SurfaceStmt])
}

///|
priv struct SurfaceMatchCase {
  pattern : Pattern
  body : SurfaceExpr
}

///|
priv enum SurfaceHandlerClause {
  Val(String, SurfaceExpr)
  Fun(String, Array[String], SurfaceExpr)
}

///|
priv struct SurfaceReturnClause {
  param : String
  body : SurfaceExpr
}

///|
priv enum SurfaceStmt {
  Val(String, SurfaceExpr)
  Var(String, SurfaceExpr)
  Fun(String, Array[String], SurfaceExpr)
  WithOverride(String, Array[String], SurfaceExpr, Array[SurfaceStmt])
  WithExpr(SurfaceWithBinding, SurfaceExpr, Array[SurfaceStmt])
  WithFun(String, Array[String], SurfaceExpr, Array[SurfaceStmt])
  WithVal(String, SurfaceExpr, Array[SurfaceStmt])
  Expr(SurfaceExpr)
}

///|
priv enum SurfaceWithBinding {
  None
  Bind(String)
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
  Handler(Array[HandlerClause], ReturnClause?)
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
priv struct ReturnClause {
  param : String
  body : Expr
}

///|
priv enum Stmt {
  Val(String, Expr)
  Var(String, Expr)
  Fun(String, Array[String], Expr)
  WithOverride(String, Array[String], Expr, Stmt)
  Expr(Expr)
}
