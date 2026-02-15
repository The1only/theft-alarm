import Cocoa
import FlutterMacOS
import AVFoundation
import IOKit.pwr_mgt
import LocalAuthentication

// Sleep prevention controller
class SleepPrevention {
    private var systemSleepAssertionID: IOPMAssertionID = 0
    private var displaySleepAssertionID: IOPMAssertionID = 0
    private var isPreventingSleep = false
    
    func preventSleep() -> Bool {
        guard !isPreventingSleep else { return true }
        
        let reasonForActivity = "Alarm system is monitoring for motion" as CFString
        
        // Prevent system sleep (for closed lid)
        let systemResult = IOPMAssertionCreateWithName(
            "NoIdleSleepAssertion" as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reasonForActivity,
            &systemSleepAssertionID
        )
        
        // Also prevent display sleep to be safe
        let displayResult = IOPMAssertionCreateWithName(
            "PreventUserIdleDisplaySleep" as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reasonForActivity,
            &displaySleepAssertionID
        )
        
        if systemResult == kIOReturnSuccess {
            isPreventingSleep = true
            print("🛌 Sleep prevention enabled - laptop will stay awake when closed")
            print("🛌 System sleep assertion: \(systemResult), Display assertion: \(displayResult)")
            return true
        } else {
            print("❌ Failed to prevent sleep - System: \(systemResult), Display: \(displayResult)")
            return false
        }
    }
    
    func allowSleep() -> Bool {
        guard isPreventingSleep else { return true }
        
        let systemResult = IOPMAssertionRelease(systemSleepAssertionID)
        let displayResult = IOPMAssertionRelease(displaySleepAssertionID)
        
        if systemResult == kIOReturnSuccess {
            isPreventingSleep = false
            systemSleepAssertionID = 0
            displaySleepAssertionID = 0
            print("😴 Sleep prevention disabled - laptop can sleep normally")
            return true
        } else {
            print("❌ Failed to release sleep assertions - System: \(systemResult), Display: \(displayResult)")
            return false
        }
    }
    
    func isPreventingSystemSleep() -> Bool {
        return isPreventingSleep
    }
    
    // System-level sleep disable detection (no admin privileges needed)
    func checkSystemSleepDisabled() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/pmset"
        task.arguments = ["-g"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                // Check for both SleepDisabled and disablesleep settings
                let isSleepDisabled = output.contains("SleepDisabled          1") || 
                                     output.contains("disablesleep 1") ||
                                     output.contains("sleep prevented by")
                
                print(isSleepDisabled ? "🔒 System sleep is currently prevented" : "⚠️ System can sleep normally")
                return isSleepDisabled
            } else {
                print("❌ Failed to check system sleep status")
                return false
            }
        } catch {
            print("❌ Error checking pmset status: \(error)")
            return false
        }
    }
    
    deinit {
        if isPreventingSleep {
            IOPMAssertionRelease(systemSleepAssertionID)
            IOPMAssertionRelease(displaySleepAssertionID)
        }
    }
}

// Volume controller embedded in AppDelegate
class VolumeController {
    func getCurrentVolume() -> Float {
        // Note: AVAudioSession outputVolume is read-only on macOS
        // We'll use AppleScript to get system volume instead
        return getSystemVolume()
    }
    
    func setVolume(_ volume: Float) -> Bool {
        let volumePercent = Int(volume * 100)
        let script = "set volume output volume \(volumePercent)"
        
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            print("Error setting volume: \(error)")
            return false
        }
    }
    
    func getSystemVolume() -> Float {
        let script = "output volume of (get volume settings)"
        
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let volumeString = output, let volumeInt = Int(volumeString) {
                return Float(volumeInt) / 100.0
            }
        } catch {
            print("Error getting system volume: \(error)")
        }
        
        return 0.5
    }
}

@main
class AppDelegate: FlutterAppDelegate {
  private var audioPlayer: AVAudioPlayer?
  private var volumeController = VolumeController()
  private var sleepPrevention = SleepPrevention()
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller: FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
    
    // Audio channel for alarm sounds
    let audioChannel = FlutterMethodChannel(name: "alarm_audio", binaryMessenger: controller.engine.binaryMessenger)
    audioChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "playAlarm":
        self?.playAlarm()
        result(nil)
      case "stopAlarm":
        self?.stopAlarm()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    // Volume control channel
    let volumeChannel = FlutterMethodChannel(name: "volume_control", binaryMessenger: controller.engine.binaryMessenger)
    volumeChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "getVolume":
        let volume = self?.volumeController.getSystemVolume() ?? 0.5
        result(volume)
      case "setVolume":
        if let args = call.arguments as? [String: Any],
           let volume = args["volume"] as? Double {
          let success = self?.volumeController.setVolume(Float(volume)) ?? false
          result(success)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Volume value required", details: nil))
        }
      case "preventSleep":
        let success = self?.sleepPrevention.preventSleep() ?? false
        result(success)
      case "allowSleep":
        let success = self?.sleepPrevention.allowSleep() ?? false
        result(success)
      case "isPreventingSleep":
        let isActive = self?.sleepPrevention.isPreventingSystemSleep() ?? false
        result(isActive)
      case "checkSystemSleepDisabled":
        let isDisabled = self?.sleepPrevention.checkSystemSleepDisabled() ?? false
        result(isDisabled)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    // Authentication channel for biometric/password authentication
    let authChannel = FlutterMethodChannel(name: "authentication", binaryMessenger: controller.engine.binaryMessenger)
    authChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "authenticate":
        if let args = call.arguments as? [String: Any],
           let reason = args["reason"] as? String {
          self?.authenticateUser(reason: reason, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Reason required", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  private func authenticateUser(reason: String, result: @escaping FlutterResult) {
    let context = LAContext()
    var error: NSError?
    
    // Check if biometric authentication is available
    if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
      context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
        DispatchQueue.main.async {
          if success {
            print("✅ Authentication successful")
            result(true)
          } else {
            print("❌ Authentication failed: \(authError?.localizedDescription ?? "Unknown error")")
            result(false)
          }
        }
      }
    } else {
      print("❌ Authentication not available: \(error?.localizedDescription ?? "Unknown error")")
      result(false)
    }
  }
  
  private func playAlarm() {
    guard audioPlayer == nil || !audioPlayer!.isPlaying else { return }
    
    // Look for car_alarm.wav in app bundle Resources
    guard let url = Bundle.main.url(forResource: "car_alarm", withExtension: "wav") else {
      print("❌ Could not find car_alarm.wav in bundle")
      return
    }
    
    do {
      audioPlayer = try AVAudioPlayer(contentsOf: url)
      audioPlayer?.numberOfLoops = -1 // Loop indefinitely
      audioPlayer?.volume = 1.0
      audioPlayer?.prepareToPlay()
      audioPlayer?.play()
      print("✅ Car alarm playing (looping)")
    } catch {
      print("❌ Audio player error: \(error)")
    }
  }
  
  private func stopAlarm() {
    audioPlayer?.stop()
    audioPlayer = nil
    print("🔇 Car alarm stopped")
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // Don't terminate when window closes - needed for closed-lid operation
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}