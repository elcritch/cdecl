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
  let params = macroutils.params(def)
  let retType = params[0]
  let args = params[1..^1]
  let prags = macroutils.pragmas(def)
  echo fmt"cmacro: {procname.treeRepr=}"
  echo fmt"cmacro: {params.treeRepr=}"
  echo fmt"cmacro: {args.repr=}"
  echo fmt"cmacro: {retType.treeRepr=}"
  echo fmt"cmacro: {prags.treeRepr=}"
  result = newStmtList()

