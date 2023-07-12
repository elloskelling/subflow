/* 
subflow - a music visualizer
Copyright (C) 2021-2023 Ello Skelling Productions

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

import Foundation

extension String {
  var subCmdParts: [String] {
    let parts = split(separator: ":")
    
    // Character sets may be inverted to identify all
    // characters that are *not* a member of the set.
    let delimiterSet = ":"
    
    return parts.compactMap { part in
      // Here we grab the first sequence of letters right
      // after the @-sign, and check that it’s non-empty.
      let name = part.components(separatedBy: delimiterSet)[0]
      return name.isEmpty ? nil : name
    }
  }

  var cmdParts: [String] {
    let parts = split(separator: ";")
    
    // Character sets may be inverted to identify all
    // characters that are *not* a member of the set.
    let delimiterSet = ";"
    
    return parts.compactMap { part in
      // Here we grab the first sequence of letters right
      // after the semicolon, and check that it’s non-empty.
      let name = part.components(separatedBy: delimiterSet)[0]
      return name.isEmpty ? nil : name
    }
  }
}

struct cmdStruct{
  var cmdType: String = UDP_NONE
  var cmdArg: CFTimeInterval = 0.0
  var cmdDuration: UInt32 = 0
}

class commandParser {
  var curIdx: Int = 0
  var cmdSize: Int = 0
  var cmdString: String = ""
  var cmdReady: Bool = false
  var cmdLoaded: Bool = false
  var loopCounter: UInt32 = 0
  
  func setCmd(cmd: String) -> Bool{
    if (cmd.cmdParts.count > 1 && cmd.cmdParts[0] == "subflow"+UDP_MAGIC){
      cmdString = cmd
      cmdSize = cmd.cmdParts.count
      curIdx = 1
      cmdLoaded = true
    }else{
      cmdLoaded = false
    }
    return cmdLoaded
  }
  
  func nextSubCmd() -> cmdStruct{
    // Execute the current index first, then advance.
    // This is because loops and countdowns can set the index explicitly
    let subCmd = cmdString.cmdParts[curIdx]
    var subCmdStruct = cmdStruct()

    if (subCmd.subCmdParts.count == 3){
      subCmdStruct.cmdType = subCmd.subCmdParts[0]
      subCmdStruct.cmdArg = CFTimeInterval(subCmd.subCmdParts[1]) ?? 0.0
      subCmdStruct.cmdDuration = UInt32(subCmd.subCmdParts[2]) ?? 0
    }

    // process a loop if needed
    if (subCmdStruct.cmdType == UDP_LOOP){
      if ((subCmdStruct.cmdDuration == 0 && loopCounter < UInt32.max) ||
          (subCmdStruct.cmdDuration <= MAX_LOOPS
           && loopCounter < subCmdStruct.cmdDuration)
          ){
        loopCounter = loopCounter + 1
        let newIdx = Int(subCmdStruct.cmdArg)
        if (newIdx < cmdSize - 1){
          curIdx = newIdx
          return nextSubCmd()
        } else {
        }
      }
    }
        
    if (curIdx < cmdSize - 1) {
      curIdx += 1
    }
  
    return subCmdStruct
  }
  
}
