import strutils

## =====
## CRC32 
## =====
## 
## Basic CRC32 implementation
## 

type Crc32* = distinct uint32

proc `==`*(a, b: Crc32): bool {.borrow.}
proc `$`*(a: Crc32): string = "0x" & a.int32.toHex(8)

proc createCrcTable(): array[0..255, uint32] =
  for i in 0'u32..255:
    var rem = i
    for j in 0..7:
      if (rem and 1) > 0'u32: rem = (rem shr 1) xor 0xEDB88320'u32
      else: rem = rem shr 1
    result[i] = rem

# Table created at compile time
const crc32table = createCrcTable()

proc updateCrc32(crc: var uint32, c: char) =
  crc = (crc shr 8) xor crc32table[(crc and 0xff) xor ord(c).uint32]

proc crc32*(val: string): Crc32 =
  ## compute the crc32 for a string
  var res = uint32.high
  for ch in val:
    updateCrc32(res, ch)
  result = Crc32(not res)

proc crc32*(val: uint): Crc32 =
  ## compute the crc32 for a string
  var res = uint32.high
  for i in 0..3:
    let ch = cast[char](val shr (8*i))
    updateCrc32(res, ch)
  result = Crc32(not res)

proc crc32*(vals: varargs[string]): Crc32 =
  ## compute the crc32 for multiple strings
  ## works as if the strings were one long string
  var res = uint32.high
  for val in vals: 
    for ch in val:
      updateCrc32(res, ch)
  result = Crc32(not res)

proc `!&`*(a, b: Crc32): Crc32 =
  ## hash two CRC32's together
  result = Crc32(a.uint32 xor b.uint32)

