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

  StdMsgsBool* = object
    data*: bool
  StdMsgsBools* = object
    data*: bool

template Bool*(typ: typedesc[StdMsgs]): typedesc[StdMsgsBool] =
  StdMsgsBool
template Bools*(typ: typedesc[StdMsgs]): typedesc[StdMsgsBools] =
  StdMsgsBools

proc test*(a: StdMsgsBool, b: int) =
  echo "testing: ", a.data, " b: ", b

proc init*(typ: typedesc[StdMsgs.Bool]): StdMsgs.Bool =
  echo "init"
  result.data = true

import unittest

suite "faux module":

  test "init":
    var msg: StdMsgs.Bool
    # var msg2: StdMsgsOther.Bool
    msg = StdMsgsBool.init()
    echo "msg: ", msg
    test(msg, 1)

