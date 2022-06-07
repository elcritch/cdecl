import macros

type
  CToken* = static[string] ##\
    ## Represents a C token that can be anything passed to a C macro 
  CRawStr* = distinct static[string] ##\
    ## Represents a raw string that gets interpolated into generated C ouput

macro symbolName*(x: untyped): string =
  ## Get a string representation of a Nim symbol
  x.toStrLit

template symbolVal*(x: CRawStr): string =
  ## Turns a CRawStr into a normal string
  x.string
