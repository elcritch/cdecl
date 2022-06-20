# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest
import strutils, strformat

import cdecl/cdecls

type
  c_var_t[N] = array[N, int]

{.emit: """/*TYPESECTION*/
/* define example C Macro for testing */
#define C_DEFINE_VAR(NM, SZ) int32_t NM[SZ]
#define C_DEFINE_VAR_DUO(NM, SZ, NM2) int32_t NM[SZ]
#define C_DEFINE_VAR_ADDITION(NM, SZ, N2) \
  int32_t NM[SZ]; \
  NM[0] = N2

#define C_PRINT(FS, AA, BB) printf(FS, AA, BB)
""".}

proc CDefineVar*(name: CToken, size: static[int]) {.
  cdeclmacro: "C_DEFINE_VAR", cdeclsVar(name -> array[size, int32]).}

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

proc CDefineVarDuo*(name: CToken, size: static[int], otherCVar: CToken) {.
  cdeclmacro: "C_DEFINE_VAR_DUO", global, cdeclsVar(name -> array[size, int32]).}

CDefineVarDuo(myVarDuo, 5, other)
 
test "test duo myVar declaration":
  let testVal = [1'i32,2,3,4,5]
  myVarDuo[0..4] = testVal
  check myVarDuo.len() == 5
  echo "myVar: ", repr myVarDuo
  let res = myVarDuo == testVal
  check res

proc CDefineVarStack*(name: CToken, size: static[int]) {.
  cdeclmacro: "C_DEFINE_VAR", cdeclsVar(name -> array[size, int32]).}
 
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

proc CDefineVarStackRaw*(name: CToken, size: static[int], otherRaw: CRawStr) {.
  cdeclmacro: "C_DEFINE_VAR_ADDITION", cdeclsVar(name -> array[size, int32]).}
 
proc runCDefineVarStackRaw() =
  const x = CRawStr("40+2")
  CDefineVarStackRaw(myVarStackRaw, 5, x)
  let testVal = [42'i32,1,2,3,4]
  myVarStackRaw[1..4] = testVal[1..^1]
  check myVarStackRaw.len() == 5
  echo "myVarStackRaw: ", repr myVarStackRaw
  let res = myVarStackRaw == testVal
  check res

test "test myVar stack with raw":
  runCDefineVarStackRaw()

proc CPRINT*(fs: static[string], name: static[string], otherRaw: static[int])  {.
  cdeclmacro: "C_PRINT".}
 
proc runCDefineVarRaw() =
  CPRINT("%s => %d", "hello", 22)
  echo ""

test "test raw c arguments":
  runCDefineVarRaw()

template CDefineVarDuoWrapper*(name: untyped, size: static[int], otherCVar: untyped) =
  CDefineVarDuo(name, size, otherCVar)
  echo "name: ", repr(name)
 
CDefineVarDuoWrapper(myVarDuoWrap, 5, other)

test "test duo myVar declaration":
  let testVal = [1'i32,2,3,4,5]
  myVarDuoWrap[0..4] = testVal
  check myVarDuoWrap.len() == 5
  echo "myVar: ", repr myVarDuoWrap
  let res = myVarDuoWrap == testVal
  check res
