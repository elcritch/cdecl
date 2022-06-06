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
#define C_DEFINE_VAR(NM, SZ) int32_t NM[SZ]
#define C_DEFINE_VAR_DUO(NM, SZ, NM2) int32_t NM[SZ]
#define C_DEFINE_VAR_ADDITION(NM, SZ, N2) \
  int32_t NM[SZ]; \
  NM[0] = N2
""".}

proc CDefineVar*(name: CToken, size: static[int]): array[size, int32] {.
  cdeclmacro: "C_DEFINE_VAR".}

const canCompilewrongCallSyntax = 
    compiles do:
      proc CDefineVar*(name: CToken, size: int): array[size, int32] {.
        cdeclmacro: "C_DEFINE_VAR".}

const cVarSz = 4
CDefineVar(myVar, cVarSz)
 
test "test myVar declaration":
  let testVal = [1'i32,2,3,4]
  myVar[0..3] = testVal
  check myVar.len() == cVarSz
  echo "myVar: ", repr myVar
  let res = myVar == testVal
  check res

  check canCompilewrongCallSyntax == false

proc CDefineVarDuo*(name: CToken, size: static[int], otherCVar: CToken): array[size, int32] {.
  cdeclmacro: "C_DEFINE_VAR_DUO", global.}

CDefineVarDuo(myVarDuo, 5, other)
 
test "test duo myVar declaration":
  let testVal = [1'i32,2,3,4,5]
  myVarDuo[0..4] = testVal
  check myVarDuo.len() == 5
  echo "myVar: ", repr myVarDuo
  let res = myVarDuo == testVal
  check res

proc CDefineVarStack*(name: CToken, size: static[int]): array[size, int32] {.
  cdeclmacro: "C_DEFINE_VAR".}
 
proc runCDefineVarStack() =
  CDefineVarStack(myVarStack, 5)
  let testVal = [1'i32,2,3,4,5]
  myVarStack[0..4] = testVal
  check myVarStack.len() == 5
  echo "myVar: ", repr myVarStack
  let res = myVarStack == testVal
  check res

test "test myVar stack declaration":
  runCDefineVarStack()

test "test myVar stack no-declaration":

  const canCompileMissingVar = 
      compiles do:
        echo myVarStack.repr
  check canCompileMissingVar == false

proc CDefineVarStackRaw*(name: CToken, size: static[int], otherRaw: CRawStr): array[size, int32] {.
  cdeclmacro: "C_DEFINE_VAR_ADDITION".}
 
proc runCDefineVarStackRaw() =
  CDefineVarStackRaw(myVarStackRaw, 5, CRawStr("40+2"))
  let testVal = [1'i32,2,3,4,5]
  myVarStackRaw[0..4] = testVal
  # let testVal = [42'i32,2,3,4,5]
  # for i in 1..4:
    # myVarStackRaw[1] = testVal[1]
  check myVarStackRaw.len() == 5
  echo "myVarStackRaw: ", repr myVarStackRaw
  let res = myVarStackRaw == testVal
  check res

test "test myVar stack with raw":
  runCDefineVarStackRaw()