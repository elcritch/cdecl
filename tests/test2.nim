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
  c_var_t[N] = array[N, int]

{.emit: """/*TYPESECTION*/
/* define example C Macro for testing */
#define C_DEFINE_VAR(NM, SZ) int NM[SZ]
""".}

proc CDefineVar*(name: CToken, size: static[int]): array[size, int] {.
  cdeclmacro: "C_DEFINE_VAR".}

const cVarSz = 4
CDefineVar(myVar, cVarSz)
 
test "test myVar declaration":
  let testVal = [1,2,3,4]
  myVar[0..3] = testVal
  check myVar.len() == cVarSz
  echo "myVar: ", repr myVar
  let res = myVar == testVal
  check res
