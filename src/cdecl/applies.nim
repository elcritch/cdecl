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
    body: varargs[untyped]
): untyped =
  ## 
  echo "unpackLabelsAsArgs: ", body.treeRepr
  echo "callee: ", callee.getType().repr
  body.expectKind nnkArgList
  let fnImpl = getImpl(callee)
  let fnParams = macros.params(fnImpl).paramNames()
  echo "params: ", fnParams.keys().toSeq()


