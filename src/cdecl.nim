# This is just an example to get you started. A typical library package
# exports the main API in this file. Note that you cannot rename this file
# but you can remove it if you wish.

import macros, sugar, tables
import strformat, strutils, sequtils

import macroutils

template mname(node: NimNode) = macroutils.name(node)

type
  CToken* = static[string]
  CRawStr* = distinct static[string]

macro symbolName*(x: untyped): string =
  x.toStrLit
template symbolVal*(x: CRawStr): string =
  x.string

template cname*(name: untyped): CToken =
  symbolName(name)

macro cdeclmacro*(name: string, def: untyped) =
  ## Macro helper for wrapping a C macro that declares 
  ## a new C variable.
  ## 
  ## It handles emitting the appropriate
  ## C code for calling the macro. 
  ## 
  ## It can define Nim variables using importc to wrap the
  ## generated variable. This is done using `varName: CToken` in 
  ## the argument list and adding a `cdeclsVar(varName -> varType)`
  ## pragma. The `cdeclsVar` tells the macro which CToken argument
  ## to use and its type.
  ## 
  ## The macro will pass any extra pragmas to the
  ## variable. If the `global` pragma is passed in
  ## the emitted C code will be put in the 
  ## `/*VARSECTION*/` section. 
  ## 
  runnableExamples:
    import macros
    import cdecl 

    {.emit: """/*TYPESECTION*/
    /* define example C Macro for testing */
    #define C_DEFINE_VAR(NM, SZ) int NM[SZ]
    #define C_DEFINE_VAR_DUO(NM, SZ, NM2) int NM[SZ]
    """.}

    proc CDefineVar*(name: CToken, size: static[int]): array[size, int] {.
      cdeclmacro: "C_DEFINE_VAR", cdeclsVar(name -> array[size, int32]).}
    
    # Then it's possible to invoke CDefineVar to call the C macro and
    # generate a variable:
    const cVarSz = 4
    CDefineVar(myVar, cVarSz)

    static:
      discard """`CDefineVar` generates code that looks like:"""
      discard quote do:
        template CDefineVar*(name: untyped, size: static[int]) =
          var name* {.inject, importc, nodecl.}: array[size, int]
        {.emit: "/*VARSECTION*/\nC_DEFINE_VAR($1, $2); " % [ symbolName(name), $size, ] .}

  runnableExamples:
    import macros
    import cdecl 

    {.emit: """/*TYPESECTION*/
    /* define example C Macro for testing */
    #define C_DEFINE_VAR_ADDITION(NM, SZ, N2) \
      int32_t NM[SZ]; \
      NM[0] = N2
    """.}

    proc CDefineVarStackRaw*(name: CToken, size: static[int], otherRaw: CRawStr): array[size, int32] {.
      cdeclmacro: "C_DEFINE_VAR_ADDITION", cdeclsVar(name -> array[size, int32]).}
    
    # Pass a raw string to the C macro:
    proc runCDefineVarStackRaw() =
      CDefineVarStackRaw(myVarStackRaw, 5, CRawStr("40+2"))
      assert myVarStackRaw[0] == 42
    

  let varNameStr = name.strVal 
  let varName = ident(name.strVal) 
  let procName = macroutils.name(def)
  var params = macroutils.params(def)
  # let retType = params[0]
  let prags = macroutils.pragmas(def)
  let generics = macroutils.generics(def)
  var args = params[1..^1]

  let isGlobal = prags.toSeq().anyIt(it.repr.eqIdent "global")
  var decls = initTable[string, NimNode]()

  ## process pragmas
  for prag in prags:
    if prag.kind == nnkCall and prag[0].eqident("cdeclsVar"):
      let vn = prag[1]
      if vn.kind != nnkInfix or not vn[0].eqIdent("->"):
        error("must pass cdeclsVar argument of `name -> type`")
      let name = vn[1].repr
      let rType = vn[2]
      decls[name] = rType

  var cFmtArgs = Bracket(varNameStr)
  for arg in args.mitems:
    if arg.kind == nnkIdentDefs and arg.typ.repr.eqIdent("CToken"):
      arg.typ= ident "untyped"
      cFmtArgs.add Call("symbolName", arg.mname)
    elif arg.kind == nnkIdentDefs and arg.typ.repr.eqIdent("CRawStr"):
      arg.typ= ident "CRawStr"
      cFmtArgs.add Call("symbolVal", arg.mname)
    elif arg.kind == nnkIdentDefs:
      if arg[1].kind != nnkBracketExpr:
        error("arguments to `CDefineVar` must be wrapped in static[T]. Perhaps try `static[$1]`" % [ arg[0].repr ] )
      if arg[1][0].strVal != "static":
        error("arguments to `CDefineVar` must be wrapped in static[T]. Got: " & arg.repr )
      
      if arg[1][1].eqIdent("string"):
        cFmtArgs.add Call("repr", arg.mname)
      else:
        cFmtArgs.add Call("$", arg.mname)
    else:
      error("arguments to `CDefineVar` must a type wrapped in `static[T] or be a `CToken`. Instead got: $1." % [repr(arg)]  )
  
  var cFmtStr = ""
  if isGlobal: cFmtStr &= "/*VARSECTION*/\n"
  cFmtStr &= "$1("
  cFmtStr &= toSeq(0..<args.len()).mapIt("$" & $(it+2)).join(", ")
  cFmtStr &= "); /* CDefineVar macro invocation */"
  let cFmtLit = newLit(cFmtStr)
  let n1 = args[0].mname

  var varDecls = newStmtList()
  for name, rtype in decls:
    let nm = ident name
    var vd = quote do:
      var `nm` {.inject, importc, nodecl.}: `rtype`
    if isGlobal:
      vd[0][0][1].add ident "global"
    varDecls.add vd
  
  result = quote do:
    template `procName`() =
      `varDecls`
      {.emit: `cFmtLit` % `cFmtArgs` .}
  
  result.params= FormalParams(Empty(), args)
  # echo fmt"cmacro: {result.repr=}"
  # echo fmt"cmacro: {result.treerepr=}"


