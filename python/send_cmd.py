#! /usr/bin/env python

### subflow - a music visualizer
### Copyright (C) 2021-2023 Ello Skelling Productions

### This program is free software: you can redistribute it and/or modify
### it under the terms of the GNU Affero General Public License as published
### by the Free Software Foundation, either version 3 of the License, or
### (at your option) any later version.

### This program is distributed in the hope that it will be useful,
### but WITHOUT ANY WARRANTY; without even the implied warranty of
### MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
### GNU Affero General Public License for more details.

### You should have received a copy of the GNU Affero General Public License
### along with this program.  If not, see <https://www.gnu.org/licenses/>.

# The device that is running the subflow visualization must be on the same network as this sender,
# and must be reachable via UDP broadcast.
# Example usage:
# ./send_cmd.py "subflow24379;BPM:122:0;SCL:1.1:0;MOD:7:7;MOD:4:7;MOD:3:7;SCL:1.0:7;LOP:2:2000;"
#                  header    |  cmd 1  |  cmd 2  | cmd 3 | cmd 4 | cmd 5 |  cmd 6  |  cmd 7
#                ---------------------------------------------------------------------------
#                 keep as is | set BPM |set pulse| MODE 7| MODE 4| MODE 3| turn off| jump to cmd 2
#                            | to 122  | to 110% | for 7 | for 7 | for 7 | pulsing | and loop
#                            | forever |  scale  | beats | beats | beats |for 7 bts| 2000 times
#                                            ^                                          |
#                                            |___________________jump___________________|
# Command Structure
# "command : argument : duration (beats)"
#   string :  double  :      uint32
#
# Possible commands
#
# BPM - set BPM; argument is the BPM, 20.0 <= BPM <= 480.0
# SPD - set glide speed; argument is the speed, 0.3 <= SPD <= 6.3
# SCL - set pulse scale (1.0 = no pulsing); argument scales the beat pulses, 0.7 <= SCL <= 1.3
# MOD - set viz mode; argument is cast to an int to become the mode, 0 <= MOD <= 7 
#	  - duration should be (measure length - 1) to account for the mode transition beat
# LOP - jump to any valid command; argument is the jmp index (1-based, excluding header)
#     - here the duration is the number of loops; 0 <= duration <= 2e9; duration 0 is the same as duration 2e9

import sys
import socket

port  = 37020
magic = "subflow24379"
sendstr   = sys.argv[1]
print(sendstr)

server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
server.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
server.settimeout(1.0)
server.sendto(sendstr.encode('utf-8'), ('<broadcast>', port))

print("You should have seen the subflow screen flash briefly; if not, send again.")
print("To start this beat: Click UP on TV remote, or tap top of touchscreen.")
print("To pause: Click DOWN on TV remote or tap bottom of touchscreen.")
print("To unload sequence: Click DOWN or tap bottom while paused.")
