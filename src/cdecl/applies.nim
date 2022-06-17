import macros, macroutils, tables

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
  Attribute* = object
    name*: string
    code*: NimNode

import strformat

macro unpackLabelsAsArgs*(
    callee: typed;
    body: varargs[untyped]
): untyped =
  ## 
  echo "unpackLabelsAsArgs: ", body.treeRepr
  echo "callee: ", callee.getType().repr
  body.expectKind nnkArgList
  let fnx = getImpl(callee)
  echo "fnx: ", fnx.treeRepr()


