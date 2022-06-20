import macros

type
  CRawStr* = distinct string ##\
    ## Represents a raw string that gets interpolated into generated C ouput
  CToken* = distinct static[CRawStr] ##\
    ## Represents a C token that can be anything passed to a C macro 

macro symbolName*(x: untyped): string =
  ## Get a string representation of a Nim symbol
  x.toStrLit

template symbolVal*(x: CRawStr): string =
  ## Turns a CRawStr into a normal string
  x.string
