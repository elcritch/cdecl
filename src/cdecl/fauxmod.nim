import std/typetraits
import std/hashes
import std/tables
import std/macrocache
import std/strutils
import std/macros
import std/genasts

## ====================
## Faux Modules for Nim
## ====================
## 

type
  FauxModule* = object

macro module*(name, blk: untyped) =
  echo "name: ", name
  result = genAst(Mod=ident(name.strVal)):
    type
      Mod* = distinct FauxModule
  
  echo "result:"
  echo result.treeRepr

expandMacros:
  module StdMsgs:

    module Bool:
      type
        Bool* = object
          data*: bool

      proc init*(): BoolMsg =
        echo "init"

type
  `StdMsgs.Bool`* = object
    data*: bool

proc init*(): `StdMsgs.Bool` =
  echo "init"

template Bool*[T: StdMsgs](typ: typedesc[T]): typedesc =
  `StdMsgs.Bool`

proc init*[T: `StdMsgs.Bool`](typ: typedesc[T]): `StdMsgs.Bool` =
  echo "init"

import unittest

suite "faux module":

  test "init":
    let msg: StdMsgs.Bool = StdMsgs.Bool.init()
    echo "msg: ", msg

