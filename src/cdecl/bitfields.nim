## =========
## BitFields
## =========
## 
## Macro for generating *bitfield* style accessors. The accessors
## are portable and generally compile down to one or two `and` or `or`
## bit operations. 
## 
## This is often preferable to C-style bitfields
## which Nim does support. C-style bitfields are 
## compiler and architecture dependent and prone
## to breaking on field alignement, endiannes, 
## and other issues. See https://lwn.net/Articles/478657/
## 


import macros, tables, strformat, strutils, sequtils
import bitops
export bitops

proc setBitsSlice*[T: SomeInteger, V](b: var T, slice: Slice[int], x: V) = 
  b.clearMask(slice)
  b.setMask(masked(T(x) shl slice.a, slice))

macro bitfields*(name, def: untyped) =
  ## Create a new distinct integer type with accessors
  ## for `bitfields` that set and get bits for each
  ## field. These are more stable and portable than C-style bitfields. 
  ## 
  ## Note: the ranges are *inclusive* and 0-based. 
  ## 
  ## The basic syntax for a `bitfield` declarations is:
  ##     `fieldname: uint8[0..5]`
  ## or equivalently:
  ##     `fieldname: uint8[5..0]`
  ## 
  ## - `fieldName` is the name of the accessors and produces both
  ##     a getter (`fieldName`) and setter (`fieldName=`)
  ## - the range `4..5` is the target bit indexes. The ranges are 
  ##     inclusive meaning `6 ... 6` is 1 bit. Ranges are sorted so
  ##     you can also use `5 .. 4` to match hardware documentation. 
  ## - The type `uint8` is the type that the bits are converted to/from.
  ## 
  ## Signed types like `int8` are supported and do signed shifts to
  ## properly extend the sign. For example:
  ##     `speed: int8[7..4]`
  ## 
  ## The accessors generated are very simple and what you
  ## would generally produce by hand.
  ## 
  ## Note: accessors currrently ignore overflows / underfloags. They
  ##       use raw casts, but are masked to not overwrite adjacent fields.
  ## 
  ## For example: 
  ## 
  ##   ```nim
  ##   bitfields RegConfig(uint16):
  ##     speed: int8[4..2]
  ##   ```
  ## 
  ## Generates code similar too:
  ##   ```nim
  ##   type
  ##     RegChannel = distinct uint16
  ## 
  ##   proc speed*(reg: RegChannel): uint8 =
  ##       result = uint8(bitsliced(uint16(reg), 4 .. 9))
  ##   proc speed=*(reg: var RegChannel; x: uint8) =
  ##       setBitsSlice(uint16(reg), 4 .. 9, x)
  ##   ```
  ##
  runnableExamples:
    bitfields RegConfig(uint8):
      ## define RegConfig integer with accessors for `bitfields`
      clockEnable: bool[7..7]
      daisyIn: bool[6..6]
      speed: int8[5..1]

    ## Now use it to make a new register field
    var regConfig: RegConfig

    regConfig.clockEnable= true
    regConfig.speed= -10

    echo "regConfig.speed ", regConfig.speed 
    assert regConfig.clockEnable == true
    assert regConfig.speed == -10
    ## the type of `RegConfig` is just a `distinct uint8`
    import typetraits
    assert distinctBase(typeof(regConfig)) is uint8

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
          when `fieldType` is SomeSignedInt:
            const cnt = 8*sizeof(`fieldType`) - (`rngB` - `rngA` + 1)
            result = (result shl cnt) shr cnt
        
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
    
    proc `eqName`*(a: `typeName`, b: `typeName`): bool = `eqName`(`intTyp`(a), `intTyp`(b))
    proc `dollarName`*(reg: `typeName`): string =
      result =  `strNamePrefix ` & 
                  toBin(int64(reg), 8*sizeof(`typeName`)) &
                ")" 

  result.add stmts
  # echo fmt"{result.treerepr=}"
