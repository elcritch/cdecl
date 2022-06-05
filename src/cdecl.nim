# This is just an example to get you started. A typical library package
# exports the main API in this file. Note that you cannot rename this file
# but you can remove it if you wish.

import macros
import macroutils
import strformat, strutils, sequtils
export macros

macro symbolName*(x: typed): string =
  x.toStrLit

type
  CToken* = static[string]

template cname*(name: untyped): CToken =
  symbolName(name)

macro cdeclmacro*(name: string, def: untyped) =
  let varNameStr = name.strVal 
  let varName = ident(name.strVal) 
  let procName = macroutils.name(def)
  var params = macroutils.params(def)
  let retType = params[0]
  let prags = macroutils.pragmas(def)
  var args = params[1..^1]

  var ctoks: seq[NimNode]
  var cFmtArgs = Bracket(varNameStr)
  for arg in args.mitems:
    if arg.kind == nnkIdentDefs and arg.typ.repr == "CToken":
      ctoks.add macroutils.name(arg)
      arg.typ= ident "untyped"
      cFmtArgs.add Call("symbolName", macroutils.name(arg))
    else:
      cFmtArgs.add Call("$", macroutils.name(arg))

  assert ctoks.len() == 1 # TODO: support multple vars decl?

  var cFmtStr = "/*VARSECTION*/\n $1("
  cFmtStr &= toSeq(0..<args.len()).mapIt("$" & $(it+2)).join(", ")
  cFmtStr &= "); "
  let cFmtLit = newLit(cFmtStr)
  let n1 = macroutils.name(args[0])

  result = quote do:
    template `procName`() =
      var `n1` {.inject, importc, nodecl.}: `retType`
      {.emit: `cFmtLit` % `cFmtArgs` .}
  
  result.params= FormalParams(Empty(), args)
  echo fmt"cmacro: {result.repr=}"


