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

import numpy as np

def calculateCheckSum(crc, byteValue): #UInt8
  generator = 29
  newCrc = np.uint8(np.bitwise_xor(crc,byteValue))
  for x in range(8):
    if np.bitwise_and(newCrc, np.uint8(128)) != 0:
      newCrc = np.uint8(np.bitwise_xor((newCrc << 1), generator))
    else:
      newCrc = np.uint8(newCrc << 1)
  return newCrc

uuid = "ABC31337-A123-B456-789E-DEADBEEFCAFE"
barr = uuid.encode()
uuidSum = np.uint8(0)


for b in barr:
  uuidSum = calculateCheckSum(uuidSum,np.uint8(b))

print(uuid)
print(uuidSum)