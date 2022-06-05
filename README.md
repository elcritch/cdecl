
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
