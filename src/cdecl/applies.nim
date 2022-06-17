import macros, tables, sequtils

macro unpackObjectArgs*(callee: untyped; arg: typed, extras: varargs[untyped]): untyped =
  ## Calls `callee` with fields form object `args` unpacked as individual arguments.
  ## 
  ## This is similar to `unpackVarargs` in `std/macros` but for call a function
  ## using the values from an object
  
  runnableExamples:
    proc add(a, b: int): int =
      result = a + b
    let args = AddObj(a: 1, b: 2)
    let res = unpackObjectArgs(add, args)
    check res == 3
  
  let paramNames = arg.getType()[2]
  result = newCall(callee)
  for nm in paramNames:
    result.add quote do:
      `arg`.`nm`
  for extra in extras:
    result.add extra

type
  Param* = object
    idx*: int
    name*: string
    typ*: NimNode
    default*: NimNode

import strformat

proc paramNames(node: NimNode): OrderedTable[string, Param] = 
  ## get all parameters from `FormalParams` in easy form
  node.expectKind nnkFormalParams
  var idx = 0
  for paramNode in node[1..^1]:
    let
      nms = paramNode[0..<paramNode.len() - 2]
      tp = paramNode[^2]
      df = paramNode[^1]
    for nm in nms:
      let n = nm.strVal
      result[n] = Param(idx: idx, name: n, typ: tp, default: df)
      idx.inc

var debugPrint* {.compileTime.} = false

proc processLabel(
    varList: var OrderedTable[int, (string, NimNode)],
    fnParams: OrderedTable[string, Param],
    labelArg: NimNode,
) =
  if debugPrint:
    echo fmt"{labelArg.treeRepr=}"
  labelArg.expectKind nnkCall
  let
    lname = labelArg[0].strVal
    lstmt = labelArg[1]
    fparam = fnParams[lname]
  

  if debugPrint:
    echo fmt"{fparam.name=} "
    echo fmt"{fparam.typ.treeRepr=}"
    echo fmt"{lstmt.treeRepr=}"
    echo fmt"{lstmt.kind == nnkDo =}"
  if lstmt.kind == nnkDo:
    let doFmlParam = params(lstmt)
    let doBody = body(lstmt)
    echo fmt"{doFmlParam.treeRepr()=}"
    let plet = quote do:
        let x = proc () = discard
    let plambda = plet[0][^1]
    echo fmt"plet: {plambda.treeRepr()=}"
    plambda.params= doFmlParam
    plambda.body= doBody
    echo fmt"{plambda.treeRepr()=}"
    let pstmt = quote do:
        let fn = `plambda`
        fn
    echo fmt"{pstmt.treeRepr=} "
    echo fmt"{pstmt.repr=} "
    varList[fparam.idx] = (fparam.name, pstmt)
  else:
    varList[fparam.idx] = (fparam.name, lstmt)

macro unpackLabelsAsArgs*(
    callee: typed;
    args: varargs[untyped]
): untyped =
  ## unpacks labels
  runnableExamples:
    proc foo(name: string = "buzz", a, b: int) =
      echo name, ":", " a: ", $a, " b: ", $b
    
    template myFoo(blk: varargs[untyped]) =
      unpackLabelsAsArgs(foo, blk)
    
    myFoo:
      name: "buzz"
      a: 11
      b: 22
  
  runnableExamples:
    proc fizz(name: proc (): string, a, b: int) =
      echo name, ":", " a: ", $a, " b: ", $b
    
    template Fizz(blk: varargs[untyped]) =
      unpackLabelsAsArgs(foo, blk)
    
    let fn = proc (): string = "fizzy"
    Fizz:
      name: fn
      a: 11
      b: 22
  
  if debugPrint:
    echo fmt"{args.treeRepr=}"
  args.expectKind nnkArgList
  let fnImpl = getImpl(callee)
  let fnParams = fnImpl.params().paramNames()

  ## parse out params in various formats
  var varList: OrderedTable[int, (string, NimNode)]
  var idx = 0
  for arg in args:
    if arg.kind == nnkStmtList:
      for labelArg in arg:
        # handle `label` or `property` arg
        idx = -1
        varList.processLabel(fnParams, labelArg)
    elif arg.kind == nnkExprEqExpr:
      # handle regular named parameters
      let
        lname = arg[0].strVal
      varList[idx] = (lname, arg[1])
      idx.inc
    else:
      # handle basic types like strlit or intlit
      varList[idx] = ("", arg)
      idx.inc
  
  # order arguments
  varList.sort(system.cmp)
  assert varList.hasKey(-1) == false ## not possible

  # generate actual function call
  result = newCall(callee)
  for idx, (nm, vl) in varList.pairs():
    if nm == "":
      result.add vl
    else:
      result.add nnkExprEqExpr.newTree(ident nm, vl)


