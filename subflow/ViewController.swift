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

import UIKit
import Metal
import NIO
import Foundation

// TCP Message Handler
class OS2LTCPMessageHandler: ChannelInboundHandler {
  typealias InboundIn = ByteBuffer
  var vc: ViewController
  
  
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
//      print("Received TCP message: \(message)")
      if let dataFrame = parseDataFrame(json: message) {
        if dataFrame.evt.elementsEqual("beat"){
          vc.pauseDelays(localScale:Float(dataFrame.strength))
        }
        if dataFrame.evt.elementsEqual("cmd"){
          if (dataFrame.id == 23){
            if (dataFrame.param >= FIRST_MODE && dataFrame.param <= LAST_MODE){
              vc.objectToDraw.playMode = dataFrame.param
//              print("changed mode")
            }
          }
        }
//        print("Event: \(dataFrame.evt)")
//        print("Change: \(dataFrame.change)")
//        print("Position: \(dataFrame.pos)")
//        print("BPM: \(dataFrame.bpm)")
//        print("Strength: \(dataFrame.strength)")
//        print("ID: \(dataFrame.id)")
//        print("Param: \(dataFrame.param)")
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
//      print("Received UDP message: \(message)")
      if vc.objectToDraw.cmdParser.setCmd(cmd: message){
        vc.objectToDraw.shade = 0.3
      }
    }
  }
  
  func errorCaught(context: ChannelHandlerContext, error: Error) {
    print("Error: \(error)")
    context.close(promise: nil)
  }
}

class ViewController: UIViewController {
  var objectToDraw: Triangle!
  
  var device: MTLDevice!
  var metalLayer: CAMetalLayer!
  var pipelineState: MTLRenderPipelineState!
  var commandQueue: MTLCommandQueue!
  var timer: CADisplayLink!
  var projectionMatrix: Matrix4!
  var lastFrameTimestamp: CFTimeInterval = 0.0
  var pulseClickTimestamp: CFTimeInterval = 0.0
  var lastProcessedPulseClickTimestamp: CFTimeInterval = 0.0
  var totalPulsePeriod: CFTimeInterval = 0.0
  var totalPulseCount: CFTimeInterval = 0.0
  var uuidSum: UInt8 = 0
  var oldPulsePeriod: CFTimeInterval = 0.0
  
  #if !os(tvOS)
  override var prefersHomeIndicatorAutoHidden: Bool { true }
  #endif
  
  func tsNudgeEarlier(){
    objectToDraw.lastPulseTimeStamp -= PULSE_TS_NUDGE
  }
  
  func tsNudgeLater(){
    objectToDraw.lastPulseTimeStamp += PULSE_TS_NUDGE
  }
  
  @objc
  func swipedRight(sender:UISwipeGestureRecognizer){
    tsNudgeLater()
  }

  @objc
  func swipedLeft(sender:UISwipeGestureRecognizer){
    tsNudgeEarlier()
  }
  
  func speedDown(){
    if objectToDraw.playMode > MODE_STP {
      objectToDraw.speed_in = max(objectToDraw.speed_in-SPEED_STEP,SPEED_MIN)
    }
  }
  
  func speedUp(){
    if objectToDraw.playMode > MODE_STP {
      objectToDraw.speed_in = min(objectToDraw.speed_in+SPEED_STEP,SPEED_MAX)
    }
  }
  
  @objc
  func swipedDown(sender:UISwipeGestureRecognizer){
    speedDown()
  }

  @objc
  func swipedUp(sender:UISwipeGestureRecognizer){
    speedUp()
  }
  
  @objc
  func handleTap(tapper: UITapGestureRecognizer) {
    let locx = tapper.location(in: self.view).x/self.view.bounds.width
    let locy = tapper.location(in: self.view).y/self.view.bounds.height

    if (locx < 0.2){ // left
      prevMode()
    }else if (locx > 0.8) { //right
      nextMode()
    }else{ //middle
      if (locy < 0.6){ // upper
        computeDelays()
      }else{ //lower
        pauseDelays(localScale: 1.0)
      }
    }
  }
  
  func nextMode(){
    if (objectToDraw.playMode < LAST_MODE){
      objectToDraw.playMode = objectToDraw.playMode+1
    }
  }
  
  func prevMode(){
    if (objectToDraw.playMode > FIRST_MODE){
      objectToDraw.playMode = objectToDraw.playMode-1
    }
  }
  
  
    
  func computeDelays(){
    var pulseElapsed: CFTimeInterval = 0.0
    var pulseCount: CFTimeInterval = 0.0

    pulseClickTimestamp = Date().timeIntervalSinceReferenceDate

    if objectToDraw.cmdParser.cmdLoaded {
      objectToDraw.reinitCmds()
      objectToDraw.cmdParser.cmdReady = true
      // get the initial set of commands until the first beat-dependent command
      objectToDraw.iterateCmds()
    }

    if (oldPulsePeriod > 1e-1){
      objectToDraw.pulsePeriod = oldPulsePeriod
      objectToDraw.speed_in = Float(TRI_SPACE/objectToDraw.pulsePeriod)
    }
    
    if objectToDraw.remoteBPM > 1e-1{
      lastProcessedPulseClickTimestamp = 0.0
    }else{
      if lastProcessedPulseClickTimestamp > 0.0 {
        pulseElapsed = pulseClickTimestamp - lastProcessedPulseClickTimestamp
        if objectToDraw.pulsePeriod < 1e-1{
          // if we've never set a period before, then this is the second click ever; a single pulse period has elapsed
          pulseCount = 1.0
        }else{
          // otherwise, we have previously set a beat and some time has passed;
          // we estimate how many beats fit into the elapsed time (this helps us improve our beat accuracy)
          // make sure pulseCount is never zero, i.e. never less than 1
          pulseCount = max(1,round(pulseElapsed / objectToDraw.pulsePeriod))
        }
        
        // now add up all the time that has elapsed since we started counting
        totalPulsePeriod += pulseElapsed;
        // and the number of beats that have occurred (real clicks + estimated)
        totalPulseCount += pulseCount;

        // lastly, compute the new pulse period
        objectToDraw.pulsePeriod = totalPulsePeriod / totalPulseCount
        objectToDraw.speed_in = Float(TRI_SPACE/objectToDraw.pulsePeriod)

      }
      lastProcessedPulseClickTimestamp = pulseClickTimestamp
    }
    
    //    print(objectToDraw.pulsePeriod)
    // This zeroes the phase of whatever beat we may have set
    objectToDraw.lastPulseTimeStamp = pulseClickTimestamp;
    // And pulses once. The next pulse will happen automatically in the render loop, with the right period
    objectToDraw.scale = objectToDraw.pulse_scale
  }

  func pauseDelays(localScale: Float){
    if (objectToDraw.cmdParser.cmdReady){
      // first click -- stop executing, can restart again
      objectToDraw.cmdParser.cmdReady = false
    }else{
      // second click -- unload, cannot restart
      objectToDraw.cmdParser.cmdLoaded = false
      objectToDraw.reinitCmds()
      objectToDraw.defaultParams()
    }

    if objectToDraw.pulsePeriod > 1e-1{
      oldPulsePeriod = objectToDraw.pulsePeriod
      objectToDraw.pulsePeriod = 0.0
    }else{
      oldPulsePeriod = 0.0
      objectToDraw.scale = 1.0+(objectToDraw.pulse_scale-1)*localScale
    }
    totalPulseCount = 0.0
    totalPulsePeriod = 0.0
    lastProcessedPulseClickTimestamp = 0.0
  }
  
  override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    guard let type = presses.first?.type else { return }
    
    switch type {
    case .leftArrow:
      prevMode()
    case .rightArrow:
      nextMode()
    case .upArrow:
      computeDelays()
    case .downArrow:
      pauseDelays(localScale: 1.0)
    default:
      super.pressesBegan(presses, with: event)
    }
  }
  
  override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    super.pressesEnded(presses, with: event)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if !os(tvOS)
    super.setNeedsUpdateOfHomeIndicatorAutoHidden()
    #endif
    
    projectionMatrix = Matrix4.makePerspectiveViewAngle(Matrix4.degrees(toRad: 85.0), aspectRatio: Float(self.view.bounds.size.width / self.view.bounds.size.height), nearZ: NEAR_Z_LIMIT, farZ: FAR_Z_LIMIT)
    
    
    device = MTLCreateSystemDefaultDevice()
    
    metalLayer = CAMetalLayer()
    metalLayer.device = device
    metalLayer.pixelFormat = .bgra8Unorm
    metalLayer.framebufferOnly = true
    metalLayer.frame = view.layer.frame
    
    var drawableSize: CGSize = self.view.bounds.size
    drawableSize.width  *= 2.0
    drawableSize.height *= 2.0
    metalLayer.drawableSize = drawableSize
    
    view.layer.addSublayer(metalLayer)
    
    objectToDraw = Triangle(device: device)
    
    let defaultLibrary = device.makeDefaultLibrary()!
    let fragmentProgram = defaultLibrary.makeFunction(name: "basic_fragment")
    let vertexProgram = defaultLibrary.makeFunction(name: "basic_vertex")
    
    let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
    pipelineStateDescriptor.vertexFunction = vertexProgram
    pipelineStateDescriptor.fragmentFunction = fragmentProgram
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    
    pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
    
    commandQueue = device.makeCommandQueue()
    
    timer = CADisplayLink(target: self, selector: #selector(ViewController.newFrame(displayLink:)))
    timer.add(to: RunLoop.main, forMode: .default)
    UIApplication.shared.isIdleTimerDisabled = true
    
    let swipeUp: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipedUp))
    swipeUp.direction = .up
    view.addGestureRecognizer(swipeUp)

    let swipeDown: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipedDown))
    swipeDown.direction = .down
    view.addGestureRecognizer(swipeDown)
    
    let swipeLeft: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipedLeft))
    swipeLeft.direction = .left
    view.addGestureRecognizer(swipeLeft)

    let swipeRight: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(swipedRight))
    swipeRight.direction = .right
    view.addGestureRecognizer(swipeRight)

    let tapper = UITapGestureRecognizer(target: self,
                                                action: #selector(handleTap))
    view.addGestureRecognizer(tapper)
    
    print("UUID")
    print(UIDevice.current.identifierForVendor!.uuidString)
    
    uuidSum = 0
    let bytes = UIDevice.current.identifierForVendor!.uuidString.utf8
    for item in bytes {
       uuidSum = calculateCheckSum(crc: uuidSum, byteValue: UInt8(item))
    }
    
    print(uuidSum)
    
    

    DispatchQueue(label:"netlisten").async(qos: .utility) {
      let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
      // TCP Bootstrap
      let tcpBootstrap = ServerBootstrap(group: group)
        .serverChannelOption(ChannelOptions.backlog, value: 256)
        .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        .childChannelInitializer { channel in
          channel.pipeline.addHandler(OS2LTCPMessageHandler(vcin:self))
        }
        .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
        .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
      
      // UDP Bootstrap
      let udpBootstrap = DatagramBootstrap(group: group)
        .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        .channelInitializer { channel in
          channel.pipeline.addHandler(OS2LUDPMessageHandler(vcin:self))
        }
      defer {
        try? group.syncShutdownGracefully()
      }

      do{
          // Bind TCP server
          let tcpChannel = try tcpBootstrap.bind(host: "0.0.0.0", port: Int(TCP_PORT)).wait()
          print("Listening for TCP on \(tcpChannel.localAddress!)")
          
          // Bind UDP server
          let udpChannel = try udpBootstrap.bind(host: "0.0.0.0", port: Int(UDP_PORT)).wait()
          print("Listening for UDP on \(udpChannel.localAddress!)")
          
          try udpChannel.closeFuture.wait()
          try tcpChannel.closeFuture.wait()
      }catch{
        print("Error opening TCP listener")
      }
    }
  }

  
  func calculateCheckSum(crc:UInt8, byteValue: UInt8) -> UInt8 {
      let generator: UInt8 = 0x1D
        // a new variable has to be declared inside this function
      var newCrc = crc ^ byteValue
    
      for _ in 1...8 {
          if newCrc & 0x80 != 0 {
              newCrc = (newCrc << 1) ^ generator
          }
          else {
              newCrc = newCrc << 1
          }
      }
    
      return newCrc
  }
      
  func render() {
    guard let drawable = metalLayer?.nextDrawable() else { return }
    objectToDraw.render(commandQueue: commandQueue, pipelineState: pipelineState, drawable: drawable,projectionMatrix: projectionMatrix, clearColor: nil)
  }
  
  @objc func newFrame(displayLink: CADisplayLink){
    
    if lastFrameTimestamp == 0.0
    {
      lastFrameTimestamp = displayLink.timestamp
    }
    
    let elapsed: CFTimeInterval = displayLink.timestamp - lastFrameTimestamp
    lastFrameTimestamp = displayLink.timestamp
    
    gameloop(timeSinceLastUpdate: elapsed)
  }
  
  func gameloop(timeSinceLastUpdate: CFTimeInterval) {
    
    objectToDraw.updateWithDelta(delta: timeSinceLastUpdate)
    
    autoreleasepool {
      self.render()
    }
  }
  
}
