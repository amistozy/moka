// Whitebox tests run within the package scope.
// Use them to validate internal helpers or invariants.
// Keep them focused; public behavior belongs in `_test.mbt`.

///|
test "desugar appends with-binding body as final lambda argument" {
  let source =
    #|with x <- foo(1, 2)
    #|x + 3
  let surface = Parser::new(tokenize(source)).parse_surface_program()
  let core = desugar_program(surface)
  match core {
    [Stmt::Expr(Expr::Call(Expr::Var("foo"), args))] => {
      assert_eq(args.length(), 3)
      assert_true(args[0] is Expr::Int(1))
      assert_true(args[1] is Expr::Int(2))
      assert_true(args[2] is Expr::Lambda(["x"], Expr::Block(_)))
    }
    _ => fail("expected desugared with-binding call")
  }
}
