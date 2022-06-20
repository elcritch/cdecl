import unittest
import strutils, strformat

import cdecl/cdeclapi
import cdecl/cdecls


{.emit: """/*TYPESECTION*/
/* define example C Macro for testing */
int myVar = 0;

#define C_VAR(vn) vn
#define C_VAR_NAME(AA, BB) (AA ## BB)

""".}

proc CVarName*(prefix: CToken, name: CToken): CRawStr {.cmacrowrapper: "C_VAR_NAME".}

proc CVar*(varname: CRawStr): cint {.cmacrocall: "C_VAR".}

proc staticEcho*(val: CToken) =
  static:
    echo "staticEcho: ", val.string

test "test c macro wrapper":
  const varname = CVarName(my, Var)
  staticEcho(varname)
  check varname.string == "C_VAR_NAME(my, Var)"
  echo "varname: ", varname.string

import macros

test "test c macro call":
  var myVarC {.importc: "myVar".}: cint
  myVarC = 42
  const myvar = CVarName(my, Var)
  var someVar: cint
  expandMacros:
    someVar = CVar(myvar)
    echo "someVar: ", $someVar
  check someVar == 42

