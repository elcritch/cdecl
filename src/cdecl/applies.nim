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
    name*: string
    typ*: NimNode
    default*: NimNode

import strformat

proc paramNames(node: NimNode): OrderedTable[string, Param] = 
  ## args
  echo "params"
  node.expectKind nnkFormalParams
  for paramNode in node[1..^1]:
    let
      nms = paramNode[0..<paramNode.len() - 2]
      tp = paramNode[^2]
      df = paramNode[^1]
    echo fmt"{nms.repr=}"
    echo fmt"{tp.repr=}"
    echo fmt"{df.repr=}"
    for nm in nms:
      let n = nm.strVal
      let pm = Param(name: n, typ: tp, default: df)
      result[n] = pm


macro unpackLabelsAsArgs*(
    callee: typed;
    body: varargs[untyped]
): untyped =
  ## 
  echo "unpackLabelsAsArgs: ", body.treeRepr
  echo "callee: ", callee.getType().repr
  body.expectKind nnkArgList
  let fnx = getImpl(callee)
  let fnxArgs = macros.params(fnx)
  echo "fnx: ", fnxArgs.treeRepr()
  let fnParams = fnxArgs.paramNames()
  echo "params: ", fnParams.keys().toSeq()


