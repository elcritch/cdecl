import unittest
import cdecl/applies

suite "rpc methods":
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

