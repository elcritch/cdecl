# This is just an example to get you started. A typical library package
# exports the main API in this file. Note that you cannot rename this file
# but you can remove it if you wish.

import macros
export macros

macro symbolName*(x: typed): string =
  x.toStrLit
