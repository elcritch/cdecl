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

  GainValues* {.pure.} = enum
    X2 = 0b000
    X4 = 0b001
    X6 = 0b010
    X16 = 0b111

bitfields RegConfig(uint8):
  ## define RegConfig integer with accessors:
  clockEnable: bool[7..7]
  daisyIn: bool[6..6]
  speed: Speed[4..3]
  gain: GainValues[2..0]

type
  
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
    registerConfig.speed = k3
    echo fmt"pre: {$registerConfig=}"
    let speed = registerConfig.speed
    echo fmt"post: {$registerConfig=}"
    echo fmt"{speed=}"
    unittest.check speed == k3
    unittest.check registerConfig.int == 0b0001_1000

  test "get speed":
    let speed = registerConfig.speed
    echo fmt"{$registerConfig=} {speed=}"
    unittest.check speed == k1

  test "set speed":
    registerConfig.speed = k2
    echo fmt"{$registerConfig=}"
    let speed = registerConfig.speed
    echo fmt"{speed=}"
    unittest.check speed == k2
