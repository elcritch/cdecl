
# CDecl: Easy wrapper generation for C/C++ declaration macros

```nim
import cdecl

proc CMacroDeclare*(name: CToken, size: static[int], otherName: CToken): array[size, int] {.
  cdeclmacro: "C_MACRO_VARIABLE_DECLARER", global.}

CMacroDeclare(myVar, 128, someExternalCVariable) # creates myVar
```

## **macro** cdeclmacro

<p>Macro helper for wrapping a C macro that declares a new C variable.</p>
<p>It handles emitting the appropriate C code for calling the macro. Additionally it defines a new Nim variable using importc which imports the declared variable.   </p>

```nim
macro cdeclmacro(name: string; def: untyped)
```

## cdeclmacro docs

Macro helper for wrapping a C macro that declares 
a new C variable.

It handles emitting the appropriate
C code for calling the macro. Additionally it defines
a new Nim variable using importc which imports the 
declared variable.   

The macro will pass any extra pragmas to the
variable. If the `global` pragma is passed in
the emitted C code will be put in the 
`/*VARSECTION*/` section. 


## Example

Basic Usage:

```nim
import macros
import cdecl 

{.emit: """/*TYPESECTION*/
    /* define example C Macro for testing */
    #define C_DEFINE_VAR(NM, SZ) int NM[SZ]
    """.}

# Wrap a C Macro that stakes an C macro label and a size to create a new array variable
proc CDefineVar*(name: CToken, size: static[int]): array[size, int] {.
  cdeclmacro: "C_DEFINE_VAR", global.}

# Then it's possible to invoke CDefineVar to call the C macro and
# generate a variable:
const cVarSz = 4
CDefineVar(myVar, cVarSz)

static:
  discard """`CDefineVar` generates code that looks like:"""
  discard quote do:
    template CDefineVar*(name: untyped, size: static[int]) =
      var name* {.inject, importc, nodecl.}: array[size, int]
    {.emit: "/*VARSECTION*/\nC_DEFINE_VAR($1, $2); " % [ symbolName(name), $size, ] .}
```

## Example CRawStr

```nim
import macros
import cdecl 

{.emit: """/*TYPESECTION*/
/* define example C Macro for testing */
#define C_DEFINE_VAR_ADDITION(NM, SZ, N2) \
  int32_t NM[SZ]; \
  NM[0] = N2
""".}

proc CDefineVarStackRaw*(name: CToken, size: static[int], otherRaw: CRawStr): array[size, int32] {.
  cdeclmacro: "C_DEFINE_VAR_ADDITION".}

# Pass a raw string to the C macro:
proc runCDefineVarStackRaw() =
  CDefineVarStackRaw(myVarStackRaw, 5, CRawStr("40+2"))
  assert myVarStackRaw[0] == 42
```

## TODO

I plan to add more macros as needed and am welcome to PRs. I'm also interested in issues for use cases that fall withing the general theme of invoking C/C++ macros from Nim.