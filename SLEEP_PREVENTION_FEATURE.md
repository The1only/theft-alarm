# Sleep Prevention Feature

## Overview
The Alarm app now includes sleep prevention functionality that keeps your laptop awake when the alarm is armed, allowing it to monitor for motion even with the laptop lid closed.

## How It Works

### When Alarm is Armed
1. After the 4-second countdown completes
2. The app prevents macOS from going to sleep using IOKit power management
3. Your laptop stays awake to continue monitoring motion via Bluetooth
4. Console shows: `🛌 Sleep prevention activated - laptop will stay awake when closed`

### When Alarm is Disarmed
1. Sleep prevention is automatically disabled
2. Your laptop returns to normal power management
3. Console shows: `😴 Sleep prevention disabled - laptop can sleep normally`

### Clean Exit
- When the app closes, sleep prevention is automatically disabled
- No risk of leaving your laptop permanently awake

## Technical Implementation

### macOS Native (Swift)
- **File**: `macos/Runner/AppDelegate.swift`
- **Class**: `SleepPrevention`
- **APIs Used**: IOKit power management (`IOPMAssertionCreateWithName`, `IOPMAssertionRelease`)
- **Assertion Type**: `kIOPMAssertPreventUserIdleSystemSleep`

### Flutter Integration
- **Method Channel**: `volume_control` (extended)
- **Methods Added**:
  - `preventSleep()` - Activate sleep prevention
  - `allowSleep()` - Deactivate sleep prevention  
  - `isPreventingSleep()` - Check current status

### Error Handling
- Graceful fallback if sleep prevention fails
- Automatic cleanup on app termination
- Console logging for all sleep state changes

## Real-World Usage

Perfect for:
- **Coffee shops**: Leave laptop closed on table while monitoring
- **Travel**: Secure laptop in hotel rooms
- **Office**: Monitor workstation during breaks
- **Home**: Nighttime security without screen glow

## Power Consumption
- Minimal impact on battery life
- Only prevents display sleep, not CPU throttling
- Bluetooth monitoring uses very little power
- Automatic return to normal power management when disarmed

## Status Messages
- `🛌 Sleep prevention enabled` - System-level activation successful
- `🛌 Sleep prevention activated` - Flutter-level confirmation  
- `😴 Sleep prevention disabled` - Normal power management restored
- `❌ Failed to prevent sleep` - Error occurred (rare)

The laptop will now stay awake and continue monitoring for motion even when the lid is closed, making the theft alarm system fully functional for real-world deployment scenarios.