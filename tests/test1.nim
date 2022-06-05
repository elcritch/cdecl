# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest
import strutils, strformat
import cdecl

type
  c_var = object
  c_var_other_t = object

template CDefineVar*(name: untyped, size: static[int]) =
  var name* {.inject, importc, nodecl.}: ptr c_var_other_t
  {.emit: "/*TYPESECTION*/ C_DEFINE_VAR($1, $2);" % [ symbolName(name), $size, ] .}

const cVarSz = 1024
CDefineVar(myVar, cVarSz)
var blink {.exportc.}: c_var
 
import cdecl
test "can add":
  check add(5, 5) == 10

  ##   KDefineStack(blinkStack, blinkStackSz.int)
  ##   var blink {.exportc.}: k_thread

