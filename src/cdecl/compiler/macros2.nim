
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
