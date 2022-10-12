import unittest
import cdecl/crc32

test "basic test":
  let c = crc32("The quick brown fox jumps over the lazy dog")
  echo $c
  check Crc32(0x414FA339) == c

test "combine hack":
  let a = crc32("The quick brown fox jumps over the lazy dog")
  let b = crc32(". The end.")
  echo "a: ", $a
  echo "b: ", $b
  echo $(a !& b)
