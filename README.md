# Theft Alarm - Flutter Motion Detection System

A sophisticated Flutter-based theft alarm system that uses Alarm-sensor WT9011DCL IMU sensor for motion detection via Bluetooth. Features native volume control and loud car alarm sounds to deter theft.

## 🚨 Features

- **Motion Detection**: Real-time accelerometer-based movement detection with configurable sensitivity
- **Alarm-sensor IMU Support**: Full support for WT9011DCL IMU sensor via Bluetooth LE
- **Smart Volume Control**: Automatically saves current volume, sets to maximum during alarm, then restores original
- **Car Alarm Sound**: High-impact looping alarm sound with 5-second continuation after movement stops
- **Sleep Prevention**: Keeps laptop awake when alarm is armed, allowing closed-lid monitoring 
- **4-Second Countdown**: User-friendly countdown before arming provides time to close laptop
- **Cross-Platform**: Native implementation for macOS with iOS/Android support
- **Intelligent Bluetooth**: Proper adapter state handling eliminates need to scan twice

## 📱 Supported Platforms

- ✅ **macOS** (Primary platform with native volume control)
- ✅ **iOS** (Bluetooth and audio support)
- ✅ **Android** (Bluetooth and audio support)

## 🛠️ Prerequisites

- Flutter SDK (3.24.3 or later)
- Dart SDK
- **Xcode** (for macOS/iOS development)
- **Android Studio** (for Android development)
- **Alarm-sensor WT9011DCL IMU sensor** (or compatible device)

## 📦 Dependencies

```yaml
dependencies:
  flutter_blue_plus: ^1.32.12    # Bluetooth LE connectivity
  audioplayers: ^6.0.0           # Car alarm audio playback
```

## 🚀 Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/The1only/theft-alarm.git
   cd theft-alarm
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   # For macOS (recommended)
   flutter run -d macos
   
   # For iOS
   flutter run -d ios
   
   # For Android
   flutter run -d android
   ```

## 📖 Usage

### 🚀 **Best Option: Desktop App** 

Double-click the **Alarm System.app** for one-click operation:
```bash
# Create the desktop app (one-time setup):
./create_app_bundle.sh

# Then just double-click "Alarm System.app" to launch!
```

The app automatically handles sleep prevention setup and cleanup.

### ⭐ **Alternative: Command Line Launcher** 

Simply run the launcher script that handles everything automatically:
```bash
./run.sh
```

This script will:
- ✅ Enable sleep prevention (`sudo pmset -b disablesleep 1`)
- ✅ Launch the Flutter alarm app
- ✅ Automatically restore normal sleep when you exit (`sudo pmset -b disablesleep 0`)
- ✅ Handle cleanup even if interrupted with Ctrl+C

### Other Methods

### Option 1: For Reliable Closed-Lid Operation

**Step 1: Start Sleep Prevention Helper**
```bash
# In one terminal window:
./alarm_sleep_helper.sh
```

**Step 2: Launch Alarm App**
```bash  
# In another terminal:
flutter run -d macos
```

**Step 3: Normal Operation**
- Connect to your Alarm-sensor WT9011DCL sensor
- Arm the alarm (4-second countdown begins)
- Close your MacBook lid safely
- System stays awake and monitors motion
- Alarm sounds through built-in speakers if triggered

### Option 2: Standard Operation (App-Only)

### 1. Bluetooth Setup
- Launch the app and tap **"Scan for Devices"**
- Select your Alarm-sensor WT9011DCL device from the list
- Tap **"Connect"** to establish Bluetooth connection

### 2. Motion Alarm Operation
- **ARM**: Tap "ARM ALARM" button to activate motion detection
  - 4-second countdown provides time to close laptop
  - System captures current accelerometer baseline
  - Volume is saved for later restoration
  - Sleep prevention automatically activated
- **TRIGGER**: Movement above 0.045G threshold triggers car alarm
  - Volume automatically sets to maximum
  - Car alarm sound plays with looping
  - Continues for 5 seconds after movement stops
- **DISARM**: Tap "DISARM ALARM" to deactivate
  - Stops any active alarm
  - Restores original system volume
  - Sleep prevention automatically disabled

### 3. Volume Control Features
- **Auto-save**: Current volume captured on app start and when arming
- **Maximum during alarm**: System volume set to 100% during alarm
- **Smart restore**: Original volume level restored after alarm

### 4. Sleep Prevention
- **Automatic**: Activates when alarm is armed
- **Multiple Methods**: Uses IOKit power management + system settings
- **Clean Shutdown**: Automatically restores normal sleep when disarmed

## ⚙️ Configuration

### Motion Sensitivity
- **Threshold**: 0.045G (balanced above sensor noise floor)
- **Detection**: Accelerometer magnitude comparison against baseline
- **Continuation**: 5-second alarm continuation after movement stops

### Sensor Support
- **Packet Format**: 40-byte packets (two 20-byte segments)
- **Data Type**: 0x61 combined accelerometer/gyroscope/angle packets  
- **Range**: ±16g accelerometer range
- **Frequency**: ~100Hz update rate

## 🏗️ Project Structure

```
lib/
├── main.dart              # Main motion alarm application
├── main_backup.dart       # Backup of working version
├── bluetooth_main.dart    # Full Bluetooth IMU implementation
└── alarm_main.dart        # Alarm-specific implementation

macos/Runner/
├── AppDelegate.swift      # Native macOS volume control
└── Info.plist            # macOS app configuration

assets/
└── car_alarm_and_indistinct_talk_in_the_background_f9X.wav  # Alarm sound

android/                   # Android platform files
ios/                      # iOS platform files
web/                     # Web platform files (limited functionality)
```

## 🔧 Native Implementation

### macOS Volume Control
- **Platform Channel**: `volume_control` method channel
- **AppleScript Integration**: Uses `osascript` for system volume control
- **VolumeController Class**: Embedded in AppDelegate.swift

### Bluetooth Configuration
- **Auto-initialization**: Bluetooth adapter state monitoring
- **Error Handling**: User-friendly error messages for Bluetooth issues
- **Device Filtering**: Automatic Alarm-sensor device detection

## 🚨 Alarm System Details

### Motion Detection Algorithm
1. **Baseline Capture**: Records initial accelerometer magnitude when armed
2. **Real-time Monitoring**: Calculates magnitude every 100ms
3. **Threshold Comparison**: Triggers when |current - baseline| > 0.045G
4. **Movement Tracking**: Continues alarm for 5 seconds after last movement

### Audio System
- **File Format**: WAV audio with high-impact car alarm sound
- **Playback Mode**: ReleaseMode.loop for continuous alarm
- **Volume Control**: Dual-level control (system + app volume)

## 🔄 Backup Files

- **main_backup.dart**: Working motion alarm system backup
- **bluetooth_main.dart**: Extended Bluetooth functionality
- **alarm_main.dart**: Specialized alarm implementation

## 🐛 Troubleshooting

### Bluetooth Issues
- Ensure Bluetooth is enabled on your device
- Grant Bluetooth permissions when requested
- If scanning fails initially, try again after a few seconds

### Volume Control
- macOS: Requires system permissions for AppleScript
- iOS/Android: Limited to app-level volume control

### Motion Detection
- Ensure IMU sensor is properly positioned
- Allow a few seconds for baseline calibration
- Check sensor battery level if connectivity issues occur

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Commit changes: `git commit -m 'Add feature'`
4. Push to branch: `git push origin feature-name`
5. Open a Pull Request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

## 🙏 Acknowledgments

- **Alarm-sensor**: For IMU sensor hardware and documentation
- **Flutter Blue Plus**: For reliable Bluetooth LE implementation
- **AudioPlayers**: For cross-platform audio functionality

---

**⚠️ Disclaimer**: This theft alarm system is designed as a deterrent and educational project. For critical security applications, consider professional security systems with redundant monitoring and alerts.
