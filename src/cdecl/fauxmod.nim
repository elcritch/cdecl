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

# macro module*(name, blk: untyped) =
#   echo "name: ", name
#   result = genAst(Mod=ident(name.strVal)):
#     type
#       Mod* = distinct FauxModule
  
#   echo "result:"
#   echo result.treeRepr
#   result = newEmptyNode()

# expandMacros:
#   module StdMsgs:

#     module Bool:
#       type
#         Bool* = object
#           data*: bool

#       proc init*(): BoolMsg =
#         echo "init"

type
  `StdMsgs`* = object
  `StdMsgsOther`* = object

  `StdMsgs.Bool`* = object
    data*: bool
  
  `fauxmod[StdMsgs]`* = concept s
    s is typedesc[StdMsgs]
  `fauxmod[StdMsgs.Bool]`* = concept s
    s is typedesc[`StdMsgs.Bool`]

proc init*(): `StdMsgs.Bool` =
  echo "init"

template Bool*(typ: `fauxmod[StdMsgs]`): typedesc[`StdMsgs.Bool`] =
  `StdMsgs.Bool`

proc test*[T: StdMsgs.Bool](a: typedesc[T], b: int) =
  echo "testing..", a + b

proc init*[T: `StdMsgs.Bool`](_: typedesc[T]): `StdMsgs.Bool` =
  echo "init"
  result.data = true

import unittest

suite "faux module":

  test "init":
    var msg: StdMsgs.Bool
    # var msg2: StdMsgsOther.Bool
    msg = StdMsgs.Bool.init()
    echo "msg: ", msg
    # test(StdMsgs.Bool, 1)

