# This is just an example to get you started. A typical library package
# exports the main API in this file. Note that you cannot rename this file
# but you can remove it if you wish.

import macros
import macroutils
import strformat
export macros

macro symbolName*(x: typed): string =
  x.toStrLit

type
  CToken* = static[string]

template cname*(name: untyped): CToken =
  symbolName(name)

macro cdeclmacro*(name: string, def: untyped) =
  let procName = macroutils.name(def)
  var params = macroutils.params(def)
  let retType = params[0]
  let prags = macroutils.pragmas(def)
  var args = params[1..^1]
  echo fmt"cmacro: {procname.treeRepr=}"
  echo fmt"cmacro: {params.treeRepr=}"
  echo fmt"cmacro: {args.repr=}"
  echo fmt"cmacro: {retType.treeRepr=}"
  echo fmt"cmacro: {prags.treeRepr=}"
  result = quote do:
    template `procName`() =
      var `procName` {.inject, importc, nodecl.}: c_var_t[size]
      {.emit: "/*TYPESECTION*/\nC_DEFINE_VAR($1, $2); "   .}
  
  for arg in args.mitems:
    echo fmt"cmacro: {arg.treeRepr=}"
    if arg.kind == nnkIdentDefs and arg.typ.repr == "CToken":
      arg.typ= ident "untyped"

  result.params= FormalParams(retType, args)
  echo fmt"cmacro: {result.repr=}"


