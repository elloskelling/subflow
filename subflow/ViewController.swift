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

class ViewController: UIViewController {
  var od: Triangle!
  var ua: UserActions!
  var device: MTLDevice!
  var metalLayer: CAMetalLayer!
  var pipelineState: MTLRenderPipelineState!
  var commandQueue: MTLCommandQueue!
  var timer: CADisplayLink!
  var projectionMatrix: Matrix4!
  var lastFrameTimestamp: CFTimeInterval = 0.0
  
  
  #if !os(tvOS)
  override var prefersHomeIndicatorAutoHidden: Bool { true }
  #endif
  
  override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    guard let type = presses.first?.type else { return }
    switch type {
    case .leftArrow:
      ua.prevMode()
    case .rightArrow:
      ua.nextMode()
    case .upArrow:
      ua.computeDelays()
    case .downArrow:
      ua.pauseDelays()
    default:
      super.pressesBegan(presses, with: event)
    }
  }
  
  override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    super.pressesEnded(presses, with: event)
  }
  
  
  @objc
  func handleTap(tapper: UITapGestureRecognizer) {
    let locx = tapper.location(in: self.view).x/self.view.bounds.width
    let locy = tapper.location(in: self.view).y/self.view.bounds.height

    if (locx < 0.2){ // left
      ua.prevMode()
    }else if (locx > 0.8) { //right
      ua.nextMode()
    }else{ //middle
      if (locy < 0.6){ // upper
        ua.computeDelays()
      }else{ //lower
        ua.pauseDelays()
      }
    }
}

  @objc
  func handlePress(presser: UITapGestureRecognizer) {
    ua.switchColor()
  }
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    #if !os(tvOS)
    super.setNeedsUpdateOfHomeIndicatorAutoHidden()
    #endif
    
    // initialize Metal
    device = MTLCreateSystemDefaultDevice()
    metalLayer = CAMetalLayer()
    metalLayer.device = device
    metalLayer.pixelFormat = .bgra8Unorm
    metalLayer.framebufferOnly = true
    metalLayer.frame = view.layer.frame
    view.layer.addSublayer(metalLayer)

    // set up the view matrix
    projectionMatrix = Matrix4.makePerspectiveViewAngle(Matrix4.degrees(toRad: 85.0), aspectRatio: Float(self.view.bounds.size.width / self.view.bounds.size.height), nearZ: NEAR_Z_LIMIT, farZ: FAR_Z_LIMIT)
    
  
    // initialize screen size
    var drawableSize: CGSize = self.view.bounds.size
    drawableSize.width  *= 2.0
    drawableSize.height *= 2.0
    metalLayer.drawableSize = drawableSize
        
    od = Triangle(device: device)
    ua = UserActions(odin: od)
    
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
    
    let swipeUp: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(ua.swipedUp))
    swipeUp.direction = .up
    view.addGestureRecognizer(swipeUp)

    let swipeDown: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(ua.swipedDown))
    swipeDown.direction = .down
    view.addGestureRecognizer(swipeDown)
    
    let swipeLeft: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(ua.swipedLeft))
    swipeLeft.direction = .left
    view.addGestureRecognizer(swipeLeft)

    let swipeRight: UISwipeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(ua.swipedRight))
    swipeRight.direction = .right
    view.addGestureRecognizer(swipeRight)

    let longPress: UILongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handlePress))
    view.addGestureRecognizer(longPress)

#if !os(tvOS)
    // disable tap recognizer on appleTV. It will use the arrows keys instead.
    let tapper:UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    view.addGestureRecognizer(tapper)
#endif

    // add all the network listeners
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

  func render() {
    guard let drawable = metalLayer?.nextDrawable() else { return }
    od.render(commandQueue: commandQueue, pipelineState: pipelineState, drawable: drawable,projectionMatrix: projectionMatrix, clearColor: nil)
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
    
    od.updateWithDelta(delta: timeSinceLastUpdate)
    
    autoreleasepool {
      self.render()
    }
  }
  
}
