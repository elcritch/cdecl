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

proc CVarStrName*(prefix: CRawToken, name: CToken): CLabel {.cmacrowrapper: "C_VAR_NAME".}
proc CVarName*(prefix: CToken, name: CToken): CLabel {.cmacrowrapper: "C_VAR_NAME".}

proc CVar(varname: CLabel): cint {.cmacrowrapper: "C_VAR".}

proc staticEcho*(val: CToken) =
  static:
    echo "staticEcho: ", val.string

test "test c macro wrapper":
  const varname = CVarName(my, Var)
  staticEcho(varname)
  check varname.string == "C_VAR_NAME(my, Var)"
  echo "varname: ", varname.string

test "test c macro wrapper with mix CToken and CRawToken":
  ## mixing CRawToken (e.g. static[string) and CToken's
  ## to help show the differences
  const varname = CVarStrName("my", Var)
  staticEcho(varname)
  check varname.string == "C_VAR_NAME(my, Var)"
  echo "varname: ", varname.string

test "test c macro call":
  ## some C Variable
  var myVarC {.importc: "myVar".}: cint
  myVarC = 42
  ## we use a C Macro to create a C variable "label"
  const myvar = CVarName(my, Var)
  var someVar = CVar(myvar)
  echo "someVar: ", $someVar
  check someVar == 42

