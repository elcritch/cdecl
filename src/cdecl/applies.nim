import macros, macroutils, tables, sequtils

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


macro unpackLabelsAsArgs*(
    callee: typed;
    args: varargs[untyped]
): untyped =
  ## 
  echo "==============="
  echo "unpackLabelsAsArgs: ", args.treeRepr
  echo "callee: ", callee.getType().repr
  args.expectKind nnkArgList
  let fnImpl = getImpl(callee)
  let fnParams = macros.params(fnImpl).paramNames()
  echo "params: ", fnParams.keys().toSeq()

  ## parse out params in various formats
  var varList: OrderedTable[int, (string, NimNode)]
  var idx = 0
  for arg in args:
    if arg.kind == nnkStmtList:
      for labelArg in arg:
        labelArg.expectKind nnkCall
        let
          lname = labelArg[0].strVal
          lstmt = labelArg[1]
        echo fmt"labelArg: {labelArg.treeRepr=}"
        let param = fnParams[lname]
        echo fmt"{param.name=} {param.idx=}"
        varList[param.idx] = (param.name, lstmt)
        idx.inc
    elif arg.kind == nnkExprEqExpr:
      let
        lname = arg[0].strVal
        lstmt = arg[1]
      varList[idx] = (lname, lstmt)
      idx.inc
    else:
      varList[idx] = ("", arg)
      idx.inc
  
  echo " "
  varList.sort(system.cmp)

  for idx, (nm, vl) in varList.pairs():
    echo fmt"varList: {idx=} {vl.treeRepr()}"
  echo "result: ", result.treeRepr()
  echo "\n"


