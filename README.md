
# API: cdecl

```nim
import cdecl

proc CMacroDeclare*(name: CToken, size: static[int], otherName: CToken): array[size, int] {.
  cdeclmacro: "C_MACRO_VARIABLE_DECLARER".}

CMacroDeclare(myVar, 128, someExternalCVariable) # creates myVar
```

## **macro** cdeclmacro

<p>Macro helper for wrapping a C macro that declares a new C variable.</p>
<p>It handles emitting the appropriate C code for calling the macro. Additionally it defines a new Nim variable using importc which imports the declared variable.   </p>

```nim
macro cdeclmacro(name: string; def: untyped)
```

## Example

Basic Usage:

```nim
import macros
import cdecl 

{.emit: """/*TYPESECTION*/
    /* define example C Macro for testing */
    #define C_DEFINE_VAR(NM, SZ) int NM[SZ]
    #define C_DEFINE_VAR_DUO(NM, SZ, NM2) int NM[SZ]
    """.}

# Wrap a C Macro that stakes an C macro label and a size to create a new array variable
proc CDefineVar*(name: CToken, size: static[int]): array[size, int] {.
  cdeclmacro: "C_DEFINE_VAR".}

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

## TODO

I plan to add more macros as needed and am welcome to PRs. I'm also interested in issues for use cases that fall withing the general theme of invoking C/C++ macros from Nim.