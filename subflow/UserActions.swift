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

class UserActions{
  var od:Triangle
  var lastColorSwitch: CFTimeInterval = -CFTimeInterval(DEBOUNCE_COLORSWITCH_T)
  var pulseClickTimestamp: CFTimeInterval = 0.0
  var lastProcessedPulseClickTimestamp: CFTimeInterval = 0.0
  var oldPulsePeriod: CFTimeInterval = 0.0
  var totalPulsePeriod: CFTimeInterval = 0.0
  var totalPulseCount: CFTimeInterval = 0.0

  init (odin: Triangle){
    self.od = odin
  }
  
  func tsNudgeEarlier(){
    od.lastPulseTimeStamp -= CFTimeInterval(PULSE_TS_NUDGE)
  }
  
  func tsNudgeLater(){
    od.lastPulseTimeStamp += CFTimeInterval(PULSE_TS_NUDGE)
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
    if od.playMode > MODE_STP {
      od.speed_in = max(od.speed_in-SPEED_STEP,SPEED_MIN)
    }
  }
  
  func speedUp(){
    if od.playMode > MODE_STP {
      od.speed_in = min(od.speed_in+SPEED_STEP,SPEED_MAX)
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

  func switchColor(){
    let switchTime = Date().timeIntervalSinceReferenceDate
    if (switchTime > lastColorSwitch + CFTimeInterval(DEBOUNCE_COLORSWITCH_T)){
      if (od.rgbcol == RGB_COLOR_RED){
        od.rgbcol = UInt8(RGB_COLOR_WHT)
      }else{
        od.rgbcol = UInt8(RGB_COLOR_RED)
      }
      lastColorSwitch = switchTime
    }
  }
  
  func nextMode(){
    if (od.playMode < LAST_MODE){
      od.playMode = od.playMode+1
    }
  }
  
  func prevMode(){
    if (od.playMode > FIRST_MODE){
      od.playMode = od.playMode-1
    }
  }
  
  func seqUp(){
    if od.cmdParser.cmdLoaded {
      od.reinitCmds()
      od.cmdParser.cmdReady = true
      // get the initial set of commands until the first beat-dependent command
      od.iterateCmds()
    }
  }
    
  func computeDelays(){
    var pulseElapsed: CFTimeInterval = 0.0
    var pulseCount: CFTimeInterval = 0.0

    pulseClickTimestamp = Date().timeIntervalSinceReferenceDate

    seqUp()
    
    if (oldPulsePeriod > 1e-1){
      od.pulsePeriod = oldPulsePeriod
      od.speed_in = Float(CFTimeInterval(TRI_SPACE)/od.pulsePeriod)
    }
    
    if od.remoteBPM > 1e-1{
      lastProcessedPulseClickTimestamp = 0.0
    }else{
      if lastProcessedPulseClickTimestamp > 0.0 {
        pulseElapsed = pulseClickTimestamp - lastProcessedPulseClickTimestamp
        if od.pulsePeriod < 1e-1{
          // if we've never set a period before, then this is the second click ever; a single pulse period has elapsed
          pulseCount = 1.0
        }else{
          // otherwise, we have previously set a beat and some time has passed;
          // we estimate how many beats fit into the elapsed time (this helps us improve our beat accuracy)
          // make sure pulseCount is never zero, i.e. never less than 1
          pulseCount = max(1,round(pulseElapsed / od.pulsePeriod))
        }
        
        // now add up all the time that has elapsed since we started counting
        totalPulsePeriod += pulseElapsed;
        // and the number of beats that have occurred (real clicks + estimated)
        totalPulseCount += pulseCount;

        // lastly, compute the new pulse period
        od.pulsePeriod = totalPulsePeriod / totalPulseCount
        od.speed_in = Float(CFTimeInterval(TRI_SPACE)/od.pulsePeriod)

      }
      lastProcessedPulseClickTimestamp = pulseClickTimestamp
    }
    
    // This zeroes the phase of whatever beat we may have set
    od.lastPulseTimeStamp = pulseClickTimestamp;
    // And pulses once. The next pulse will happen automatically in the render loop, with the right period
    od.scale = od.pulse_scale
  }

  func seqTrash(){
    od.cmdParser.cmdLoaded = false
    od.reinitCmds()
    od.defaultParams()
  }
  
  func seqDown(){
    if (od.cmdParser.cmdReady){
      // first click -- stop executing, can restart again
      od.cmdParser.cmdReady = false
    }else{
      // second click -- unload, cannot restart
      seqTrash()
    }
  }

  func pulseDown(localScale: Float){
    if od.pulsePeriod > 1e-1{
      oldPulsePeriod = od.pulsePeriod
      od.pulsePeriod = 0.0
    }else{
      oldPulsePeriod = 0.0
      od.scale = 1.0+(od.pulse_scale-1)*localScale
    }
    totalPulseCount = 0.0
    totalPulsePeriod = 0.0
    lastProcessedPulseClickTimestamp = 0.0
  }
    
  func pauseDelays(){
    seqDown()
    pulseDown(localScale: 1.0)
  }

}
