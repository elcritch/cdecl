import macros

type
  CRawStr* = distinct string ##\
    ## Represents a raw string that gets interpolated into generated C ouput
  CLabel* = CRawStr ##\
    ## used to represent a C macro "label", an alias for CRawStr
  CRawToken* = distinct static[CRawStr] ##\
    ## Represents a C token derived from a Nim expression
  CToken* = distinct static[CRawStr] ##\
    ## Represents a C token derived from a Nim expression

macro symbolName*(x: untyped): string =
  ## Get a string representation of a Nim symbol
  x.toStrLit

template symbolVal*(x: CRawStr): string =
  ## Turns a CRawStr into a normal string
  x.string

template symbolVal*(x: string): string =
  ## Turns a CRawStr into a normal string
  x
