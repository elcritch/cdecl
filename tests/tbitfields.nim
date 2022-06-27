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
  speed: Speed[3..4] # range are re-ordered using min/max
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

  test "get gain":
    let gain = registerConfig.gain
    echo fmt"{$registerConfig=} {gain=}"
    unittest.check gain == X2

  test "set gain":
    registerConfig.gain= X4
    echo fmt"{$registerConfig=}"
    let gain = registerConfig.gain
    echo fmt"{gain=}"
    unittest.check gain == X4

  test "set all ":
    registerConfig.clockEnable = true
    registerConfig.speed = k3
    registerConfig.gain= X6

    echo fmt"{$registerConfig=}"
    unittest.check registerConfig.clockEnable == true
    unittest.check registerConfig.gain == X6
    unittest.check registerConfig.speed == k3
    unittest.check registerConfig.int == 0b1001_1010
