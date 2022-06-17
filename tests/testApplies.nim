import unittest
import cdecl/applies
import macros

suite "unpack object args":
  type AddObj = object
    a*: int
    b*: int
  
  test "test unpackObjectArgs":
    proc add(a, b: int): int =
      result = a + b
    
    let args = AddObj(a: 1, b: 2)
    let res = unpackObjectArgs(add, args)
    check res == 3

  test "test unpackObjectArgs with extra":
    proc addDouble(a, b: int, double: bool): int =
      result = a + b
      if double: result *= 2

    let args = AddObj(a: 1, b: 2)
    let res = unpackObjectArgs(addDouble, args, true)
    check res == 6

suite "unpack labels":
  setup:
    var wasRun = false
    proc foo(name: string = "buzz", a, b: int) =
      echo name, ":", " a: ", $a, " b: ", $b
      wasRun = true
    
    template fooBar(blk: varargs[untyped]) =
      unpackLabelsAsArgs(foo, blk)

  teardown:
    check wasRun

  test "test basic":
    fooBar:
      name: "buzz"
      a: 11
      b: 22
    
  test "test with pos arg":
    fooBar("buzz"):
      a: 11
      b: 22
    
  test "test with pos args":
    fooBar("buzz", 11):
      b: 22
    
  test "test with named args":
    fooBar("buzz", a = 11):
      b: 22
    
  test "test with block label":
    fooBar:
      name: "buzz"
      a: 11
      b:
        echo "b arg"
        22

    check wasRun

