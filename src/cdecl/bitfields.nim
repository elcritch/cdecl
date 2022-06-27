import macros, tables, strformat, strutils, sequtils
import bitops
export bitops

proc setBitsSlice*[T: SomeInteger, V](b: var T, slice: Slice[int], x: V) = 
  b.clearMask(slice)
  b.setMask(masked(T(x) shl slice.a, slice))

macro bitfields*(name, def: untyped) =
  ## Create a new distinct integer type with accessors
  ## for `bitfields` that set and get bits for each
  ## field.
  ## 
  ## The basic syntax is `fieldname: Type[4..5]`
  ## where the range `4..5` is the bits for the value. 
  ## The range is inclusive like normal Slices. 
  ## 
  runnableExamples:
    bitfields RegConfig(uint8):
      ## define RegConfig integer with accessors for `bitfields`
      clockEnable: bool[7..7]
      daisyIn: bool[6..6]
      speed: int8[4..2]

  let
    typeName = name[0]
    strTypeName = newStrLitNode typeName.repr
    intTyp = name[^1]
    reclist = def

  var stmts = newStmtList()
  var fields = newSeq[NimNode]()
  for idx, identdef in reclist:
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

      fields.add fieldName
      stmts.add quote do:
        proc `fieldName`*(reg: `typeName`): `fieldType` =
          result = `fieldType`(bitsliced(`intTyp`(reg), `rngA`..`rngB`))
          when `fieldType` is SomeInteger:
            let cnt = 8*sizeof(`fieldType`) - (`rngB` - `rngA` + 1)
            echo "val0:", result
            result = result shl cnt
            echo "val1:", result
            result = result shr cnt
            echo "val2:", result
          # result = cast[`fieldType`](val)
        proc `fieldNameEq`*(reg: var `typeName`, x: `fieldType`) =
          reg.`intTyp`.setBitsSlice(`rngA`..`rngB`, x)

  result = newStmtList()
  let
    dollarName = ident "$"
    eqName = ident "=="
    strNamePrefix = strTypeName.strVal & "(0b"
  result.add quote do:
    type
      `typeName`* = distinct `intTyp`
    
    proc `eqName`*(a: `typeName`, b: `typeName`): bool {.borrow.}
    proc `dollarName`*(reg: `typeName`): string =
      result =  `strNamePrefix ` & 
                  toBin(int64(reg), 8*sizeof(`typeName`)) &
                ")" 

  result.add stmts
  # echo fmt"{result.treerepr=}"
