
import system except NimNode
import compiler/[ast, lineinfos, idents]
import utils

type
  NimNode* = PNode

forwardEnums("NimNodeKind", "n", TNodeKind)
forwardEnums("NimTypeKind", "n", TTypeKind)
forwardEnums("NimSymKind", "n", TSymKind)

template `ident=`*[T](nn: var NimNode, i: T) =
  discard

var cache = newIdentCache()

template benign*(p: untyped) = p

proc newNimNode*(kind: NimNodeKind): NimNode =
  result = newNode(TNodeKind(kind.ord()))

# proc newTree*(kind: NimNodeKind; children: varargs[NimNode]): NimNode =
#   result = ast.newTree(TNodeKind(kind.ord()), children)

proc ident*(name: string): NimNode =
  result = newIdentNode(cache.getIdent(name), unknownLineInfo)

proc newIdentNode*(name: string): NimNode =
  result = newIdentNode(cache.getIdent(name), unknownLineInfo)

when false:
  proc getImpl*(node: NimNode): NimNode = 
    # of opcGetImpl:
    decodeB(rkNode)
    var a = regs[rb].node
    if a.kind == nkVarTy: a = a[0]
    if a.kind == nkSym:
      regs[ra].node = if a.sym.ast.isNil: newNode(nkNilLit)
                      else: copyTree(a.sym.ast)
      regs[ra].node.flags.incl nfIsRef
    else:
      stackTrace(c, tos, pc, "node is not a symbol")

proc newIntLitNode*(i: BiggestInt): NimNode =
  ## Creates an int literal node from `i`.
  result = newNimNode(nnkIntLit)
  result.intVal = i

proc newFloatLitNode*(f: BiggestFloat): NimNode =
  ## Creates a float literal node from `f`.
  result = newNimNode(nnkFloatLit)
  result.floatVal = f

proc add*(father, son: NimNode) =
  assert son != nil
  father.sons.add(son)

proc add*(father: NimNode, children: varargs[NimNode]): NimNode =
  father.sons.add(children)


proc quote*(bl: typed, op = "``"): NimNode {.magic: "QuoteAst", noSideEffect.} =
  ## Quasi-quoting operator.
  ## Accepts an expression or a block and returns the AST that represents it.
  ## Within the quoted AST, you are able to interpolate NimNode expressions
  ## from the surrounding scope. If no operator is given, quoting is done using
  ## backticks. Otherwise, the given operator must be used as a prefix operator
  ## for any interpolated expression. The original meaning of the interpolation
  ## operator may be obtained by escaping it (by prefixing it with itself) when used
  ## as a unary operator:
  ## e.g. `@` is escaped as `@@`, `&%` is escaped as `&%&%` and so on; see examples.
  ##
  ## A custom operator interpolation needs accent quoted (``) whenever it resolves
  ## to a symbol.
  ##
  ## See also `genasts <genasts.html>`_ which avoids some issues with `quote`.
  runnableExamples:
    macro check(ex: untyped) =
      # this is a simplified version of the check macro from the
      # unittest module.

      # If there is a failed check, we want to make it easy for
      # the user to jump to the faulty line in the code, so we
      # get the line info here:
      var info = ex.lineinfo

      # We will also display the code string of the failed check:
      var expString = ex.toStrLit

      # Finally we compose the code to implement the check:
      result = quote do:
        if not `ex`:
          echo `info` & ": Check failed: " & `expString`
    check 1 + 1 == 2

  runnableExamples:
    # example showing how to define a symbol that requires backtick without
    # quoting it.
    var destroyCalled = false
    macro bar() =
      let s = newTree(nnkAccQuoted, ident"=destroy")
      # let s = ident"`=destroy`" # this would not work
      result = quote do:
        type Foo = object
        # proc `=destroy`(a: var Foo) = destroyCalled = true # this would not work
        proc `s`(a: var Foo) = destroyCalled = true
        block:
          let a = Foo()
    bar()
    doAssert destroyCalled

  runnableExamples:
    # custom `op`
    var destroyCalled = false
    macro bar(ident) =
      var x = 1.5
      result = quote("@") do:
        type Foo = object
        let `@ident` = 0 # custom op interpolated symbols need quoted (``)
        proc `=destroy`(a: var Foo) =
          doAssert @x == 1.5
          doAssert compiles(@x == 1.5)
          let b1 = @[1,2]
          let b2 = @@[1,2]
          doAssert $b1 == "[1, 2]"
          doAssert $b2 == "@[1, 2]"
          destroyCalled = true
        block:
          let a = Foo()
    bar(someident)
    doAssert destroyCalled

    proc `&%`(x: int): int = 1
    proc `&%`(x, y: int): int = 2

    macro bar2() =
      var x = 3
      result = quote("&%") do:
        var y = &%x # quoting operator
        doAssert &%&%y == 1 # unary operator => need to escape
        doAssert y &% y == 2 # binary operator => no need to escape
        doAssert y == 3
    bar2()

proc expectKind*(n: NimNode, k: NimNodeKind) =
  ## Checks that `n` is of kind `k`. If this is not the case,
  ## compilation aborts with an error message. This is useful for writing
  ## macros that check the AST that is passed to them.
  if n.kind != k: error("Expected a node of kind " & $k & ", got " & $n.kind, n)

proc expectMinLen*(n: NimNode, min: int) =
  ## Checks that `n` has at least `min` children. If this is not the case,
  ## compilation aborts with an error message. This is useful for writing
  ## macros that check its number of arguments.
  if n.len < min: error("Expected a node with at least " & $min & " children, got " & $n.len, n)

proc expectLen*(n: NimNode, len: int) =
  ## Checks that `n` has exactly `len` children. If this is not the case,
  ## compilation aborts with an error message. This is useful for writing
  ## macros that check its number of arguments.
  if n.len != len: error("Expected a node with " & $len & " children, got " & $n.len, n)

proc expectLen*(n: NimNode, min, max: int) =
  ## Checks that `n` has a number of children in the range `min..max`.
  ## If this is not the case, compilation aborts with an error message.
  ## This is useful for writing macros that check its number of arguments.
  if n.len < min or n.len > max:
    error("Expected a node with " & $min & ".." & $max & " children, got " & $n.len, n)

proc newTree*(kind: NimNodeKind,
              children: varargs[NimNode]): NimNode =
  ## Produces a new node with children.
  result = newNimNode(kind)
  result.add(children)

proc newCall*(theProc: NimNode, args: varargs[NimNode]): NimNode =
  ## Produces a new call node. `theProc` is the proc that is called with
  ## the arguments `args[0..]`.
  result = newNimNode(nnkCall)
  result.add(theProc)
  result.add(args)

{.push warnings: off.}

proc newCall*(theProc: NimIdent, args: varargs[NimNode]): NimNode {.deprecated:
  "Deprecated since v0.18.1; use 'newCall(string, ...)' or 'newCall(NimNode, ...)' instead".} =
  ## Produces a new call node. `theProc` is the proc that is called with
  ## the arguments `args[0..]`.
  result = newNimNode(nnkCall)
  result.add(newIdentNode(theProc))
  result.add(args)

{.pop.}

proc newCall*(theProc: string,
              args: varargs[NimNode]): NimNode =
  ## Produces a new call node. `theProc` is the proc that is called with
  ## the arguments `args[0..]`.
  result = newNimNode(nnkCall)
  result.add(newIdentNode(theProc))
  result.add(args)

proc newLit*(c: char): NimNode =
  ## Produces a new character literal node.
  result = newNimNode(nnkCharLit)
  result.intVal = ord(c)

proc newLit*(i: int): NimNode =
  ## Produces a new integer literal node.
  result = newNimNode(nnkIntLit)
  result.intVal = i

proc newLit*(i: int8): NimNode =
  ## Produces a new integer literal node.
  result = newNimNode(nnkInt8Lit)
  result.intVal = i

proc newLit*(i: int16): NimNode =
  ## Produces a new integer literal node.
  result = newNimNode(nnkInt16Lit)
  result.intVal = i

proc newLit*(i: int32): NimNode =
  ## Produces a new integer literal node.
  result = newNimNode(nnkInt32Lit)
  result.intVal = i

proc newLit*(i: int64): NimNode =
  ## Produces a new integer literal node.
  result = newNimNode(nnkInt64Lit)
  result.intVal = i

proc newLit*(i: uint): NimNode =
  ## Produces a new unsigned integer literal node.
  result = newNimNode(nnkUIntLit)
  result.intVal = BiggestInt(i)

proc newLit*(i: uint8): NimNode =
  ## Produces a new unsigned integer literal node.
  result = newNimNode(nnkUInt8Lit)
  result.intVal = BiggestInt(i)

proc newLit*(i: uint16): NimNode =
  ## Produces a new unsigned integer literal node.
  result = newNimNode(nnkUInt16Lit)
  result.intVal = BiggestInt(i)

proc newLit*(i: uint32): NimNode =
  ## Produces a new unsigned integer literal node.
  result = newNimNode(nnkUInt32Lit)
  result.intVal = BiggestInt(i)

proc newLit*(i: uint64): NimNode =
  ## Produces a new unsigned integer literal node.
  result = newNimNode(nnkUInt64Lit)
  result.intVal = BiggestInt(i)

proc newLit*(b: bool): NimNode =
  ## Produces a new boolean literal node.
  result = if b: bindSym"true" else: bindSym"false"

proc newLit*(s: string): NimNode =
  ## Produces a new string literal node.
  result = newNimNode(nnkStrLit)
  result.strVal = s

when false:
  # the float type is not really a distinct type as described in https://github.com/nim-lang/Nim/issues/5875
  proc newLit*(f: float): NimNode =
    ## Produces a new float literal node.
    result = newNimNode(nnkFloatLit)
    result.floatVal = f

proc newLit*(f: float32): NimNode =
  ## Produces a new float literal node.
  result = newNimNode(nnkFloat32Lit)
  result.floatVal = f

proc newLit*(f: float64): NimNode =
  ## Produces a new float literal node.
  result = newNimNode(nnkFloat64Lit)
  result.floatVal = f

when declared(float128):
  proc newLit*(f: float128): NimNode =
    ## Produces a new float literal node.
    result = newNimNode(nnkFloat128Lit)
    result.floatVal = f

proc newLit*(arg: enum): NimNode =
  result = newCall(
    arg.typeof.getTypeInst[1],
    newLit(int(arg))
  )

proc newLit*[N,T](arg: array[N,T]): NimNode
proc newLit*[T](arg: seq[T]): NimNode
proc newLit*[T](s: set[T]): NimNode
proc newLit*[T: tuple](arg: T): NimNode

proc newLit*(arg: object): NimNode =
  result = nnkObjConstr.newTree(arg.typeof.getTypeInst[1])
  for a, b in arg.fieldPairs:
    result.add nnkExprColonExpr.newTree( newIdentNode(a), newLit(b) )

proc newLit*(arg: ref object): NimNode =
  ## produces a new ref type literal node.
  result = nnkObjConstr.newTree(arg.typeof.getTypeInst[1])
  for a, b in fieldPairs(arg[]):
    result.add nnkExprColonExpr.newTree(newIdentNode(a), newLit(b))

proc newLit*[N,T](arg: array[N,T]): NimNode =
  result = nnkBracket.newTree
  for x in arg:
    result.add newLit(x)

proc newLit*[T](arg: seq[T]): NimNode =
  let bracket = nnkBracket.newTree
  for x in arg:
    bracket.add newLit(x)
  result = nnkPrefix.newTree(
    bindSym"@",
    bracket
  )
  if arg.len == 0:
    # add type cast for empty seq
    var typ = getTypeInst(typeof(arg))[1]
    result = newCall(typ,result)

proc newLit*[T](s: set[T]): NimNode =
  result = nnkCurly.newTree
  for x in s:
    result.add newLit(x)
  if result.len == 0:
    # add type cast for empty set
    var typ = getTypeInst(typeof(s))[1]
    result = newCall(typ,result)

proc isNamedTuple(T: typedesc): bool {.magic: "TypeTrait".}
  ## See `typetraits.isNamedTuple`

proc newLit*[T: tuple](arg: T): NimNode =
  ## use -d:nimHasWorkaround14720 to restore behavior prior to PR, forcing
  ## a named tuple even when `arg` is unnamed.
  result = nnkTupleConstr.newTree
  when defined(nimHasWorkaround14720) or isNamedTuple(T):
    for a, b in arg.fieldPairs:
      result.add nnkExprColonExpr.newTree(newIdentNode(a), newLit(b))
  else:
    for b in arg.fields:
      result.add newLit(b)

proc nestList*(op: NimNode; pack: NimNode): NimNode =
  ## Nests the list `pack` into a tree of call expressions:
  ## `[a, b, c]` is transformed into `op(a, op(c, d))`.
  ## This is also known as fold expression.
  if pack.len < 1:
    error("`nestList` expects a node with at least 1 child")
  result = pack[^1]
  for i in countdown(pack.len - 2, 0):
    result = newCall(op, pack[i], result)

proc nestList*(op: NimNode; pack: NimNode; init: NimNode): NimNode =
  ## Nests the list `pack` into a tree of call expressions:
  ## `[a, b, c]` is transformed into `op(a, op(c, d))`.
  ## This is also known as fold expression.
  result = init
  for i in countdown(pack.len - 1, 0):
    result = newCall(op, pack[i], result)

proc eqIdent*(a: string; b: string): bool {.magic: "EqIdent", noSideEffect.}
  ## Style insensitive comparison.

proc eqIdent*(a: NimNode; b: string): bool {.magic: "EqIdent", noSideEffect.}
  ## Style insensitive comparison.  `a` can be an identifier or a
  ## symbol. `a` may be wrapped in an export marker
  ## (`nnkPostfix`) or quoted with backticks (`nnkAccQuoted`),
  ## these nodes will be unwrapped.

proc eqIdent*(a: string; b: NimNode): bool {.magic: "EqIdent", noSideEffect.}
  ## Style insensitive comparison.  `b` can be an identifier or a
  ## symbol. `b` may be wrapped in an export marker
  ## (`nnkPostfix`) or quoted with backticks (`nnkAccQuoted`),
  ## these nodes will be unwrapped.

proc eqIdent*(a: NimNode; b: NimNode): bool {.magic: "EqIdent", noSideEffect.}
  ## Style insensitive comparison.  `a` and `b` can be an
  ## identifier or a symbol. Both may be wrapped in an export marker
  ## (`nnkPostfix`) or quoted with backticks (`nnkAccQuoted`),
  ## these nodes will be unwrapped.

const collapseSymChoice = not defined(nimLegacyMacrosCollapseSymChoice)

proc treeTraverse(n: NimNode; res: var string; level = 0; isLisp = false, indented = false) {.benign.} =
  if level > 0:
    if indented:
      res.add("\n")
      for i in 0 .. level-1:
        if isLisp:
          res.add(" ")          # dumpLisp indentation
        else:
          res.add("  ")         # dumpTree indentation
    else:
      res.add(" ")

  if isLisp:
    res.add("(")
  res.add(($n.kind).substr(3))

  case n.kind
  of nnkEmpty, nnkNilLit:
    discard # same as nil node in this representation
  of nnkCharLit .. nnkInt64Lit:
    res.add(" " & $n.intVal)
  of nnkFloatLit .. nnkFloat64Lit:
    res.add(" " & $n.floatVal)
  of nnkStrLit .. nnkTripleStrLit, nnkCommentStmt, nnkIdent, nnkSym:
    res.add(" " & $n.strVal.newLit.repr)
  of nnkNone:
    assert false
  elif n.kind in {nnkOpenSymChoice, nnkClosedSymChoice} and collapseSymChoice:
    res.add(" " & $n.len)
    if n.len > 0:
      var allSameSymName = true
      for i in 0..<n.len:
        if n[i].kind != nnkSym or not eqIdent(n[i], n[0]):
          allSameSymName = false
          break
      if allSameSymName:
        res.add(" " & $n[0].strVal.newLit.repr)
      else:
        for j in 0 ..< n.len:
          n[j].treeTraverse(res, level+1, isLisp, indented)
  else:
    for j in 0 ..< n.len:
      n[j].treeTraverse(res, level+1, isLisp, indented)

  if isLisp:
    res.add(")")

proc treeRepr*(n: NimNode): string {.benign.} =
  ## Convert the AST `n` to a human-readable tree-like string.
  ##
  ## See also `repr`, `lispRepr`, and `astGenRepr`.
  result = ""
  n.treeTraverse(result, isLisp = false, indented = true)

proc lispRepr*(n: NimNode; indented = false): string {.benign.} =
  ## Convert the AST `n` to a human-readable lisp-like string.
  ##
  ## See also `repr`, `treeRepr`, and `astGenRepr`.
  result = ""
  n.treeTraverse(result, isLisp = true, indented = indented)

proc astGenRepr*(n: NimNode): string {.benign.} =
  ## Convert the AST `n` to the code required to generate that AST.
  ##
  ## See also `repr`, `treeRepr`, and `lispRepr`.

  const
    NodeKinds = {nnkEmpty, nnkIdent, nnkSym, nnkNone, nnkCommentStmt}
    LitKinds = {nnkCharLit..nnkInt64Lit, nnkFloatLit..nnkFloat64Lit, nnkStrLit..nnkTripleStrLit}

  proc traverse(res: var string, level: int, n: NimNode) {.benign.} =
    for i in 0..level-1: res.add "  "
    if n.kind in NodeKinds:
      res.add("new" & ($n.kind).substr(3) & "Node(")
    elif n.kind in LitKinds:
      res.add("newLit(")
    elif n.kind == nnkNilLit:
      res.add("newNilLit()")
    else:
      res.add($n.kind)

    case n.kind
    of nnkEmpty, nnkNilLit: discard
    of nnkCharLit: res.add("'" & $chr(n.intVal) & "'")
    of nnkIntLit..nnkInt64Lit: res.add($n.intVal)
    of nnkFloatLit..nnkFloat64Lit: res.add($n.floatVal)
    of nnkStrLit..nnkTripleStrLit, nnkCommentStmt, nnkIdent, nnkSym:
      res.add(n.strVal.newLit.repr)
    of nnkNone: assert false
    elif n.kind in {nnkOpenSymChoice, nnkClosedSymChoice} and collapseSymChoice:
      res.add(", # unrepresentable symbols: " & $n.len)
      if n.len > 0:
        res.add(" " & n[0].strVal.newLit.repr)
    else:
      res.add(".newTree(")
      for j in 0..<n.len:
        res.add "\n"
        traverse(res, level + 1, n[j])
        if j != n.len-1:
          res.add(",")

      res.add("\n")
      for i in 0..level-1: res.add "  "
      res.add(")")

    if n.kind in NodeKinds+LitKinds:
      res.add(")")

  result = ""
  traverse(result, 0, n)
