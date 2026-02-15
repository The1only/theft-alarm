# Troubleshooting Closed-Lid Operation

## If the alarm doesn't sound with MacBook lid closed:

### 1. Check System Settings
```bash
# Open System Settings and verify:
# Battery → "Prevent automatic sleeping on power adapter when display is off" = ON
# Sound → Output = "Internal Speakers" (not external devices)
# Bluetooth → WT9011DCL sensor stays connected
```

### 2. Verify Sleep Prevention is Active
Look for these console messages when arming:
```
🛌 Sleep prevention enabled - laptop will stay awake when closed
🛌 Sleep prevention activated - laptop will stay awake when closed
```

### 3. Force Audio to Internal Speakers
Add this to your test procedure:
```bash
# Disconnect any external audio devices before closing lid
# System Preferences → Sound → Output → Internal Speakers
```

### 4. Test Sleep Prevention Manually
```bash
# Open Terminal and run:
sudo pmset -g assertions
# Look for "PreventUserIdleSystemSleep" assertion from our app
```

### 5. Alternative: Use Clamshell Mode
If you have external monitor/keyboard:
```bash
# Connect external display and input devices
# Close lid while connected - this enables "clamshell mode"  
# System stays fully awake with external display
```

### 6. Emergency Override
If sleep prevention fails, you can manually prevent sleep:
```bash
# Run in Terminal before arming alarm:
caffeinate -d &
# This prevents display sleep until you kill the process
```

## Expected Behavior:
- ✅ MacBook fans may run (system is awake)
- ✅ Bluetooth sensor stays connected  
- ✅ Car alarm plays through built-in speakers
- ✅ Volume control works normally
- ✅ Motion detection continues working