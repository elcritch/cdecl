import macros, typetraits, tables, strformat, strutils, sequtils

macro unpackObjectArgs*(callee: untyped; arg: typed, extras: varargs[untyped]): untyped =
  ## Calls `callee` with fields form object `args` unpacked as individual arguments.
  ## 
  ## This is similar to `unpackVarargs` in `std/macros` but for call a function
  ## using the values from an object
  
  runnableExamples:
    type AddObj = object
      a*: int
      b*: int
    proc add(a, b: int): int =
      result = a + b
    let args = AddObj(a: 1, b: 2)
    let res = unpackObjectArgs(add, args)
    assert res == 3
  
  let paramNames = arg.getType()[2]
  result = newCall(callee)
  for nm in paramNames:
    result.add quote do:
      `arg`.`nm`
  for extra in extras:
    result.add extra

macro unpackObjectArgFields*(callee: untyped; arg: typed, extras: varargs[untyped]): untyped =
  ## Similar to `unpackObjectArgs` but with named parameters based on field names.
  ## 
  
  runnableExamples:
    type AddObj = object
      a*: int
      b*: int
    proc divide(b, a: int): int =
      result = b div a
    let args = AddObj(a: 1, b: 0)
    let res = unpackObjectArgFields(divide, args)
    assert res == 0
  
  let paramNames = arg.getType()[2]
  result = newCall(callee)
  for nm in paramNames:
    let p = quote do:
      `arg`.`nm`
    result.add nnkExprEqExpr.newTree(nm, p)
  for extra in extras:
    result.add extra

type
  Param* = object
    idx*: int
    name*: string
    typ*: NimNode

proc getBaseType(fparam: Param): NimNode =
  result = fparam.typ.getTypeImpl()

proc fnParamNames(node: NimNode): OrderedTable[string, Param] = 
  ## get all parameters from `FormalParams` in easy form
  node.expectKind nnkFormalParams
  var idx = 0
  for paramNode in node[1..^1]:
    let
      nms = paramNode[0..<paramNode.len() - 2]
      tp = paramNode[^2]
    for nm in nms:
      let n = nm.strVal
      result[n] = Param(idx: idx, name: n, typ: tp)
      idx.inc

# iterator attributes*(blk: NimNode): (int, tuple[name: string, code: NimNode]) =
#   for idx, item in blk:
#     if item.kind == nnkStmtList:
#       var name = item[0].repr
#       if item.len() > 2:
#         let code = newStmtList(item[1..^1])
#         yield (idx, (name: name, code: code))
#       else:
#         yield (idx, (name: name, code: item[1]))

proc processLambda(
    lname: string,
    lstmt: NimNode,
    fparam: Param,
    fparamTyp: NimNode,
): NimNode =
  if lstmt.kind != nnkDo and fparamTyp[0].len() > 1:
    ## print error in corner case of anonymous proc with args
    let fsyntax = fparamTyp[0].repr.replace("):",") ->")
    var msg = &"label `{lname}` is an anonymous proc that"
    msg &= &" takes one or more arguments."
    msg &= &" Please use the do call syntax: \n"
    msg &= &"\t{lname} do {fsyntax} "
    error(msg, fparam.typ)

  var pstmt = quote do:
    let fn: proc (): string =
      proc (): string =
        result = "test"
    fn
  
  # find our new lambda...
  var
    letSect = pstmt[0]
    idDefs = letSect[0]
    procTy = idDefs[1]
    lamDef = idDefs[2]

  pstmt.copyLineInfo(lstmt)
  procTy[0]= fparam.getBaseType()[0]
  procTy.pragma= fparamTyp.pragma

  if lstmt.kind == nnkDo:
    lamDef.params= params(lstmt)
    lamDef.body= body(lstmt)
  else:
    lamDef.params= fparam.getBaseType()[0]
    lamDef.body= lstmt
  
  result = pstmt

proc processLabel(
    varList: var OrderedTable[int, (string, NimNode)],
    fnParams: OrderedTable[string, Param],
    lcode: (string, NimNode),
) =
  let
    lname = lcode[0]
    lstmt = lcode[1]
    fparam = fnParams[lname]
    fparamTyp = fparam.getBaseType()
  
  # lambda's require specialized handling to work reliably
  if fparamTyp.kind == nnkProcTy:
    let pstmt = processLambda(lname, lstmt, fparam, fparamTyp)
    varList[fparam.idx] = (fparam.name, pstmt)
  else:
    varList[fparam.idx] = (fparam.name, lstmt)

type
  LabelTransformer* = proc (code: (string, NimNode)): (string, NimNode)

let noTransforms {.compileTime.} =
  proc (code: (string, NimNode)): (string, NimNode) = 
    result = code

proc unpackLabelsImpl*(
    transformer: LabelTransformer,
    callee: NimNode,
    args: NimNode
): NimNode {.compileTime.} =
  ## unpacks 'labels' as named arguments. Labels are 
  ## created using the Nim `command`, `call`, `do`, and
  ## `name parameter` syntaxes. 
  ## 
  ## This lets you write create templates that look
  ## like YAML type code. 
  ## 
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
      echo name(), ":", " a: ", $a, " b: ", $b
    
    template Fizz(blk: varargs[untyped]) =
      unpackLabelsAsArgs(fizz, blk)
    
    let fn = proc (): string = "fizzy"
    Fizz:
      name: fn() # due to typing limitations this will wrap `fn` in another closure 
      a: 11
      b: 22
  
  args.expectKind nnkArgList
  let fnImpl = getTypeImpl(callee)

  fnImpl.expectKind(nnkProcTy)
  let fnParams = fnImpl[0].fnParamNames()
  let fnIdxParams = fnParams.pairs().toSeq()

  ## parse out params in various formats
  var varList: OrderedTable[int, (string, NimNode)]
  var idx = 0
  for arg in args:
    if arg.kind == nnkStmtList:
      for labelArg in arg:
        # handle `label` args
        labelArg.expectKind nnkCall
        idx = -1
        let
          rcode = (labelArg[0].strVal, labelArg[1])
          lcode = transformer(rcode)
        try:
          varList.processLabel(fnParams, lcode)
        except KeyError:
          error(fmt"label argument `{lcode[0]}` not found in proc arguments list. Options are: {fnParams.keys().toSeq().repr}", labelArg[0])
    elif arg.kind == nnkExprEqExpr:
      # handle regular named parameters
      let lname = arg[0].strVal
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
  # for v in fnIdxParams:
  #   echo "fnIdxParams: v: ", v.repr 

  result = newCall(callee)
  result.copyLineInfo(args[0])
  for idx, (nm, vl) in varList.pairs():
    let fname = fnIdxParams[idx][0]
    if nm == "":
      result.add nnkExprEqExpr.newTree(ident fname, vl)
    else:
      result.add nnkExprEqExpr.newTree(ident nm, vl)

  # echo "repr: "
  # echo repr result

macro unpackLabelsAsArgsWithFn*(
    transforms: static[LabelTransformer];
    callee: typed,
    args: varargs[untyped]
): untyped =
  result = unpackLabelsImpl(transforms, callee, args)

macro unpackLabelsAsArgs*(
    callee: typed;
    args: varargs[untyped]
): untyped =
  result = unpackLabelsImpl(noTransforms, callee, args)

