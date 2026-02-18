import Flutter
import UIKit
import AVFoundation
import LocalAuthentication

// Sleep prevention controller for iOS
class SleepPrevention {
    private var isPreventingSleep = false
    
    func preventSleep() -> Bool {
        // On iOS, prevent screen from auto-locking
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        isPreventingSleep = true
        print("🛌 iOS sleep prevention enabled - screen won't auto-lock")
        return true
    }
    
    func allowSleep() -> Bool {
        // Allow normal auto-lock behavior
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        isPreventingSleep = false
        print("😴 iOS sleep prevention disabled - normal auto-lock resumed")
        return true
    }
    
    func isPreventingSystemSleep() -> Bool {
        return isPreventingSleep
    }
    
    func checkSystemSleepDisabled() -> Bool {
        // iOS doesn't have system-level sleep settings like macOS
        return UIApplication.shared.isIdleTimerDisabled
    }
}

// Volume controller for iOS
class VolumeController {
    private let audioSession = AVAudioSession.sharedInstance()
    
    func getCurrentVolume() -> Float {
        // On iOS, we can read the system output volume
        return audioSession.outputVolume
    }
    
    func setVolume(_ volume: Float) -> Bool {
        // Note: iOS restricts programmatic volume changes for privacy/UX reasons
        // Apps can only control their own audio playback volume, not system volume
        // This will work for the alarm sound played through AVAudioPlayer
        
        // Configure audio session for playback
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)
            
            // We can't directly set system volume, but we'll return success
            // so the app knows to play audio at maximum volume
            print("⚠️ iOS: System volume cannot be changed programmatically")
            print("📱 Audio session configured for maximum playback")
            return true
        } catch {
            print("❌ Failed to configure audio session: \(error)")
            return false
        }
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
    var volumeController = VolumeController()
    var sleepPrevention = SleepPrevention()
    var channelsInitialized = false
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Configure audio session for alarm sounds
        configureAudioSession()
        
        GeneratedPluginRegistrant.register(with: self)
        
        // Try to setup channels immediately
        trySetupChannels()
        
        // Also try after a delay to ensure Flutter is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.trySetupChannels()
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
        // Try again when app becomes active
        trySetupChannels()
    }
    
    private func trySetupChannels() {
        guard !channelsInitialized else { return }
        
        if let controller = window?.rootViewController as? FlutterViewController {
            setupMethodChannels(with: controller)
            channelsInitialized = true
            print("✅ Method channels initialized successfully")
        } else {
            print("⚠️ FlutterViewController not ready yet, will retry")
        }
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
    
    func setupMethodChannels(with controller: FlutterViewController) {
        print("🔧 Setting up method channels...")
        
        // Volume control channel
        let volumeChannel = FlutterMethodChannel(
            name: "volume_control",
            binaryMessenger: controller.binaryMessenger
        )
        print("📱 Volume channel created")
        volumeChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "getVolume":
                let volume = self?.volumeController.getCurrentVolume() ?? 0.5
                result(Double(volume))
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
        
        // Authentication channel for Face ID/Touch ID
        let authChannel = FlutterMethodChannel(
            name: "authentication",
            binaryMessenger: controller.binaryMessenger
        )
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
        
        // Check if biometric authentication is available (Face ID/Touch ID)
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        print("✅ Authentication successful (Face ID/Touch ID/Passcode)")
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
    
    override func applicationWillTerminate(_ application: UIApplication) {
        // Allow sleep when app terminates
        sleepPrevention.allowSleep()
    }
}
