
import cdecl/cdecls
import cdecl/cdeclapi
import cdecl/applies
import cdecl/bitfields

export cdecls, cdeclapi, applies, bitfields

## ## C.D.E.C.L.: Commonly Desired Edge Case Library
## 
## See full docs at `docs <https://elcritch.github.io/cdecl/>`_ or source on github at `elcritch/cdecl <https://github.com/elcritch/cdecl>`_.
## 
## Small library for macros to handle various edge cases for Nim syntax. These are mostly edge case syntax handlers or tricky C Macro interfacings. The goal is to implement them as generically and well unit tested as possible.
## 
## Current macros includes: 
## 
## - `cdecls <https://elcritch.github.io/cdecl/cdecl/cdecls.html>`_: Macros to help using C macros that declare variables
##   - `cdeclmacro`
## - `applies <https://elcritch.github.io/cdecl/cdecl/applies.html>`_: Macros that unpack arguments from various forms and calls functions
##   - `unpackObjectArgs`: macro to *splat* an object to position arguments
##   - `unpackObjectArgFields`: macro to *splat* an object to keyword arguments
##   - `unpackLabelsAsArgs`: turn *labels* to named arguments
## - `bitfields <https://elcritch.github.io/cdecl/cdecl/bitfields.html>`_: Macros for making bitfield style accessor 
##   - `bitfields`: create *bitfield* accessors for hardware registers using any int type
## 
## You can see various usages in the [tests ](https://github.com/elcritch/cdecl/tree/main/tests) folder. 
## 
## ## Macros
## 
## ### `unpackObjectArgs`
## 
## Helper to apply all fields of an object as named paramters. 
## 
## ```nim
## type AddObj = object
##   a*: int
##   b*: int
## 
## proc add(a, b: int): int =
##     result = a + b
##   
## let args = AddObj(a: 1, b: 2)
## let res = unpackObjectArgs(add, args)
## assert res == 3
## ```
## 
## ### `unpackLabelsAsArgs`
## 
## Helper to transform `labels` as named arguments to a function. *Labels* are regular Nim syntax for calling procs but are transformed to parameter names:
## 
## ```nim
## proc foo(name: string = "buzz", a, b: int) =
##   echo name, ":", " a: ", $a, " b: ", $b
## 
## template Foo(blk: varargs[untyped]) =
##   ## create a new template to act YAML like API
##   unpackLabelsAsArgs(foo, blk)
## 
## Foo:
##   name: "buzz"
##   a: 11
##   b: 22
## 
## ```
## 
## Will call `foo(name="buzz",a=11,b=22)` and print:
## 
## ```sh
## buzz: a: 11 b: 22
## ```
## 
## ### `cdeclmacro`
## 
## Macro helper for wrapping a C macro that declares a new C variable.
## 
## It handles emitting the appropriate C code for calling the macro. Additionally it defines a new Nim variable using importc which imports the declared variable. 
## 
## #### Basic Example
## 
## ```nim
## import cdecl/cdecls
## import cdecl/cdeclapi
## export cdeclapi # this is needed clients to use the declared apis
## 
## proc CDefineVar*(name: CToken, size: static[int]) {.
##   cdeclmacro: "C_MACRO_VARIABLE_DECLARER", cdeclsVar(name -> array[size, int32]).}
## 
## CMacroDeclare(myVar, 128, someExternalCVariable) # creates myVar
## ```
## 
## ```nim
## macro cdeclmacro(name: string; def: untyped)
## ```
##  
## #### CRawStr Example 
## 
## ```nim
## import macros
## import cdecl 
## 
## proc CDefineVarStackRaw*(name: CToken, size: static[int], otherRaw: CRawStr): array[size, int32] {.
##   cdeclmacro: "C_DEFINE_VAR_ADDITION".}
## 
## # Pass a raw string to the C macro:
## proc runCDefineVarStackRaw() =
##   CDefineVarStackRaw(myVarStackRaw, 5, CRawStr("40+2"))
##   assert myVarStackRaw[0] == 42
## ```
## 