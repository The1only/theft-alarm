import Cocoa
import FlutterMacOS
import AVFoundation

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
      default:
        result(FlutterMethodNotImplemented)
      }
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
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}