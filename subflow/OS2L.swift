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

import NIO
import Foundation

// TCP Message Handler
class OS2LTCPMessageHandler: ChannelInboundHandler {
  typealias InboundIn = ByteBuffer
  var vc: ViewController
  var directBeat: Bool = true

  
  
  struct DataFrame: Codable {
    let evt: String
    let change: Bool
    let pos: Int
    let bpm: Double
    let strength: Double
    let id: Int
    let param: UInt32
    
    enum CodingKeys: String, CodingKey {
      case evt
      case change
      case pos
      case bpm
      case strength
      case id
      case param
    }
    
    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      evt = try container.decode(String.self, forKey: .evt)
      change = try container.decodeIfPresent(Bool.self, forKey: .change) ?? false
      pos = try container.decodeIfPresent(Int.self, forKey: .pos) ?? 0
      bpm = try container.decodeIfPresent(Double.self, forKey: .bpm) ?? 0.0
      strength = try container.decodeIfPresent(Double.self, forKey: .strength) ?? 0.0
      id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
      param = try container.decodeIfPresent(UInt32.self, forKey: .param) ?? 0
    }
  }
  
  func parseDataFrame(json: String) -> DataFrame? {
    let jsonData = json.data(using: .utf8)
    guard let data = jsonData else {
      print("Error: Invalid JSON string")
      return nil
    }
    
    do {
      let decoder = JSONDecoder()
      let dataFrame = try decoder.decode(DataFrame.self, from: data)
      return dataFrame
    } catch {
      print("Error: Failed to decode JSON: \(error)")
      return nil
    }
  }
  
  init(vcin: ViewController){
    self.vc = vcin
  }
  
  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    var buffer = unwrapInboundIn(data)
    if let message = buffer.readString(length: buffer.readableBytes) {
      if let dataFrame = parseDataFrame(json: message) {
        if dataFrame.evt.elementsEqual("beat"){
          if (directBeat == false){
            if (
              dataFrame.bpm >= CFTimeInterval(CMD_BPM_MIN) &&
              dataFrame.bpm <= CFTimeInterval(CMD_BPM_MAX)) {
              // just read the BPM, but don't pulse on this beat event
              vc.od.remoteBPM = dataFrame.bpm
              vc.od.pulsePeriod = 60.0/vc.od.remoteBPM
              vc.od.speed_in = Float(CFTimeInterval(TRI_SPACE)/vc.od.pulsePeriod)
            }
          }else{
            // Just pulse on this beat event.
            if vc.od.cmdParser.cmdReady{
              vc.od.iterateCmds()
            }
            vc.ua.pulseDown(localScale:Float(dataFrame.strength))
          }
        }
        if dataFrame.evt.elementsEqual("cmd"){
          if (dataFrame.id == 23){
            if (dataFrame.param >= FIRST_MODE && dataFrame.param <= LAST_MODE){
              vc.od.playMode = dataFrame.param
            }
          }
          if (dataFrame.id == 17){
            if (dataFrame.param == 100){
              // start sequence
              vc.ua.seqUp()
            }else{
              // stop sequence
              vc.od.cmdParser.cmdReady = false
            }
            if (dataFrame.param == 0){
              vc.ua.seqTrash()
            }
          }
          if (dataFrame.id == 11){
            vc.od.pulse_scale = SCALE_MIN+(SCALE_MAX-SCALE_MIN)*Float(dataFrame.param)/100.0
          }
          if (dataFrame.id == 7){
            if (dataFrame.param == 0){
              directBeat = false
            } else {
              directBeat = true
            }
          }
          if (dataFrame.id == 5){
            if dataFrame.param >= CMD_COLOR_MIN && dataFrame.param <= CMD_COLOR_MAX {
              vc.od.rgbcol = UInt8(dataFrame.param)
            }
          }
        }
      } else {
        print("Failed to parse JSON string")
      }
    }
  }
  
  func errorCaught(context: ChannelHandlerContext, error: Error) {
    print("Error: \(error)")
    context.close(promise: nil)
  }
}

// UDP Message Handler
class OS2LUDPMessageHandler: ChannelInboundHandler {
  typealias InboundIn = AddressedEnvelope<ByteBuffer>
  var vc: ViewController
  
  init(vcin: ViewController){
    self.vc = vcin
  }
  
  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let envelope = unwrapInboundIn(data)
    var buffer = envelope.data
    if let message = buffer.readString(length: buffer.readableBytes) {
      if vc.od.cmdParser.setCmd(cmd: message){
        vc.od.shade = 0.3
      }
    }
  }
  
  func errorCaught(context: ChannelHandlerContext, error: Error) {
    print("Error: \(error)")
    context.close(promise: nil)
  }
}
