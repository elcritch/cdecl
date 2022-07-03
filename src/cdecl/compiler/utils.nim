
import macros

macro forwardEnums*(name, prefix: string, en: typed) =
  ## macro to help 'forward' an enum
  ## used to rename the enums in ast.nim 
  let eid = ident name.strVal
  let oeid = ident en.strVal
  let pre = prefix.strVal
  let edecl = getImpl(en)[2]

  var allFields: seq[string]
  for fld in edecl:
    if fld.kind == nnkEmpty: continue
    allFields.add fld.strVal

  result = quote do:
    type `eid`* = enum
      a
    converter toEnum*(x: `eid`): `oeid` =
      result = `oeid`(ord(x))
    converter toEnum*(x: `oeid`): `eid` =
      result = `eid`(ord(x))

  let newEnumTy = newTree(nnkEnumTy, newEmptyNode())
  for nm in allFields:
    newEnumTy.add ident pre & nm

  result[0][0][^1] = newEnumTy

when isMainModule:

  type
    TNodeKind* = enum
      nkNone,
      nkEmpty

  var nn: TNodeKind
  forwardEnums("NimNodeKind", "n", TNodeKind)
