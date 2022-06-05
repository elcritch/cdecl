
# API: cdecl

```nim
import cdecl
```

## **macro** cdeclmacro

<p>Macro helper for wrapping a C macro that declares a new C variable.</p>
<p>It handles emitting the appropriate C code for calling the macro. Additionally it defines a new Nim variable using importc which imports the declared variable.   </p>

```nim
macro cdeclmacro(name: string; def: untyped)
```

## Example

Example:

```nim
import macros
import cdecl 

{.emit: """/*TYPESECTION*/
    /* define example C Macro for testing */
    #define C_DEFINE_VAR(NM, SZ) int NM[SZ]
    #define C_DEFINE_VAR_DUO(NM, SZ, NM2) int NM[SZ]
    """.}

proc CDefineVar*(name: CToken, size: static[int]): array[size, int] {.
  cdeclmacro: "C_DEFINE_VAR".}

static:
  discard """`CDefineVar` generates code that looks like:"""
  discard quote do:
    template CDefineVar*(name: untyped, size: static[int]) =
      var name* {.inject, importc, nodecl.}: array[size, int]
    {.emit: "/*VARSECTION*/\nC_DEFINE_VAR($1, $2); " % [ symbolName(name), $size, ] .}
```