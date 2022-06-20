import unittest
import strutils, strformat

import cdecl/cdeclapi
import cdecl/cdecls


{.emit: """/*TYPESECTION*/
/* define example C Macro for testing */
int myVar = 0;

#define C_VAR_NAME(AA, BB) (AA ## BB)
""".}

proc CVar*(prefix: CToken, name: CToken): CRawStr {.
  cmacrowrapper: "C_VAR".}

proc staticEcho*(val: CToken) =
  static:
    echo "staticEcho: ", val.string

test "test c macro wrapper":
  const x = CVar(my, Var)
  staticEcho(x)
  check x.string == "C_VAR(my, Var)"
  echo "x: ", x.string


