import unittest except check
import strutils, strformat
import print

import cdecl/bitfields

type
  Enable* {.pure.} = enum
    Dis = 0b01
    En = 0b10
  Speed* {.pure.} = enum
    k1 = 0b00
    k2 = 0b10
    k3 = 0b11


bitfields RegConfig(uint8):
  ## define RegConfig integer with accessors:
  clockEnable: bool[6..6]
  daisyIn: bool[5..5]
  speed: Speed[3..1]

type
  GainValues* {.pure.} = enum
    X2 = 0b000
    X4 = 0b001
    X6 = 0b010
    X16 = 0b111
  
  RegChannel* = distinct uint8
  RegChannelX* = object
    id: range[1..12]
    chset: RegChannel


suite "bit ops":

  setup:
    var registerConfig: RegConfig

  test "get speed":
    let speed = registerConfig.speed
    echo fmt"{speed=}"
    unittest.check speed == k1

  test "set speed":
    registerConfig.speed = k2
    echo fmt"{registerConfig.repr=}"
    let speed = registerConfig.speed
    echo fmt"{speed=}"
    unittest.check speed == k2
