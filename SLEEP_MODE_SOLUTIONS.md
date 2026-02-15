# Sleep Mode Issues - Diagnosis and Solutions

## Problem Analysis
The alarm does not work when the MacBook goes to sleep/lid closed. This can happen due to:

1. **Sleep prevention failed** - Our assertions aren't strong enough
2. **macOS App Sandboxing** - Limits power management access
3. **Battery Power** - System overrides assertions on low battery
4. **System Policy** - Some macOS versions ignore app-level assertions

## ✅ Enhanced Solution

### Option 1: Manual System Setting (Recommended)
```bash
# Run this command to prevent sleep while plugged in
sudo pmset -c sleep 0

# To restore original behavior later:
sudo pmset -c sleep 1  # (or your preferred minutes)
```

### Option 2: Pre-Launch Prevention
Run this before starting the alarm app:
```bash
# Keep system awake indefinitely 
caffeinate -s &

# Kill when done:
pkill caffeinate
```

### Option 3: Integrated Solution
I'll add a helper script that runs alongside the Flutter app.

## 🔧 Testing Your Current Setup

Run the alarm app and check:
```bash
# 1. Check if assertions are created:
pmset -g assertions | grep -i alarm

# 2. Test sleep prevention manually:
pmset sleepnow  # Should NOT sleep if working

# 3. Check current sleep settings:
pmset -g
```

## 💡 Why This Happens

- **Modern macOS** (10.15+) is more aggressive about sleep
- **App Sandbox** limits what Flutter apps can control
- **Battery preservation** overrides many assertions
- **Bluetooth** may disconnect during deep sleep

## 📱 Alternative: Use iPhone/iPad

The most reliable solution might be:
1. Build Flutter app for iOS
2. Use iPhone/iPad as the alarm monitor
3. iOS keeps Bluetooth active during sleep
4. Works reliably with closed-lid MacBooks

Would you like me to implement any of these solutions?