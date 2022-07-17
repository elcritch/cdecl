import unittest
import strutils
import cdecl/applies
import options

{.push hint[XDeclaredButNotUsed](off).}

suite "unpack object as position args":
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

suite "unpack object fields as args":
  type DivObj = object
    a*: int
    b*: int
  
  test "test unpackObjectArgs":
    proc divide(b, a: int): int =
      result = b div a
    
    let args = DivObj(a: 1, b: 0)
    let res = unpackObjectArgFields(divide, args)
    check res == 0

  test "test unpackObjectArgs with defaults":
    proc divide(c = 10, b, a: int): int =
      result = b div (a + c)
    
    let args = DivObj(a: 1, b: 11)
    let res = unpackObjectArgFields(divide, args)
    check res == 1


suite "unpack labels":
  setup:
    var wasRun = false
    var totalValue = 0
    proc foo(name: string = "buzz", a, b: int) =
      # echo name, ":", " a: ", $a, " b: ", $b
      wasRun = true
      totalValue = a + b
    
    template fooBar(blk: varargs[untyped]) =
      unpackLabelsAsArgs(foo, blk)

    proc fooPrefix(`@name`: string = "buzz", a, b: int) =
      # echo name, ":", " a: ", $a, " b: ", $b
      wasRun = true
      totalValue = a + b
    
    template FooBarPrefix(blk: varargs[untyped]) =
      unpackLabelsAsArgs(fooPrefix, blk)

    proc fizz(name: proc (): string, a, b: int) =
      # echo name(), ":", " a: ", $a, " b: ", $b
      check name() == "fizzy"
      wasRun = true
      totalValue = a + b
    
    type
      NameProc = proc (): string {.nimcall.}
      NameClosure = proc (): string {.closure.}
    
    proc fizzy(name: NameClosure, id: NameProc, a, b: int) =
      # echo name(), ":", " a: ", $a, " b: ", $b
      check id() == "fuzzy"
      check name() == "fizzy"
      wasRun = true
      totalValue = a + b
    
    proc bazz(name: proc (i: int): string, a, b: int) =
      echo name(a), ":", " a: ", $a, " b: ", $b
      check name(a) == "bazz" & $a
      wasRun = true
      totalValue = a + b
    
    let defProc = proc (): string = "barrs"
    proc barrs(name = defProc, a = 11, b = 22) =
      echo name(), ":", " a: ", $a, " b: ", $b
      check name() == "barrs"
      wasRun = true
      totalValue = a + b
    
  teardown:
    check wasRun
    check totalValue == (11+22)

  test "test basic":
    ## basic fooBar call
    ## 
    fooBar:
      name: "buzz"
      a: 11
      b: 22
    
  test "test basic capitalized":
    ## basic fooBar call
    ## 
    template Foo(blk: varargs[untyped]) =
      unpackLabelsAsArgs(foo, blk)
    
    Foo:
      name: "buzz"
      a: 11
      b: 22
    
  test "test basic capitalized":
    ## basic fooBar call
    ## 
    FooBarPrefix:
      @name: "buzz"
      a: 11
      b: 22
    
  test "test basic capitalized":
    ## basic fooBar call
    ## 
    FooBarPrefix(@name = "buzz"):
      a: 11
      b: 22
    
  test "test transform basic":
    ## basic fooBar call
    ## 
    let removeWiths {.compileTime.} =
      proc (code: (string, NimNode)): Option[(string, NimNode)] = 
        if code[0].startsWith("with"):
          result = some (code[0][4..^1].toLower(), code[1])
        else:
          result = some code
    template Foo(blk: varargs[untyped]) =
      removeWiths.unpackLabelsAsArgsWithFn(foo, blk)
    
    Foo:
      name: "buzz"
      withA: 11
      withB: 22
    
  test "test transform basic":
    ## basic fooBar call
    ## 
    let removeWiths {.compileTime.} =
      proc (code: (string, NimNode)): Option[(string, NimNode)] = 
        if code[0].startsWith("with"):
          result = some (code[0][4..^1].toLower(), code[1])
        elif code[0].startsWith("@"):
          echo "option found"
        else:
          result = some code
    template Foo(blk: varargs[untyped]) =
      removeWiths.unpackLabelsAsArgsWithFn(foo, blk)
    
    Foo:
      @opt: "test"
      name: "buzz"
      withA: 11
      withB: 22
    
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
    
  test "test with named args unordered":
    fooBar("buzz", b = 22):
      a: 11
    
  test "test with block label":
    fooBar:
      name: "buzz"
      a:
        block:
          11
      b:
        echo "b arg"
        22

  test "test with anonymous proc":
    template Fizz(blk: varargs[untyped]) =
      unpackLabelsAsArgs(fizz, blk)
    
    Fizz(name = proc(): string = "fizzy"):
      a: 11
      b: 22

  test "test with def arguments a":
    template Barrs(blk: varargs[untyped]) =
      unpackLabelsAsArgs(barrs, blk)
    
    Barrs(name = proc(): string = "barrs"):
      b: 22

  test "test with def arguments b":
    template Barrs(blk: varargs[untyped]) =
      unpackLabelsAsArgs(barrs, blk)
    
    Barrs(name = proc(): string = "barrs"):
      a: 11

  test "test with strict":
    template Barrs(blk: varargs[untyped]) =
      unpackLabelsAsArgs(barrs, blk)
    
    const works = 
      compiles(block:
        let nm = proc(): string = "barrs"
        Barrs(name = nm, a: 11):
          b: 22
      )
    check works == false
    wasRun = true
    totalValue = 11 + 22

  test "test with non-strict":
    template Barrs(blk: varargs[untyped]) =
      unpackLabelsAsArgsNonStrict(barrs, blk)
    
    let nm = proc(): string = "barrs"
    Barrs(name = nm, a: 11):
      b: 22

  test "test with def arguments name ":
    template Barrs(blk: varargs[untyped]) =
      unpackLabelsAsArgs(barrs, blk)
    
    Barrs:
      a: 11
      b: 22

  test "test with special case empty proc":
    template fizzCall(blk: varargs[untyped]) =
      unpackLabelsAsArgs(fizz, blk)
    
    fizzCall:
      name:
        # echo "running func..."
        "fizzy"
      a: 11
      b: 22

  test "test with special case named empty proc":
    template fizzyCall(blk: varargs[untyped]) =
      unpackLabelsAsArgs(fizzy, blk)
    
    fizzyCall:
      id:
        echo "running func..."
        "fuzzy"
      name:
        echo "running func..."
        "fizzy"
      a: 11
      b: 22

  test "test with anonymous proc var":
    template Fizz(blk: varargs[untyped]) =
      unpackLabelsAsArgs(fizz, blk)
    
    let fn = proc (): string = "fizzy"
    Fizz:
      name: fn()
      a: 11
      b: 22

  test "test with special case empty proc":
    template fizzCall(blk: varargs[untyped]) =
      unpackLabelsAsArgs(fizz, blk)
    fizzCall:
      name do () -> string:
        # echo "running func..."
        "fizzy"
      a: 11
      b: 22

  test "test with anonymous proc with args":
    template bazzCall(blk: varargs[untyped]) =
      unpackLabelsAsArgs(bazz, blk)
    const works =
      compiles(block:
        bazzCall:
          name:
            # echo "running func..."
            "fizzy"
          a: 11
          b: 22)
    check not works
    wasRun = true
    totalValue = 11 + 22

  test "test with special case non-empty proc":
    template bazzCall(blk: varargs[untyped]) =
      unpackLabelsAsArgs(bazz, blk)
    bazzCall:
      name do (i: int) -> string:
        # echo "running func..."
        "bazz" & $i
      a: 11
      b: 22

suite "unpack block args":
  setup:
    var wasRun = false
    var totalValue = 0
    proc foo(name: string = "buzz", a, b: int) =
      # echo name, ":", " a: ", $a, " b: ", $b
      wasRun = true
      totalValue = a + b
    
    template fooBar(blk: varargs[untyped]) =
      unpackBlockArgs(foo, blk)

    proc fooPrefix(`@name`: string = "buzz", a, b: int) =
      # echo name, ":", " a: ", $a, " b: ", $b
      wasRun = true
      totalValue = a + b
    
    template FooBarPrefix(blk: varargs[untyped]) =
      unpackBlockArgs(fooPrefix, blk)

    proc fizz(name: proc (): string, a, b: int) =
      # echo name(), ":", " a: ", $a, " b: ", $b
      check name() == "fizzy"
      wasRun = true
      totalValue = a + b
    
    type
      NameProc = proc (): string {.nimcall.}
      NameClosure = proc (): string {.closure.}
    
    proc fizzy(name: NameClosure, id: NameProc, a, b: int) =
      # echo name(), ":", " a: ", $a, " b: ", $b
      check id() == "fuzzy"
      check name() == "fizzy"
      wasRun = true
      totalValue = a + b
    
    proc bazz(name: proc(i: int): string, a, b: int) =
      # echo name(a), ":", " a: ", $a, " b: ", $b
      check name(a) == "bazz" & $a
      wasRun = true
      totalValue = a + b
    
    let defProc = proc (): string = "barrs"
    proc barrs(name = defProc, a = 11, b = 22) =
      # echo name(), ":", " a: ", $a, " b: ", $b
      check name() == "barrs"
      wasRun = true
      totalValue = a + b
    
  teardown:
    check wasRun
    check totalValue == (11+22)

  test "test basic":
    ## basic fooBar call
    ## 
    fooBar:
      name = "buzz"
      a = 11
      b = 22
    
  test "test basic capitalized":
    ## basic fooBar call
    ## 
    template Foo(blk: varargs[untyped]) =
      unpackBlockArgs(foo, blk)
    
    Foo:
      name = "buzz"
      a = 11
      b = 22
    
  test "test basic capitalized":
    ## basic fooBar call
    ## 
    FooBarPrefix:
      @name = "buzz"
      a = 11
      b = 22
  
  test "test basic capitalized":
    ## basic fooBar call
    ## 
    FooBarPrefix(@name = "buzz"):
      a = 11
      b = 22
    
  test "test transform basic":
    ## basic fooBar call
    ## 
    let removeWiths {.compileTime.} =
      proc (code: (string, NimNode)): Option[(string, NimNode)] = 
        if code[0].startsWith("with"):
          result = some (code[0][4..^1].toLower(), code[1])
        else:
          result = some code
    template Foo(blk: varargs[untyped]) =
      removeWiths.unpackBlockArgsWithFn(foo, blk)
    
    Foo:
      name = "buzz"
      withA = 11
      withB = 22
    
  test "test transform basic":
    ## basic fooBar call
    ## 
    let removeWiths {.compileTime.} =
      proc (code: (string, NimNode)): Option[(string, NimNode)] =
        if code[0].startsWith("with"):
          result = some (code[0][4..^1].toLower(), code[1])
        elif code[0].startsWith("@"):
          echo "found magic"
        else:
          result = some code
    template FooBar(blk: varargs[untyped]) =
      removeWiths.unpackBlockArgsWithFn(foo, blk)
    
    FooBar:
      @opt = true
      withA = 11
      withB = 22

  test "test with pos arg":
    fooBar("buzz"):
      a = 11
      b = 22
    
  test "test with pos args":
    fooBar("buzz", 11):
      b = 22
    
  test "test with named args":
    fooBar("buzz", a = 11):
      b = 22
    
  test "test with named args unordered":
    fooBar("buzz", b = 22):
      a = 11
    
  test "test with block label":
    fooBar:
      name =
        "buzz"
      a =
        11
      b =
        block:
          echo "b arg"
          22

  test "test with anonymous proc":
    template Fizz(blk: varargs[untyped]) =
      unpackBlockArgs(fizz, blk)
    
    Fizz(name = proc(): string = "fizzy"):
      a = 11
      b = 22

  test "test with def arguments a":
    template Barrs(blk: varargs[untyped]) =
      unpackBlockArgs(barrs, blk)
    
    Barrs(name = proc(): string = "barrs"):
      b = 22

  test "test with def arguments b":
    template Barrs(blk: varargs[untyped]) =
      unpackBlockArgs(barrs, blk)
    
    Barrs(name = proc(): string = "barrs"):
      a = 11

  test "test with def arguments name ":
    template Barrs(blk: varargs[untyped]) =
      unpackBlockArgs(barrs, blk)
    
    Barrs:
      a = 11
      b = 22

  test "test with special case empty proc":
    template fizzCall(blk: varargs[untyped]) =
      unpackBlockArgs(fizz, blk)
    
    fizzCall:
      name =
        # echo "running func..."
        "fizzy"
      a = 11
      b = 22

  test "test with special case named empty proc":
    template fizzyCall(blk: varargs[untyped]) =
      unpackBlockArgs(fizzy, blk)
    
    fizzyCall:
      id = block:
        # echo "running func..."
        "fuzzy"
      name = block:
        # echo "running func..."
        "fizzy"
      a = 11
      b = 22

  test "test with anonymous proc var":
    template Fizz(blk: varargs[untyped]) =
      unpackBlockArgs(fizz, blk)
    let fn = proc (): string = "fizzy"
    Fizz:
      name = fn()
      a = 11
      b = 22

  test "test with special case empty proc":
    template fizzCall(blk: varargs[untyped]) =
      unpackBlockArgs(fizz, blk)
    fizzCall:
      name = proc(): string =
        # echo "running func..."
        "fizzy"
      a = 11
      b = 22

  test "test with proc name alt form":
    template fizzCall(blk: varargs[untyped]) =
      unpackBlockArgs(fizz, blk)
    fizzCall:
      proc name(): string =
        # echo "running func..."
        "fizzy"
      a = 11
      b = 22
  
  test "test with anonymous proc with args":
    template bazzCall(blk: varargs[untyped]) =
      unpackBlockArgs(bazz, blk)
    const works =
      compiles(block:
        bazzCall:
          name:
            # echo "running func..."
            "fizzy"
          a: 11
          b: 22)
    check not works
    wasRun = true
    totalValue = 11 + 22

  test "test with special case non-empty proc":
    template bazzCall(blk: varargs[untyped]) =
      unpackBlockArgs(bazz, blk)
    bazzCall:
      name = proc(i: int): string =
        # echo "running func..."
        "bazz" & $i
      a = 11
      b = 22

  test "test with proc name alt non-empty proc":
    template bazzCall(blk: varargs[untyped]) =
      unpackBlockArgs(bazz, blk)
    bazzCall:
      proc name(i: int): string =
        # echo "running func..."
        "bazz" & $i
      a = 11
      b = 22
    