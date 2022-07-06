
import system except NimNode
import compiler/[ast, lineinfos, idents]
import compiler/[options, modulegraphs, condsyms]
import compiler/[passes, passaux]
import compiler/[
  astalgo, modules, passes, condsyms,
  options, llstream, lineinfos, vm,
  modulegraphs, idents, 
  passaux, scriptconfig,
  parser, renderer
]
import utils
import sems

type
  NimNode* = PNode

forwardEnums("NimNodeKind", "n", TNodeKind)
forwardEnums("NimTypeKind", "n", TTypeKind)
forwardEnums("NimSymKind", "n", TSymKind)

template `ident=`*[T](nn: var NimNode, i: T) =
  discard

var conf = newConfigRef()
var cache = newIdentCache()
var graph = newModuleGraph(cache, conf)
var module = graph.makeStdinModule()
var idgen = idGeneratorFromModule(module)
var context: PContext = newContext(graph, module)
# var ctx: PCtx = newCtx(module, cache, graph, idgen)

template benign*(p: untyped) = p

proc newNimNode*(kind: NimNodeKind): NimNode =
  result = newNode(TNodeKind(kind.ord()))
  result.kind = kind

proc newTree*(kind: NimNodeKind; children: varargs[NimNode]): NimNode =
  result = ast.newTree(TNodeKind(kind.ord()), children)

proc ident*(name: string): NimNode =
  result = newIdentNode(cache.getIdent(name), unknownLineInfo)

proc newIdentNode*(name: string): NimNode =
  result = newIdentNode(cache.getIdent(name), unknownLineInfo)

proc newIntLitNode*(i: BiggestInt): NimNode =
  ## Creates an int literal node from `i`.
  result = newNimNode(nnkIntLit)
  result.intVal = i

proc newFloatLitNode*(f: BiggestFloat): NimNode =
  ## Creates a float literal node from `f`.
  result = newNimNode(nnkFloatLit)
  result.floatVal = f

proc add*(father, son: NimNode): NimNode {.discardable.} =
  assert son != nil
  father.sons.add(son)
  result = father

proc add*(father: NimNode, children: varargs[NimNode]): NimNode {.discardable.} =
  father.sons.add(children)
  result = father

proc error*(msg: string) = 
  echo "Warning: ", msg
  quit(1)

proc error*(msg: string, n: NimNode) = 
  error(msg)

proc bindSym(id: string): NimNode = 
  let n = ident(id)
  result = semBindSym(context, n)

proc parseStmt*(s: string): NimNode =
  ## Compiles the passed string to its AST representation.
  ## Expects one or more statements. Raises `ValueError` for parsing errors.
  result = parseString(s, cache, conf)

proc strVals*(n: NimNode): string =
  case n.kind
  of nkStrLit..nkTripleStrLit:
    result = n.strVal
  of nkCommentStmt:
    result = n.comment
  of nkIdent:
    result = n.ident.s
  of nkSym:
    result = n.sym.name.s
  else:
    raise newException(Exception, "strVal wrong kind")

proc repr*(n: PNode): string =
  renderTree(n, {renderNoComments, renderDocComments})

## ~~~~~~~~~~~~~~~~~~~~
## Copy and pasted code 
## ~~~~~~~~~~~~~~~~~~~~

proc len*(n: NimNode): int {.inline.} =
  result = n.sons.len

proc safeLen*(n: NimNode): int {.inline.} =
  ## works even for leaves.
  if n.kind in {nkNone..nkNilLit}: result = 0
  else: result = n.len

proc safeArrLen*(n: NimNode): int {.inline.} =
  ## works for array-like objects (strings passed as openArray in VM).
  if n.kind in {nkStrLit..nkTripleStrLit}: result = n.strVal.len
  elif n.kind in {nkNone..nkFloat128Lit}: result = 0
  else: result = n.len

proc addAllowNil*(father, son: NimNode) {.inline.} =
  father.sons.add(son)

template `[]`*(n: NimNode, i: int): NimNode = n.sons[i]
template `[]=`*(n: NimNode, i: int; x: NimNode) = n.sons[i] = x

template `[]`*(n: NimNode, i: BackwardsIndex): NimNode = n[n.len - i.int]
template `[]=`*(n: NimNode, i: BackwardsIndex; x: NimNode) = n[n.len - i.int] = x

# proc `==`*(a, b: NimNode): bool {.magic: "EqNimrodNode", noSideEffect.}
#   ## Compare two Nim nodes. Return true if nodes are structurally
#   ## equivalent. This means two independently created nodes can be equal.

# proc sameType*(a, b: NimNode): bool {.magic: "SameNodeType", noSideEffect.} =
#   ## Compares two Nim nodes' types. Return true if the types are the same,
#   ## e.g. true when comparing alias with original type.
#   discard


template `^^`(n: NimNode, i: untyped): untyped =
  (when i is BackwardsIndex: n.len - int(i) else: int(i))

proc `[]`*[T, U: Ordinal](n: NimNode, x: HSlice[T, U]): seq[NimNode] =
  ## Slice operation for NimNode.
  ## Returns a seq of child of `n` who inclusive range [n[x.a], n[x.b]].
  let xa = n ^^ x.a
  let L = (n ^^ x.b) - xa + 1
  result = newSeq[NimNode](L)
  for i in 0..<L:
    result[i] = n[i + xa]

proc `[]=`*(n: NimNode, i: BackwardsIndex, child: NimNode) =
  ## Set `n`'s `i`'th child to `child`.
  n[n.len - i.int] = child

template `or`*(x, y: NimNode): NimNode =
  ## Evaluate `x` and when it is not an empty node, return
  ## it. Otherwise evaluate to `y`. Can be used to chain several
  ## expressions to get the first expression that is not empty.
  ##
  ## .. code-block:: nim
  ##
  ##   let node = mightBeEmpty() or mightAlsoBeEmpty() or fallbackNode

  let arg = x
  if arg != nil and arg.kind != nnkEmpty:
    arg
  else:
    y

# proc quote*(bl: typed, op = "``"): NimNode =
#   ## Quasi-quoting operator.
#   ## Accepts an expression or a block and returns the AST that represents it.
#   ## Within the quoted AST, you are able to interpolate NimNode expressions
#   ## from the surrounding scope. If no operator is given, quoting is done using
#   ## backticks. Otherwise, the given operator must be used as a prefix operator
#   ## for any interpolated expression. The original meaning of the interpolation
#   ## operator may be obtained by escaping it (by prefixing it with itself) when used
#   ## as a unary operator:
#   ## e.g. `@` is escaped as `@@`, `&%` is escaped as `&%&%` and so on; see examples.
#   ##
#   ## A custom operator interpolation needs accent quoted (``) whenever it resolves
#   ## to a symbol.
#   ##
#   ## See also `genasts <genasts.html>`_ which avoids some issues with `quote`.
#   runnableExamples:
#     macro check(ex: untyped) =
#       # this is a simplified version of the check macro from the
#       # unittest module.

#       # If there is a failed check, we want to make it easy for
#       # the user to jump to the faulty line in the code, so we
#       # get the line info here:
#       var info = ex.lineinfo

#       # We will also display the code string of the failed check:
#       var expString = ex.toStrLit

#       # Finally we compose the code to implement the check:
#       result = quote do:
#         if not `ex`:
#           echo `info` & ": Check failed: " & `expString`
#     check 1 + 1 == 2

#   runnableExamples:
#     # example showing how to define a symbol that requires backtick without
#     # quoting it.
#     var destroyCalled = false
#     macro bar() =
#       let s = newTree(nnkAccQuoted, ident"=destroy")
#       # let s = ident"`=destroy`" # this would not work
#       result = quote do:
#         type Foo = object
#         # proc `=destroy`(a: var Foo) = destroyCalled = true # this would not work
#         proc `s`(a: var Foo) = destroyCalled = true
#         block:
#           let a = Foo()
#     bar()
#     doAssert destroyCalled

#   runnableExamples:
#     # custom `op`
#     var destroyCalled = false
#     macro bar(ident) =
#       var x = 1.5
#       result = quote("@") do:
#         type Foo = object
#         let `@ident` = 0 # custom op interpolated symbols need quoted (``)
#         proc `=destroy`(a: var Foo) =
#           doAssert @x == 1.5
#           doAssert compiles(@x == 1.5)
#           let b1 = @[1,2]
#           let b2 = @@[1,2]
#           doAssert $b1 == "[1, 2]"
#           doAssert $b2 == "@[1, 2]"
#           destroyCalled = true
#         block:
#           let a = Foo()
#     bar(someident)
#     doAssert destroyCalled

#     proc `&%`(x: int): int = 1
#     proc `&%`(x, y: int): int = 2

#     macro bar2() =
#       var x = 3
#       result = quote("&%") do:
#         var y = &%x # quoting operator
#         doAssert &%&%y == 1 # unary operator => need to escape
#         doAssert y &% y == 2 # binary operator => no need to escape
#         doAssert y == 3
#     bar2()

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


proc newCall*(theProc: NimNode, args: varargs[NimNode]): NimNode =
  ## Produces a new call node. `theProc` is the proc that is called with
  ## the arguments `args[0..]`.
  result = newNimNode(nnkCall)
  result.add(theProc)
  result.add(args)

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

proc newLit*[T](s: set[T]): NimNode =
  result = nnkCurly.newTree
  for x in s:
    result.add newLit(x)


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

proc eqIdent*(lhs, rhs: NimNode): bool =
  # decodeBC(rkInt)
  # aliases for shorter and easier to understand code below
  var aNode = lhs
  var bNode = rhs
  # Skipping both, `nkPostfix` and `nkAccQuoted` for both
  # arguments.  `nkPostfix` exists only to tag exported symbols
  # and therefor it can be safely skipped. Nim has no postfix
  # operator. `nkAccQuoted` is used to quote an identifier that
  # wouldn't be allowed to use in an unquoted context.
  if aNode.kind == nkPostfix:
    aNode = aNode[1]
  if aNode.kind == nkAccQuoted:
    aNode = aNode[0]
  if bNode.kind == nkPostfix:
    bNode = bNode[1]
  if bNode.kind == nkAccQuoted:
    bNode = bNode[0]
  # These vars are of type `cstring` to prevent unnecessary string copy.
  var aStrVal: cstring = nil
  var bStrVal: cstring = nil
  # extract strVal from argument ``a``
  case aNode.kind
  of nkStrLit..nkTripleStrLit:
    aStrVal = aNode.strVal.cstring
  of nkIdent:
    aStrVal = aNode.ident.s.cstring
  of nkSym:
    aStrVal = aNode.sym.name.s.cstring
  of nkOpenSymChoice, nkClosedSymChoice:
    aStrVal = aNode[0].sym.name.s.cstring
  else:
    discard
  # extract strVal from argument ``b``
  case bNode.kind
  of nkStrLit..nkTripleStrLit:
    bStrVal = bNode.strVal.cstring
  of nkIdent:
    bStrVal = bNode.ident.s.cstring
  of nkSym:
    bStrVal = bNode.sym.name.s.cstring
  of nkOpenSymChoice, nkClosedSymChoice:
    bStrVal = bNode[0].sym.name.s.cstring
  else:
    discard

  result =
    if aStrVal != nil and bStrVal != nil:
      idents.cmpIgnoreStyle(aStrVal, bStrVal, high(int)) == 0
    else:
      false

proc eqIdent*(lhs: NimNode, rhs: string): bool =
  eqIdent(lhs, ident rhs)
proc eqIdent*(lhs: string, rhs: NimNode): bool =
  eqIdent(ident lhs, rhs)
proc eqIdent*(lhs: string, rhs: string): bool =
  eqIdent(ident lhs, ident rhs)

# proc eqIdent*(a: string; b: string): bool {.magic: "EqIdent", noSideEffect.}
#   ## Style insensitive comparison.

# proc eqIdent*(a: NimNode; b: string): bool {.magic: "EqIdent", noSideEffect.}
#   ## Style insensitive comparison.  `a` can be an identifier or a
#   ## symbol. `a` may be wrapped in an export marker
#   ## (`nnkPostfix`) or quoted with backticks (`nnkAccQuoted`),
#   ## these nodes will be unwrapped.

# proc eqIdent*(a: string; b: NimNode): bool {.magic: "EqIdent", noSideEffect.}
#   ## Style insensitive comparison.  `b` can be an identifier or a
#   ## symbol. `b` may be wrapped in an export marker
#   ## (`nnkPostfix`) or quoted with backticks (`nnkAccQuoted`),
#   ## these nodes will be unwrapped.

# proc eqIdent*(a: NimNode; b: NimNode): bool {.magic: "EqIdent", noSideEffect.}
#   ## Style insensitive comparison.  `a` and `b` can be an
#   ## identifier or a symbol. Both may be wrapped in an export marker
#   ## (`nnkPostfix`) or quoted with backticks (`nnkAccQuoted`),
#   ## these nodes will be unwrapped.

const collapseSymChoice = not defined(nimLegacyMacrosCollapseSymChoice)

proc treeTraverse(n: NimNode; res: var string; level = 0; isLisp = false, indented = false) =
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
  of nkCharLit .. nkInt64Lit:
    res.add(" " & $n.intVal)
  of nkFloatLit .. nkFloat64Lit:
    res.add(" " & $n.floatVal)
  of nkStrLit .. nkTripleStrLit, nnkCommentStmt, nnkIdent, nnkSym:
    res.add(" " & $n.strVals()) #.newLit.repr)
  of nkNone:
    assert false
  elif n.kind in {nkOpenSymChoice, nkClosedSymChoice} and collapseSymChoice:
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


proc newEmptyNode*(): NimNode {.noSideEffect.} =
  ## Create a new empty node.
  result = newNimNode(nnkEmpty)

proc newStmtList*(stmts: varargs[NimNode]): NimNode =
  ## Create a new statement list.
  result = newNimNode(nnkStmtList).add(stmts)

proc newPar*(exprs: varargs[NimNode]): NimNode =
  ## Create a new parentheses-enclosed expression.
  newNimNode(nnkPar).add(exprs)

proc newBlockStmt*(label, body: NimNode): NimNode =
  ## Create a new block statement with label.
  return newNimNode(nnkBlockStmt).add(label, body)

proc newBlockStmt*(body: NimNode): NimNode =
  ## Create a new block: stmt.
  return newNimNode(nnkBlockStmt).add(newEmptyNode(), body)

proc newVarStmt*(name, value: NimNode): NimNode =
  ## Create a new var stmt.
  return newNimNode(nnkVarSection).add(
    newNimNode(nnkIdentDefs).add(name, newNimNode(nnkEmpty), value))

proc newLetStmt*(name, value: NimNode): NimNode =
  ## Create a new let stmt.
  return newNimNode(nnkLetSection).add(
    newNimNode(nnkIdentDefs).add(name, newNimNode(nnkEmpty), value))

proc newConstStmt*(name, value: NimNode): NimNode =
  ## Create a new const stmt.
  newNimNode(nnkConstSection).add(
    newNimNode(nnkConstDef).add(name, newNimNode(nnkEmpty), value))

proc newAssignment*(lhs, rhs: NimNode): NimNode =
  return newNimNode(nnkAsgn).add(lhs, rhs)

proc newDotExpr*(a, b: NimNode): NimNode =
  ## Create new dot expression.
  ## a.dot(b) -> `a.b`
  return newNimNode(nnkDotExpr).add(a, b)

proc newColonExpr*(a, b: NimNode): NimNode =
  ## Create new colon expression.
  ## newColonExpr(a, b) -> `a: b`
  newNimNode(nnkExprColonExpr).add(a, b)

proc newIdentDefs*(name, kind: NimNode;
                   default = newEmptyNode()): NimNode =
  ## Creates a new `nnkIdentDefs` node of a specific kind and value.
  ##
  ## `nnkIdentDefs` need to have at least three children, but they can have
  ## more: first comes a list of identifiers followed by a type and value
  ## nodes. This helper proc creates a three node subtree, the first subnode
  ## being a single identifier name. Both the `kind` node and `default`
  ## (value) nodes may be empty depending on where the `nnkIdentDefs`
  ## appears: tuple or object definitions will have an empty `default` node,
  ## `let` or `var` blocks may have an empty `kind` node if the
  ## identifier is being assigned a value. Example:
  ##
  ## .. code-block:: nim
  ##
  ##   var varSection = newNimNode(nnkVarSection).add(
  ##     newIdentDefs(ident("a"), ident("string")),
  ##     newIdentDefs(ident("b"), newEmptyNode(), newLit(3)))
  ##   # --> var
  ##   #       a: string
  ##   #       b = 3
  ##
  ## If you need to create multiple identifiers you need to use the lower level
  ## `newNimNode`:
  ##
  ## .. code-block:: nim
  ##
  ##   result = newNimNode(nnkIdentDefs).add(
  ##     ident("a"), ident("b"), ident("c"), ident("string"),
  ##       newStrLitNode("Hello"))
  newNimNode(nnkIdentDefs).add(name, kind, default)

proc newNilLit*(): NimNode =
  ## New nil literal shortcut.
  result = newNimNode(nnkNilLit)

proc last*(node: NimNode): NimNode = node[node.len-1]
  ## Return the last item in nodes children. Same as `node[^1]`.


const
  RoutineNodes* = {nnkProcDef, nnkFuncDef, nnkMethodDef, nnkDo, nnkLambda,
                   nnkIteratorDef, nnkTemplateDef, nnkConverterDef, nnkMacroDef}
  AtomicNodes* = {nnkNone..nnkNilLit}
  CallNodes* = {nnkCall, nnkInfix, nnkPrefix, nnkPostfix, nnkCommand,
    nnkCallStrLit, nnkHiddenCallConv}

proc expectKind*(n: NimNode; k: set[NimNodeKind]) =
  ## Checks that `n` is of kind `k`. If this is not the case,
  ## compilation aborts with an error message. This is useful for writing
  ## macros that check the AST that is passed to them.
  if n.kind notin k:
    error("Expected one of " & $k & ", got " & $n.kind, n)

proc newProc*(name = newEmptyNode();
              params: openArray[NimNode] = [newEmptyNode()];
              body: NimNode = newStmtList();
              procType = nnkProcDef;
              pragmas: NimNode = newEmptyNode()): NimNode =
  ## Shortcut for creating a new proc.
  ##
  ## The `params` array must start with the return type of the proc,
  ## followed by a list of IdentDefs which specify the params.
  if procType notin RoutineNodes:
    error("Expected one of " & $RoutineNodes & ", got " & $procType)
  pragmas.expectKind({nnkEmpty, nnkPragma})
  result = newNimNode(procType).add(
    name,
    newEmptyNode(),
    newEmptyNode(),
    newNimNode(nnkFormalParams).add(params),
    pragmas,
    newEmptyNode(),
    body)

proc newIfStmt*(branches: varargs[tuple[cond, body: NimNode]]): NimNode =
  ## Constructor for `if` statements.
  ##
  ## .. code-block:: nim
  ##
  ##    newIfStmt(
  ##      (Ident, StmtList),
  ##      ...
  ##    )
  ##
  result = newNimNode(nnkIfStmt)
  if len(branches) < 1:
    error("If statement must have at least one branch")
  for i in branches:
    result.add(newTree(nnkElifBranch, i.cond, i.body))

proc newEnum*(name: NimNode, fields: openArray[NimNode],
              public, pure: bool): NimNode =
  ## Creates a new enum. `name` must be an ident. Fields are allowed to be
  ## either idents or EnumFieldDef
  ##
  ## .. code-block:: nim
  ##
  ##    newEnum(
  ##      name    = ident("Colors"),
  ##      fields  = [ident("Blue"), ident("Red")],
  ##      public  = true, pure = false)
  ##
  ##    # type Colors* = Blue Red
  ##
  expectKind name, nnkIdent
  if len(fields) < 1:
    raise newException(Exception, "Enum must contain at least one field")
  for field in fields:
    expectKind field, {nnkIdent, nnkEnumFieldDef}

  let enumBody = newNimNode(nnkEnumTy).add(newEmptyNode()).add(fields)
  var typeDefArgs = [name, newEmptyNode(), enumBody]

  if public:
    let postNode = newNimNode(nnkPostfix).add(
      newIdentNode("*"), typeDefArgs[0])

    typeDefArgs[0] = postNode

  if pure:
    let pragmaNode = newNimNode(nnkPragmaExpr).add(
      typeDefArgs[0],
      add(newNimNode(nnkPragma), newIdentNode("pure")))

    typeDefArgs[0] = pragmaNode

  let
    typeDef   = add(newNimNode(nnkTypeDef), typeDefArgs)
    typeSect  = add(newNimNode(nnkTypeSection), typeDef)

  return typeSect

# proc copyChildrenTo*(src, dest: NimNode) =
#   ## Copy all children from `src` to `dest`.
#   for i in 0 ..< src.len:
#     dest.add src[i].copyNimTree

template expectRoutine(node: NimNode) =
  expectKind(node, RoutineNodes)

proc name*(someProc: NimNode): NimNode =
  someProc.expectRoutine
  result = someProc[0]
  if result.kind == nnkPostfix:
    if result[1].kind == nnkAccQuoted:
      result = result[1][0]
    else:
      result = result[1]
  elif result.kind == nnkAccQuoted:
    result = result[0]

proc `name=`*(someProc: NimNode; val: NimNode) =
  someProc.expectRoutine
  if someProc[0].kind == nnkPostfix:
    someProc[0][1] = val
  else: someProc[0] = val

proc params*(someProc: NimNode): NimNode =
  someProc.expectRoutine
  result = someProc[3]
proc `params=`* (someProc: NimNode; params: NimNode) =
  someProc.expectRoutine
  expectKind(params, nnkFormalParams)
  someProc[3] = params

proc pragma*(someProc: NimNode): NimNode =
  ## Get the pragma of a proc type.
  ## These will be expanded.
  if someProc.kind == nnkProcTy:
    result = someProc[1]
  else:
    someProc.expectRoutine
    result = someProc[4]
proc `pragma=`*(someProc: NimNode; val: NimNode) =
  ## Set the pragma of a proc type.
  expectKind(val, {nnkEmpty, nnkPragma})
  if someProc.kind == nnkProcTy:
    someProc[1] = val
  else:
    someProc.expectRoutine
    someProc[4] = val

proc addPragma*(someProc, pragma: NimNode) =
  ## Adds pragma to routine definition.
  someProc.expectKind(RoutineNodes + {nnkProcTy})
  var pragmaNode = someProc.pragma
  if pragmaNode.isNil or pragmaNode.kind == nnkEmpty:
    pragmaNode = newNimNode(nnkPragma)
    someProc.pragma = pragmaNode
  pragmaNode.add(pragma)

template badNodeKind(n, f) =
  error("Invalid node kind " & $n.kind & " for macros.`" & $f & "`", n)

proc body*(someProc: NimNode): NimNode =
  case someProc.kind:
  of RoutineNodes:
    return someProc[6]
  of nnkBlockStmt, nnkWhileStmt:
    return someProc[1]
  of nnkForStmt:
    return someProc.last
  else:
    badNodeKind someProc, "body"

proc `body=`*(someProc: NimNode, val: NimNode) =
  case someProc.kind
  of RoutineNodes:
    someProc[6] = val
  of nnkBlockStmt, nnkWhileStmt:
    someProc[1] = val
  of nnkForStmt:
    someProc[len(someProc)-1] = val
  else:
    badNodeKind someProc, "body="

proc basename*(a: NimNode): NimNode =
  ## Pull an identifier from prefix/postfix expressions.
  case a.kind
  of nnkIdent: result = a
  of nnkPostfix, nnkPrefix: result = a[1]
  of nnkPragmaExpr: result = basename(a[0])
  else:
    error("Do not know how to get basename of (" & treeRepr(a) & ")\n" &
      repr(a), a)

proc `$`*(node: NimNode): string =
  ## Get the string of an identifier node.
  case node.kind
  of nnkPostfix:
    result = node.basename.strVal & "*"
  of nnkStrLit..nnkTripleStrLit, nnkCommentStmt, nnkSym, nnkIdent:
    result = node.strVal
  of nnkOpenSymChoice, nnkClosedSymChoice:
    result = $node[0]
  of nnkAccQuoted:
    result = $node[0]
  else:
    badNodeKind node, "$"

iterator items*(n: NimNode): NimNode {.inline.} =
  ## Iterates over the children of the NimNode `n`.
  for i in 0 ..< n.len:
    yield n[i]

iterator pairs*(n: NimNode): (int, NimNode) {.inline.} =
  ## Iterates over the children of the NimNode `n` and its indices.
  for i in 0 ..< n.len:
    yield (i, n[i])

iterator children*(n: NimNode): NimNode {.inline.} =
  ## Iterates over the children of the NimNode `n`.
  for i in 0 ..< n.len:
    yield n[i]

template findChild*(n: NimNode; cond: untyped): NimNode {.dirty.} =
  ## Find the first child node matching condition (or nil).
  ##
  ## .. code-block:: nim
  ##   var res = findChild(n, it.kind == nnkPostfix and
  ##                          it.basename.ident == toNimIdent"foo")
  block:
    var res: NimNode
    for it in n.children:
      if cond:
        res = it
        break
    res

proc insert*(a: NimNode; pos: int; b: NimNode) =
  ## Insert node `b` into node `a` at `pos`.
  if len(a)-1 < pos:
    # add some empty nodes first
    for i in len(a)-1..pos-2:
      a.add newEmptyNode()
    a.add b
  else:
    # push the last item onto the list again
    # and shift each item down to pos up one
    a.add(a[a.len-1])
    for i in countdown(len(a) - 3, pos):
      a[i + 1] = a[i]
    a[pos] = b

proc `basename=`*(a: NimNode; val: string) =
  case a.kind
  of nnkIdent:
    a.strVal = val
  of nnkPostfix, nnkPrefix:
    a[1] = ident(val)
  of nnkPragmaExpr: `basename=`(a[0], val)
  else:
    error("Do not know how to get basename of (" & treeRepr(a) & ")\n" &
      repr(a), a)

proc postfix*(node: NimNode; op: string): NimNode =
  newNimNode(nnkPostfix).add(ident(op), node)

proc prefix*(node: NimNode; op: string): NimNode =
  newNimNode(nnkPrefix).add(ident(op), node)

proc infix*(a: NimNode; op: string;
            b: NimNode): NimNode =
  newNimNode(nnkInfix).add(ident(op), a, b)

proc unpackPostfix*(node: NimNode): tuple[node: NimNode; op: string] =
  node.expectKind nnkPostfix
  result = (node[1], $node[0])

proc unpackPrefix*(node: NimNode): tuple[node: NimNode; op: string] =
  node.expectKind nnkPrefix
  result = (node[1], $node[0])

proc unpackInfix*(node: NimNode): tuple[left: NimNode; op: string; right: NimNode] =
  expectKind(node, nnkInfix)
  result = (node[1], $node[0], node[2])

# proc copy*(node: NimNode): NimNode =
#   ## An alias for `copyNimTree<#copyNimTree,NimNode>`_.
#   return node.copyNimTree()

proc expectIdent*(n: NimNode, name: string) =
  ## Check that `eqIdent(n,name)` holds true. If this is not the
  ## case, compilation aborts with an error message. This is useful
  ## for writing macros that check the AST that is passed to them.
  if not eqIdent(n, name):
    error("Expected identifier to be `" & name & "` here", n)

proc hasArgOfName*(params: NimNode; name: string): bool =
  ## Search `nnkFormalParams` for an argument.
  expectKind(params, nnkFormalParams)
  for i in 1..<params.len:
    for j in 0..<params[i].len-2:
      if name.eqIdent($params[i][j]):
        return true

proc addIdentIfAbsent*(dest: NimNode, ident: string) =
  ## Add `ident` to `dest` if it is not present. This is intended for use
  ## with pragmas.
  for node in dest.children:
    case node.kind
    of nnkIdent:
      if ident.eqIdent($node): return
    of nnkExprColonExpr:
      if ident.eqIdent($node[0]): return
    else: discard
  dest.add(ident(ident))

proc boolVal*(n: NimNode): bool =
  if n.kind == nnkIntLit: n.intVal != 0
  else: n == bindSym"true" # hacky solution for now


proc isExported*(n: NimNode): bool {.noSideEffect.} =
  ## Returns whether the symbol is exported or not.

proc extractDocCommentsAndRunnables*(n: NimNode): NimNode =
  ## returns a `nnkStmtList` containing the top-level doc comments and
  ## runnableExamples in `a`, stopping at the first child that is neither.
  ## Example:
  ##
  ## .. code-block:: nim
  ##  import std/macros
  ##  macro transf(a): untyped =
  ##    result = quote do:
  ##      proc fun2*() = discard
  ##    let header = extractDocCommentsAndRunnables(a.body)
  ##    # correct usage: rest is appended
  ##    result.body = header
  ##    result.body.add quote do: discard # just an example
  ##    # incorrect usage: nesting inside a nnkStmtList:
  ##    # result.body = quote do: (`header`; discard)
  ##
  ##  proc fun*() {.transf.} =
  ##    ## first comment
  ##    runnableExamples: discard
  ##    runnableExamples: discard
  ##    ## last comment
  ##    discard # first statement after doc comments + runnableExamples
  ##    ## not docgen'd

  result = newStmtList()
  for ni in n:
    case ni.kind
    of nnkCommentStmt:
      result.add ni
    of nnkCall, nnkCommand:
      if ni[0].kind == nnkIdent and ni[0].eqIdent "runnableExamples":
        result.add ni
      else: break
    else: break