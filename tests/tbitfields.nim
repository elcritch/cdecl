import unittest
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
  ## define RegConfig integer with accessors for `bitfields`
  clockEnable: bool[7..7]
  daisyIn: bool[6..6]
  speed: Speed[3..4] # range are re-ordered using min/max
  gain: GainValues[2..0]

bitfields RegChannel(uint16):
  ## define RegConfig integer with accessors for `bitfields`
  speed: int8[4..9] # range are re-ordered using min/max
  gain: int8[2..0]


suite "bit ops":

  setup:
    var regConfig: RegConfig
    var regChannel: RegChannel

  test "get speed":
    check regConfig.speed == k1

  test "set speed":
    regConfig.speed = k3
    check regConfig.speed == k3
    check regConfig.int == 0b0001_1000

  test "get gain":
    let gain = regConfig.gain
    check gain == X2

  test "set gain":
    regConfig.gain= X4
    let gain = regConfig.gain
    check gain == X4

  test "set all ":
    regConfig.clockEnable = true
    regConfig.speed = k3
    regConfig.gain= X6

    echo fmt"{$regConfig=}"
    check regConfig.clockEnable == true
    check regConfig.gain == X6
    check regConfig.speed == k3
    check regConfig.int == 0b1001_1010

  test "set reg channel":
    regChannel.gain= 5
    check regChannel.gain == 5
    regChannel.speed= 31
    check regChannel.speed == 31
    echo fmt"{$regChannel=}"
