# Package

version       = "0.5.4"
author        = "Jaremy Creechley"
description   = "Nim helper for using C Macros"
license       = "MIT"
srcDir        = "src"

# Dependencies
requires "nim >= 1.6"
requires "macroutils >= 1.2.0"

task docs, "generate docs":
  exec("nim doc --project --outdir:docs  src/cdecl.nim")

