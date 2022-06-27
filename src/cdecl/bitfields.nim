import macros, tables, strformat, strutils, sequtils
import bitops
export bitops

proc setBitsSlice*[T: SomeInteger, V](b: var T, slice: Slice[int], x: V) = 
  b.clearMask(slice)
  b.setMask(T(x) shl slice.a)

macro bitfields*(name, def: untyped) =
  echo fmt"{name.treerepr=}"
  let
    typeName = name[0]
    strTypeName = newStrLitNode typeName.repr
    intTyp = name[^1]
    reclist = def

  echo fmt"{strTypeName.treeRepr=}"
  var stmts = newStmtList()
  for idx, identdef in reclist:
    echo fmt"{identdef.treeRepr=}"
    if identdef.kind == nnkCommentStmt:
      stmts.add identdef
    else:
      identdef.expectKind nnkCall

      let
        fieldName = identdef[0]
        fieldNameEq = ident(fieldName.repr & "=")
        bexpr = identdef[1][0]
        fieldType = bexpr[0]
      bexpr.expectKind nnkBracketExpr
      let
        fieldRngA = bexpr[1][1].intVal
        fieldRngB = bexpr[1][2].intVal
        rngA = min(fieldRngA, fieldRngB)
        rngB = max(fieldRngA, fieldRngB)

      stmts.add quote do:
        proc `fieldName`*(reg: `typeName`): `fieldType` =
          let val = bitsliced(`intTyp`(reg), `rngA`..`rngB`)
          result = cast[`fieldType`](val)
        proc `fieldNameEq`*(reg: var `typeName`, x: `fieldType`) =
          reg.`intTyp`.setBitsSlice(`rngA`..`rngB`, x)

  result = newStmtList()
  let dollarName = ident "$"
  result.add quote do:
    type
      `typeName`* = distinct `intTyp`
    
    proc `dollarName`*(reg: `typeName`): string =
      result = `strTypeName` & "(" &
                toBin(int64(reg), 8*sizeof(`typeName`)) &
                ")"

  result.add stmts
  
  echo fmt"{result.repr=}"
  # echo fmt"{result.treerepr=}"
