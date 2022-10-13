import std/typetraits
import std/hashes
import std/tables
import std/macrocache
import std/strutils
import std/macros

import crc32

## =============
## Atoms for Nim
## =============
## 
## Atom type which converts a string at compile time
## into an int from CRC32. The atom's string is stored
## in a global table that is setup on program initialization. 
## 
## Atoms can be declared in a few ways:
## 
## - String macro `atom"my new atom"`
## - The `@:"hello"` macro, an alias for `atom"hello"`
## - The `@@"hello"` lookup macro, requires the atom to be declared previously
## 


const atomCache = CacheTable"atomCache"

proc contains(ct: CacheTable, nm: string): bool =
  for k, v in ct:
    if nm == k:
      return true

type
  Atom* = distinct uint32 ##\
    ## Atom for representing the CRC32 of a string as an uint32

var atomNames: Table[Atom, string]

proc `==`*(a, b: Atom): bool {.borrow.}
proc hash*(a: Atom): Hash = a.Hash

proc `$`*(a: Atom): string =
  "@:\"" & atomNames[a] & "\""
proc `repr`*(a: Atom): string =
  "@:" & "" & $a.int & "\"" & atomNames[a] & "\""

proc genCrc32(name: string): Crc32 =
  result = crc32(name.nimIdentNormalize())
  while result.int == 0:
    result = crc32(result.uint32)

proc new*(a: typedesc[Atom], name: string): Atom =
  ## initialize a new atom at runtime from the given string
  result = Atom(genCrc32(name))
  atomNames[result] = name

proc new*(a: typedesc[Atom], raw: int, desc = ""): Atom =
  ## initialize a new atom at runtime using a custom int
  result = Atom(raw)
  atomNames[result] =
    if desc.len() == 0:
      "`" & $raw & "`"
    else: desc

proc declAtom*(nm: string, checkDeclared=false): NimNode =
  ## helper for macros to declare new atoms
  let idVar = genSym(nskVar, "atomVar")
  let idStr = newStrLitNode(nm)
  let id = Atom(genCrc32(nm))
  if nm notin atomCache:
    result = quote do:
      block:
        var `idVar` {.global.} = Atom.new(`idStr`)
        `idVar`
    atomCache[nm] = result
  else:
    result = quote do:
      Atom(`id`)

var atomNone = Atom.new(0, "none")

proc none*(a: typedesc[Atom]): Atom =
  result = Atom(0)

macro atom*(name: typed): Atom =
  ## macro for defining new atoms
  result = declAtom(name.strVal)

macro `@:`*(name: untyped): Atom =
  ## macro for defining new atoms
  result = declAtom(name.strVal)

macro `@@`*(name: untyped): Atom =
  ## macro for looking up existing atoms
  ## 
  ## produces a compile time error if the atom hasn't 
  ## been declared already
  let nm = name.strVal
  if nm notin atomCache:
    error("not declared: " & name.repr, name)
  result = declAtom(name.strVal)

