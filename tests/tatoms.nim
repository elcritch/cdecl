import cdecl/atoms
import macros

import unittest

suite "tests":
  test "atom test":
    expandMacros:
      let x: Atom = atom"new long name"
      let y: Atom = @:"new Long Name"
      let z: Atom = @@"new Long Name"
    echo "x: ", x
    echo "y: ", y
    echo "z: ", z
    echo "repr x: ", repr x
    echo "repr y: ", repr y
    echo "repr z: ", repr z
    check x == atom"new long name"
    check x == y
    check x == z

  test "atom more tests":
    let x: Atom = atom"newLongName"
    let y: Atom = @:newLongName
    let z: Atom = @:newLongName
    echo "x: ", repr x
    echo "y: ", repr y
    echo "z: ", repr z
    check x == atom"newLongName"
    check x == y
    check x == z

  test "atom more tests":
    let notCompiles = compiles:
      let y: Atom = @@"undefined"
    check notCompiles == false
    check Atom(0) == Atom.empty()