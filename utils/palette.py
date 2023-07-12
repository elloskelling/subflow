#! /usr/bin/env python

import sys
import math

def char2RGB(color):
    red = (color >> 4) & 0x03
    green = (color >> 2) & 0x03
    blue = color & 0x03

    rgb = [float(red)/3., float(green)/3., float(blue)/3.]
    return rgb

def RGB2char(redf, greenf, bluef):
    red = round(redf*3.)
    green = round(greenf*3.)
    blue = round(bluef*3.)
    color = (red << 4) | (green << 2) | blue
    return color

if len(sys.argv) == 2:
    color = int(sys.argv[1])
    rgb = char2RGB(color)
    print("> ColorCode: %d" % color)
    print("<      Red: %f" % rgb[0])
    print("<    Green: %f" % rgb[1])
    print("<     Blue: %f" % rgb[2])

if len(sys.argv) == 4:
    rgb = [float(sys.argv[1]), float(sys.argv[2]), float(sys.argv[3])]
    color = RGB2char(rgb[0], rgb[1], rgb[2])
    rgb = char2RGB(color)
    print(">      Red: %f" % rgb[0])
    print(">    Green: %f" % rgb[1])
    print(">     Blue: %f" % rgb[2])
    print("< ColorCode: %d" % color)