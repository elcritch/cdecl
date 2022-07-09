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
    default*: NimNode

proc getBaseType(fparam: Param): NimNode =
  result = fparam.typ.getTypeImpl()

proc fnParamNames(node: NimNode): OrderedTable[string, Param] = 
  ## get all parameters from `FormalParams` in easy form
  node.expectKind nnkFormalParams
  var idx = 0
  echo "paramNodes: ", treeRepr node
  for paramNode in node[1..^1]:
    let
      nms = paramNode[0..<paramNode.len() - 2]
      tp = paramNode[^2]
      default = paramNode[^1]
      resolvedTp = 
        if tp.kind == nnkEmpty:
          # figure out the type from default kind
          echo "FNPARAMS:tp: ", node.getTypeImpl().repr
          tp
        else:
          tp
    for nm in nms:
      let n = nm.strVal
      result[n] = Param(idx: idx, name: n, typ: tp, default: default)
      idx.inc

proc processLabel(
    varList: var OrderedTable[int, (string, NimNode)],
    fnParams: OrderedTable[string, Param],
    labelArg: NimNode,
) =
  labelArg.expectKind nnkCall
  let
    lname = labelArg[0].strVal
    lstmt = labelArg[1]
    fparam = fnParams[lname]
  
  echo "fparam:type: ", repr fparam.name, " ", repr fparam.typ, " kd: ", repr fparam.typ.kind
  echo "nameproc: ", treerepr fparam.getBaseType()

  if lstmt.kind == nnkDo:
    let doFmlParam = params(lstmt)
    let doBody = body(lstmt)
    let plet = quote do:
        let x = proc () = discard
    let plambda = plet[0][^1]
    plambda.params= doFmlParam
    plambda.body= doBody
    let pstmt = quote do:
        let fn = `plambda`
        fn
    varList[fparam.idx] = (fparam.name, pstmt)
  elif fparam.typ.kind == nnkProcTy:
    if fparam.typ[0].len() > 1:
      ## print error in corner case of anonymous proc with args
      let fsyntax = fparam.typ[0].repr.replace("):",") ->")
      var msg = &"label `{lname}` is an anonymous proc that"
      msg &= &" takes one or more arguments."
      msg &= &" Please use the do call syntax: \n"
      msg &= &"\t{lname} do {fsyntax} "
      error(msg)

    var pstmt = quote do:
      let fn: proc (): string =
        proc (): string =
          result = "test"
      fn
    
    var
      letSect = pstmt[0]
      idDefs = letSect[0]
      procTy = idDefs[1]
      lamDef = idDefs[2]

    procTy[0]= fparam.typ[0]
    lamDef.params= fparam.typ[0]
    lamDef.body= lstmt

    varList[fparam.idx] = (fparam.name, pstmt)
  else:
    varList[fparam.idx] = (fparam.name, lstmt)

macro unpackLabelsAsArgs*(
    callee: typed;
    args: varargs[untyped]
): untyped =
  ## unpacks labels as named arguments. 
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
  echo "TP IMPL: ", treerepr fnImpl
  fnImpl.expectKind(nnkProcTy)
  let fnParams = fnImpl[0].fnParamNames()
  let fnIdxParams = fnParams.pairs().toSeq()

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
  # for v in fnIdxParams:
  #   echo "fnIdxParams: v: ", v.repr 

  result = newCall(callee)
  for idx, (nm, vl) in varList.pairs():
    let fname = fnIdxParams[idx][0]
    # echo "fname: ", fname
    if nm == "":
      result.add nnkExprEqExpr.newTree(ident fname, vl)
    else:
      result.add nnkExprEqExpr.newTree(ident nm, vl)


