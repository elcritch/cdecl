# Package

version       = "0.1.1"
author        = "Jaremy Creechley"
description   = "Nim helper for using C Macros"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.6.6"
requires "macroutils >= 1.2.0"
requires "mddoc >= 0.0.4"

task gendocs, "generate docs":
  exec("nimble doc src/cdecl.nim ")
task readme, "generate readme":
  exec("mddoc src/cdecl.nim ")

task updatedocs, "update release":
  gendocsTask()
  readmeTask()
