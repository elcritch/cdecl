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
  `StdMsgsOther`* = object

  `StdMsgs.Bool`* = object
    data*: bool
  
  `module[StdMsgs]` = concept s
    s is typedesc[StdMsgs]
  `module[StdMsgs.Bool]` = concept s
    s is typedesc[`StdMsgs.Bool`]

proc init*(): `StdMsgs.Bool` =
  echo "init"

template Bool*(typ: `module[StdMsgs]`): typedesc[`StdMsgs.Bool`] =
  `StdMsgs.Bool`

proc test*(a: `module[StdMsgs.Bool]`, b: int) =
  echo "testing..", a + b

proc init*(typ: `module[StdMsgs.Bool]`): `StdMsgs.Bool` =
  echo "init"

import unittest

suite "faux module":

  test "init":
    var msg: StdMsgs.Bool
    # var msg2: StdMsgsOther.Bool
    # msg = StdMsgs.Bool.init()
    echo "msg: ", msg
    # test(StdMsgs.Bool, 1)

