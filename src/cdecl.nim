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
  let varName = ident(name.strVal) 
  let procName = macroutils.name(def)
  var params = macroutils.params(def)
  let retType = params[0]
  let prags = macroutils.pragmas(def)
  var args = params[1..^1]

  var ctoks: seq[NimNode]
  for arg in args.mitems:
    if arg.kind == nnkIdentDefs and arg.typ.repr == "CToken":
      ctoks.add macroutils.name(arg)
      arg.typ= ident "untyped"

  assert ctoks.len() == 1 # TODO: support multple vars decl?

  let n1 = ctoks[0]
  result = quote do:
    template `procName`() =
      var `n1` {.inject, importc, nodecl.}: 
      {.emit: "/*TYPESECTION*/\n$1($2, $3); " %
        [ `varName`, symbolName(`n1`), $size ] .}
  
  result.params= FormalParams(retType, args)
  echo fmt"cmacro: {result.repr=}"


