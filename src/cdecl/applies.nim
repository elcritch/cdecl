import options
import macros, typetraits, tables, strformat, strutils, sequtils

macro unpackObjectArgs*(
    callee: untyped;
    arg: typed,
    extras: varargs[untyped]
): untyped =
  ## Calls `callee` with fields form object `args` unpacked
  ## as individual arguments.
  ## 
  ## This is similar to `unpackVarargs` in `std/macros` but
  ## for call a function using the values from an object.
  ## 
  
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

macro unpackObjectArgFields*(
    callee: untyped;
    arg: typed,
    extras: varargs[untyped]
): untyped =
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

type LabelFormat = enum AssignsFmt, LabelFmt, LabelStrictFmt

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
  var lstmt = lstmt
  if lstmt.kind == nnkProcDef:
    lstmt = lstmt.body
  elif lstmt.kind != nnkDo and fparamTyp[0].len() > 1:
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
    format: LabelFormat,
) =
  let
    lname = lcode[0]
    lstmt = lcode[1]
    fparam = fnParams[lname]
    fparamTyp = fparam.getBaseType()
  
  # lambda's require specialized handling to work reliably
  if fparamTyp.kind == nnkProcTy:
    var pstmt: NimNode
    case format:
    of AssignsFmt:
      if lstmt.kind == nnkLambda:
        pstmt = lstmt
      elif lstmt.kind == nnkProcDef:
        # pstmt = lstmt
        pstmt = processLambda(lname, lstmt, fparam, fparamTyp)
      else:
        pstmt = processLambda(lname, lstmt, fparam, fparamTyp)
    of LabelFmt, LabelStrictFmt:
      pstmt = processLambda(lname, lstmt, fparam, fparamTyp)
    varList[fparam.idx] = (fparam.name, pstmt)
  else:
    varList[fparam.idx] = (fparam.name, lstmt)

type
  LabelTransformer* =
    proc (code: (string, NimNode)): Option[(string, NimNode)]

let noTransforms {.compileTime.} =
  proc (code: (string, NimNode)): Option[(string, NimNode)] = 
    result = some(code)

proc unpackLabelsImpl(
    transformer: LabelTransformer,
    format: LabelFormat,
    callee: NimNode,
    args: NimNode
): NimNode {.compileTime.} =
  args.expectKind nnkArgList
  let fnImpl = getTypeImpl(callee)

  fnImpl.expectKind(nnkProcTy)
  let fnParams = fnImpl[0].fnParamNames()
  let fnIdxParams = fnParams.pairs().toSeq()

  ## parse out params in various formats
  var varList: OrderedTable[int, (string, NimNode)]
  var idx = 0
  for arg in args:
    # echo "ARG: ", arg.treeRepr
    if arg.kind == nnkStmtList:
      for larg in arg:
        var labelArg = larg
        # handle `label` args
        idx = -1
        var rcode: (string, NimNode)

        case format:
        of LabelFmt, LabelStrictFmt:
          ## handle prefixes
          if labelArg.kind == nnkPrefix:
            let id = ident(labelArg[0].repr & labelArg[1].repr)
            copyLineInfo(id, labelArg[0])
            var larg = nnkCall.newTree(id, labelArg[2])
            labelArg = larg

          # handle argument
          labelArg.expectKind nnkCall
          rcode = (labelArg[0].strVal, labelArg[1])
        of AssignsFmt:
          ## handle prefixes
          if labelArg[0].kind == nnkPrefix:
            let id = ident(labelArg[0][0].strVal & labelArg[0][1].strVal)
            copyLineInfo(id, labelArg[0])
            labelArg[0] = id

          # handle argument
          if labelArg.kind == nnkProcDef:
            rcode = (labelArg.name.strVal, labelArg)
          else:
            labelArg.expectKind nnkAsgn
            rcode = (labelArg[0].strVal, labelArg[1])

        let tres = transformer(rcode)
        if tres.isSome():
          let lcode = tres.get()
          try:
            varList.processLabel(fnParams, lcode, format)
          except KeyError:
            error(fmt"label argument `{lcode[0]}` not found in proc arguments list. Options are: {fnParams.keys().toSeq().repr}", labelArg[0])
    
    elif arg.kind in [nnkExprEqExpr, nnkExprColonExpr]:
      var arg = arg
      ## handle prefixes
      # echo "LBL: ", arg.treeRepr
      if arg[0].kind == nnkPrefix:
        let id = ident(arg[0][0].strVal & arg[0][1].strVal)
        copyLineInfo(id, arg[0])
        arg[0] = id
      
      case format:
      of AssignsFmt: arg.expectKind(nnkExprEqExpr)
      of LabelStrictFmt: arg.expectKind(nnkExprEqExpr)
      of LabelFmt: discard

      # handle regular named parameters
      let lname = arg[0].strVal
      let fp = fnParams[lname]
      varList[fp.idx] = (fp.name, arg[1])
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
  # for idx, (nm, vl) in varList.pairs():
  #   echo "varList: v: ", (nm, vl).repr()

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
  result = unpackLabelsImpl(transforms, LabelFmt, callee, args)

macro unpackLabelsAsArgs*(
    callee: typed;
    args: varargs[untyped]
): untyped =
  ## Unpacks 'labels' as named arguments. Labels are 
  ## created using the Nim `command`, `call`, `do`, and
  ## `name parameter` syntaxes. 
  ## 
  ## This lets you write DSL's taht look like YAML.
  ## 
  runnableExamples:
    proc foo(name: string = "buzz", a, b: int) =
      echo name, ":", " a: ", $a, " b: ", $b
    
    template MyFoo(blk: varargs[untyped]) =
      unpackLabelsAsArgs(foo, blk)
    
    MyFoo(name: "buzz"):
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
  
  result = unpackLabelsImpl(noTransforms, LabelStrictFmt, callee, args)

macro unpackLabelsAsArgsNonStrict*(
    callee: typed;
    args: varargs[untyped]
): untyped =
  ## stricter format of 
  result = unpackLabelsImpl(noTransforms, LabelFmt, callee, args)

macro unpackBlockArgsWithFn*(
    transforms: static[LabelTransformer];
    callee: typed,
    args: varargs[untyped]
): untyped =
  result = unpackLabelsImpl(transforms, AssignsFmt, callee, args)

macro unpackBlockArgs*(
    callee: typed;
    args: varargs[untyped]
): untyped =
  ## Unpacks named arguments from a block to apply to 
  ## a function.  
  ## 
  ## This lets you write create templates that look
  ## like YAML type code. 
  ## 
  runnableExamples:
    proc foo(name: string = "buzz", a, b: int) =
      echo name, ":", " a: ", $a, " b: ", $b
    
    template MyFoo(blk: varargs[untyped]) =
      unpackLabelsAsArgs(foo, blk)
    
    MyFoo(name = "buzz"):
      a = 11
      b = 22
  
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
  
  result = unpackLabelsImpl(noTransforms, AssignsFmt, callee, args)

