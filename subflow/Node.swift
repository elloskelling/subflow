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
import Metal
import QuartzCore

extension String {
  var commandParts: [String] {
    let parts = split(separator: ":")
    
    // Character sets may be inverted to identify all
    // characters that are *not* a member of the set.
    let delimiterSet = ":"
    
    return parts.compactMap { part in
      // Here we grab the first sequence of letters right
      // after the delimiter, and check that it’s non-empty.
      let name = part.components(separatedBy: delimiterSet)[0]
      return name.isEmpty ? nil : name
    }
  }
}

class Node {
  
  let device: MTLDevice
  let name: String
  let numTris: Int = Int(NUM_TRIANGLES)
  var vertexCount: Int
  var vertexBuffer: MTLBuffer
  var uniformBuffer: MTLBuffer
  
  var positionX: Float = 0.0
  var positionY: Float = Y_OFFSET_LOW
  var positionZ: Float = 0.0
    
  var switch_k: Float = INIT_SWITCH_K
  let switch_k_in: Float = 0.0

  var warp:Float = 0.0
  var drift:Float = 0.0
  var speed:Float = 0.0
  var shade:Float = 0.0
  var offcenter:Float = 0.0
  
  var warp_in:Float = 1.0
  var speed_in:Float = 1.0
  var shade_in:Float = 1.0
  var offcenter_in:Float = 1.0

  var playMode: UInt32 = MODE_SPR
  var lastMode: UInt32 = MODE_SPR
  var timeInMode: CFTimeInterval = 0.0
  
  var rotationX: Float = 0.0
  var rotationY: Float = 0.0
  var rotationZ: Float = 0.0
  var rotationZ_in: Float = 0.0
  
  var zrots: [Float]
  var zrots_in: [Float]
  var zposs: [Float]
  var zposs_in: [Float]
  var xposs: [Float]
  var xposs_in: [Float]
  var yposs: [Float]
  var yposs_in: [Float]

  var scale: Float     = 1.0
  var pulse_scale: Float = DEFAULT_PULSE_SCALE
  var uBufferPointer: UnsafeMutableRawPointer
  var time:CFTimeInterval = 0.0
  
  var cmdParser: commandParser = commandParser()
  var curCmd: cmdStruct = cmdStruct()
  var curCmdCountdown: UInt32 = 0
  var remoteBPM: CFTimeInterval = 0.0
  
  var pulsePeriod: CFTimeInterval
  var lastPulseTimeStamp: CFTimeInterval
  
  init(name: String, vertices: Array<Vertex>, device: MTLDevice){
    var vertexData = Array<Float>()
    for vertex in vertices{
      vertexData += vertex.floatBuffer()
    }
    
    let dataSize = vertexData.count * MemoryLayout.size(ofValue: vertexData[0])
    vertexBuffer = device.makeBuffer(bytes: vertexData, length: dataSize, options: [])!
    
    self.name = name
    self.device = device
    vertexCount = vertices.count
    let uBufferSize = MemoryLayout<Float>.size * Matrix4.numberOfElements() * (numTris+1)
      + MemoryLayout<Float>.size * (numTris+3);
    uniformBuffer = device.makeBuffer(length: uBufferSize, options: [])!
    
    uBufferPointer = uniformBuffer.contents()
    
    zrots = [Float](repeating: 0.0, count: numTris)
    zrots_in = [Float](repeating: 0.0, count: numTris)
    zposs = [Float](repeating: 0.0, count: numTris)
    zposs_in = [Float](repeating: 0.0, count: numTris)
    xposs = [Float](repeating: 0.0, count: numTris)
    xposs_in = [Float](repeating: 0.0, count: numTris)
    yposs = [Float](repeating: 0.0, count: numTris)
    yposs_in = [Float](repeating: 0.0, count: numTris)

    pulsePeriod = 0.0
    lastPulseTimeStamp = Date().timeIntervalSinceReferenceDate
  }
  
  func render(commandQueue: MTLCommandQueue, pipelineState: MTLRenderPipelineState, drawable: CAMetalDrawable, projectionMatrix: Matrix4, clearColor: MTLClearColor?) {
    
    if shade > 0.02 {
      var nodeModelMatrix: Matrix4
      var greys = [Float](repeating: 0.0, count: numTris)
      
      let renderPassDescriptor = MTLRenderPassDescriptor()
      renderPassDescriptor.colorAttachments[0].texture = drawable.texture
      renderPassDescriptor.colorAttachments[0].loadAction = .clear
      renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0/255, green: 0.0/255.0, blue: 0.0/255.0, alpha: 1.0)
      
      let commandBuffer = commandQueue.makeCommandBuffer()!
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
      //renderEncoder.setCullMode(MTLCullMode.front)
      renderEncoder.setDepthClipMode(MTLDepthClipMode.clip)
      renderEncoder.setRenderPipelineState(pipelineState)
      renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
      
      let rotz0 = rotationZ
      let posx0 = positionX
      let posy0 = positionY
      let posz0 = positionZ

      var tweak:Float = 0.0
      
      if (playMode == MODE_SHM || playMode == MODE_PMP){
        for ni in 0...(numTris-1) {
          zposs_in[ni] = -3.7
          zrots_in[ni] = Float(.pi * Float(ni)).truncatingRemainder(dividingBy: 2.0 * .pi)
          if (playMode == MODE_SHM){
            xposs_in[ni] = Float(ni%15) * 1.1 - 7.7
            yposs_in[ni] = floor(Float(ni)/15.0) * 1.8 - 2.7
          }else if (playMode == MODE_PMP){
            xposs_in[ni] = (Float(ni%15) * 1.1 - 7.7) * scale
            yposs_in[ni] = (floor(Float(ni)/15.0) * 1.8 - 2.7) * scale
          }
          
          tweak = (scale-1.0)*Float.random(in: -1.0...1.0)
          rotationZ = zrots[ni] + tweak
          positionX = xposs[ni]
          positionY = yposs[ni]
          positionZ = zposs[ni]
          greys[ni] = 1.0 * shade
          nodeModelMatrix = self.modelMatrix()
          
          memcpy(uBufferPointer + MemoryLayout<Float>.size * Matrix4.numberOfElements()*ni, nodeModelMatrix.raw(), MemoryLayout<Float>.size * Matrix4.numberOfElements())
        }
      }else{
        for ni in 0...(numTris-1) {
          zposs_in[ni] = posz0-Float(TRI_SPACE)*Float(ni)
          if (playMode == MODE_SRC) {
            zrots_in[ni] = warp*0.2*cosf( (0.5+positionZ) * 2.0 * .pi / SECS_PER_MOVE)
          }else{
            zrots_in[ni] = rotz0*(1.0+warp*0.02*Float(ni))
          }
          xposs_in[ni] = posx0-drift*3.0*rotz0*(1.0+0.02*Float(ni))
          yposs_in[ni] = posy0*(1+drift*rotz0*(1.0+0.02*Float(ni)))
          tweak = (scale-1.0)*Float.random(in: -1.0...1.0)
          rotationZ = zrots[ni] + tweak
          positionX = xposs[ni]
          positionY = yposs[ni]
          positionZ = zposs[ni]
          greys[ni] = max(1+positionZ/FAR_Z_LIMIT,0.0)*shade
          nodeModelMatrix = self.modelMatrix()
          
          memcpy(uBufferPointer + MemoryLayout<Float>.size * Matrix4.numberOfElements()*ni, nodeModelMatrix.raw(), MemoryLayout<Float>.size * Matrix4.numberOfElements())
        }
        
      }
      rotationZ = rotz0
      positionX = posx0
      positionY = posy0
      positionZ = posz0

      memcpy(uBufferPointer + MemoryLayout<Float>.size * Matrix4.numberOfElements()*numTris, projectionMatrix.raw(), MemoryLayout<Float>.size * Matrix4.numberOfElements())
      
      memcpy(uBufferPointer + MemoryLayout<Float>.size * Matrix4.numberOfElements()*(numTris+1), greys, MemoryLayout<Float>.size * greys.count)
      
      renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
      for ni in 0...(numTris-1){
        renderEncoder.drawPrimitives(type: .lineStrip, vertexStart: (numTris-1-ni)*4, vertexCount: 4, instanceCount: 1)
      }
      renderEncoder.endEncoding()
      
      commandBuffer.present(drawable)
      commandBuffer.commit()
    }
  }
  
  func processCmdString(inCmd: cmdStruct){
    switch inCmd.cmdType {
    case UDP_BPM:
      let cmdBPM = inCmd.cmdArg
      if cmdBPM >= CFTimeInterval(CMD_BPM_MIN) && cmdBPM <= CFTimeInterval(CMD_BPM_MAX) {
        remoteBPM = cmdBPM
        pulsePeriod = 60.0/remoteBPM
        speed_in = Float(TRI_SPACE/pulsePeriod)
//        print("BPM: ", remoteBPM)
      }else{
        pulsePeriod = 0.0
      }
      curCmdCountdown = inCmd.cmdDuration
    case UDP_SPEED:
      // CALL VALIDATOR HERE? THey have already been validated though
      let cmdSpd = Float(inCmd.cmdArg)
      if cmdSpd >= SPEED_MIN && cmdSpd <= SPEED_MAX {
        speed_in = cmdSpd
//        print("Speed: ", speed_in)
      }
      curCmdCountdown = inCmd.cmdDuration
    case UDP_SCALE:
      let cmdScl = Float(inCmd.cmdArg)
      if cmdScl >= SCALE_MIN && cmdScl <= SCALE_MAX {
        pulse_scale = cmdScl
//        print("Scale: ", pulse_scale)
      }
      curCmdCountdown = curCmd.cmdDuration
    case UDP_MODE:
      let cmdMode = UInt32(inCmd.cmdArg)
      if (cmdMode >= FIRST_MODE && cmdMode <= LAST_MODE){
        playMode = cmdMode
//        print("Mode: ", playMode)
      }
      curCmdCountdown = inCmd.cmdDuration
    default:
      break
    }
  }

    
  func lowpass(ylast: Float, yin: Float, k: Float, dt:Float) -> Float {
    var yout = yin
    if (k > 2e-2 && dt > 0.0){
      let con = dt / k
      yout = ylast * ( 1.0 - con ) + yin * con
    }
    return yout
  }
  
  func modelMatrix() -> Matrix4 {
    let matrix = Matrix4()
    matrix.translate(positionX, y: positionY, z: positionZ)
    matrix.rotateAroundX(rotationX, y: rotationY, z: rotationZ)
    matrix.scale(scale, y: scale, z: scale)
    return matrix
  }
  
  func updateWithDelta(delta: CFTimeInterval){
    let step = Float(delta)
    time += delta * Double(speed)
    timeInMode += delta * Double(speed)
    scale = lowpass(ylast: scale, yin: 1.0, k: PULSE_K, dt: step)

    if (playMode != lastMode){
      if playMode == MODE_OFF{
        shade_in = 0.0
      }else{
        shade_in = 1.0
      }
      
      if playMode > MODE_STP{
        timeInMode = 0.0
        lastMode = playMode
        //fragile -- low-pass may break, though we put some protection in there
        switch_k = INIT_SWITCH_K
      }
    }
    
    //fragile -- see above, and don't mess with filter k
    switch_k = lowpass(ylast: switch_k, yin: switch_k_in, k: SWITCH_K_LP_K, dt: step)

    if (playMode == MODE_SHM || playMode == MODE_PMP){
      offcenter_in = 0.0
      speed = lowpass(ylast: speed, yin: 0.0, k: SPEED_LP_K, dt: step)
      drift = lowpass(ylast: drift, yin: 0.0, k: WARP_LP_K, dt: step)
      warp = lowpass(ylast: warp, yin: 0.0, k: WARP_LP_K, dt: step)
    } else if playMode == MODE_SPR{
      offcenter_in = 0.0
      speed = lowpass(ylast: speed, yin: speed_in*0.5, k: SPEED_LP_K, dt: step)
      drift = lowpass(ylast: drift, yin: 0.0, k: WARP_LP_K, dt: step)
      warp = lowpass(ylast: warp, yin: 10.0*(1-speed/10.5), k: WARP_LP_K, dt: step)
    } else if playMode == MODE_SRC{
      offcenter_in = 0.0
      speed = lowpass(ylast: speed, yin: speed_in*1.1, k: SPEED_LP_K, dt: step)
      drift = lowpass(ylast: drift, yin: 0.0, k: WARP_LP_K, dt: step)
      warp = lowpass(ylast: warp, yin: 10.0*(1-speed/10.5), k: WARP_LP_K, dt: step)
    }else if playMode == MODE_FUL{
      offcenter_in = 1.0
      speed = lowpass(ylast: speed, yin: speed_in, k: SPEED_LP_K, dt: step)
      drift = lowpass(ylast: drift, yin: 0.7*(1-speed/10.5), k: WARP_LP_K, dt: step)
      warp = lowpass(ylast: warp, yin: 1.5*(1-speed/8.5), k: WARP_LP_K, dt: step)
    }else if playMode == MODE_LIN{
      offcenter_in = 1.0
      speed = lowpass(ylast: speed, yin: speed_in, k: SPEED_LP_K, dt: step)
      drift = lowpass(ylast: drift, yin: 0.0, k: WARP_LP_K, dt: step)
      warp = lowpass(ylast: warp, yin: 0.0, k: WARP_LP_K, dt: step)
    }else if playMode == MODE_STP{
      offcenter_in = 1.0
      speed = lowpass(ylast: speed, yin: 0.0, k: SPEED_LP_K, dt: step)
      drift = lowpass(ylast: drift, yin: 0.0, k: WARP_LP_K, dt: step)
      warp = lowpass(ylast: warp, yin: 0.0, k: WARP_LP_K, dt: step)
    }else if playMode == MODE_OFF{
      offcenter_in = 1.0
      speed = lowpass(ylast: speed, yin: 0.0, k: SPEED_LP_K, dt: step)
      drift = lowpass(ylast: drift, yin: 0.0, k: WARP_LP_K, dt: step)
      warp = lowpass(ylast: warp, yin: 0.0, k: WARP_LP_K, dt: step)
    }
    shade = lowpass(ylast: shade, yin: shade_in, k: 0.2, dt: step)
    offcenter = lowpass(ylast: offcenter, yin: offcenter_in, k: 0.2, dt: step)

    // TIME advances by SPEED
    // figure out how to wrap when speed < 0
    positionZ = Float(time).truncatingRemainder(dividingBy: SECS_PER_MOVE)
    rotationZ = warp*0.2*sinf( positionZ * 2.0 * .pi / SECS_PER_MOVE)
    positionX = drift*0.1*sinf( positionZ * 2.0 * .pi / SECS_PER_MOVE)
    positionY = Y_OFFSET_LOW*offcenter+drift*0.1*sinf( positionZ * 2.0 * .pi / SECS_PER_MOVE)

    if pulsePeriod > 1e-1 {
      if (Date().timeIntervalSinceReferenceDate > lastPulseTimeStamp + pulsePeriod) {
        lastPulseTimeStamp += pulsePeriod
        scale = pulse_scale
        if cmdParser.cmdReady{
          iterateCmds()
        }
      }
    }
    
    for ni in 0...(numTris-1) {
      zrots[ni] = lowpass(ylast: zrots[ni], yin: zrots_in[ni], k: switch_k, dt: step)
      zposs[ni] = lowpass(ylast: zposs[ni], yin: zposs_in[ni], k: switch_k, dt: step)
      xposs[ni] = lowpass(ylast: xposs[ni], yin: xposs_in[ni], k: switch_k, dt: step)
      yposs[ni] = lowpass(ylast: yposs[ni], yin: yposs_in[ni], k: switch_k, dt: step)
    }
  }
  
  func iterateCmds(){
    var safeCounter: Int = 0
//    print("Countdown: ", curCmdCountdown)
    if curCmdCountdown > 0{
      curCmdCountdown -= 1
    }else{
      curCmd = cmdParser.nextSubCmd()
      processCmdString(inCmd: curCmd)
    }
    while (curCmdCountdown == 0 && curCmd.cmdDuration == 0 && safeCounter < MAX_INST_CMD_SEQ){
      safeCounter += 1
      curCmd = cmdParser.nextSubCmd()
      processCmdString(inCmd: curCmd)
    }
  }
  
  func reinitCmds(){
    cmdParser.curIdx = 1
    cmdParser.loopCounter = 0
    curCmdCountdown = 0
  }
  
  func defaultParams(){
//    speed_in = DEFAULT_SPEED
    pulse_scale = DEFAULT_PULSE_SCALE
    remoteBPM = 0.0
  }
}
