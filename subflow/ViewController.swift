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
import Network


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
    
  private var connection: NWConnection?
  private var listener: NWListener?
  let udpPort = NWEndpoint.Port.init(integerLiteral: UInt16(UDP_PORT))

  @Published var incoming: String = ""
  
  #if !os(tvOS)
  override var prefersHomeIndicatorAutoHidden: Bool { true }
  #endif
  
  func udpstart(port: NWEndpoint.Port) {
    do {
      self.listener = try NWListener(using: .udp, on: port)
    } catch {
      print("exception upon creating listener")
    }
    
    guard let _ = listener else { return }
    
    prepareUpdateHandler()
    prepareNewConnectionHandler()
    
    self.listener?.start(queue: .main)
  }
  
  
  func prepareUpdateHandler() {
    self.listener?.stateUpdateHandler = {(newState) in
      switch newState {
//      case .ready:
//        print("ready")
      default:
        break
      }
    }
  }
  
  func prepareNewConnectionHandler() {
    self.listener?.newConnectionHandler = {(newConnection) in
      newConnection.stateUpdateHandler = {newState in
        switch newState {
        case .ready:
//          print("ready")
          self.udpreceive(on: newConnection)
        default:
          break
        }
      }
      newConnection.start(queue: DispatchQueue(label: "newconn"))
    }
  }
  
  func udpreceive(on connection: NWConnection) {
    connection.receiveMessage { (data, context, isComplete, error) in
      if let error = error {
        print(error)
        return
      }
      
      guard let data = data, (!data.isEmpty && data.count < 400) else {
        print("unable to receive data")
        return
      }
      
      DispatchQueue.main.async {
        self.incoming = String(decoding: data, as: UTF8.self)
        if self.objectToDraw.cmdParser.setCmd(cmd: self.incoming){
          self.objectToDraw.shade = 0.3
        }
        connection.cancel()
      }
    }
  }

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
        pauseDelays()
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

  func pauseDelays(){
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
      objectToDraw.scale = objectToDraw.pulse_scale
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
      pauseDelays()
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
    
    udpstart(port: udpPort)
    print("UUID")
    print(UIDevice.current.identifierForVendor!.uuidString)
    
    uuidSum = 0
    let bytes = UIDevice.current.identifierForVendor!.uuidString.utf8
    for item in bytes {
       uuidSum = calculateCheckSum(crc: uuidSum, byteValue: UInt8(item))
    }
    
    print(uuidSum)
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
