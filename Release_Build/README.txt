ALARM SYSTEM - Release Version
===============================

This is a standalone macOS application with no debugging or Terminal windows.

HOW TO USE:
-----------
1. Double-click "Launch_Alarm_System.command" to start
2. Enter your admin password (required for sleep prevention)
3. Use the Alarm System app
4. When done, quit the app (EXIT APP button or Cmd+Q)
5. Enter admin password again to restore sleep settings

DIRECT LAUNCH:
--------------
You can also double-click "Alarm System.app" directly, but you'll need to
manually run these commands in Terminal:

Before using:  sudo pmset -b disablesleep 1
After using:   sudo pmset -b disablesleep 0

INSTALLATION:
-------------
To install permanently:
1. Copy "Alarm System.app" to /Applications
2. Keep "Launch_Alarm_System.command" for easy launching with sleep management

FEATURES:
---------
✓ No Terminal window
✓ No debugging overhead
✓ Faster startup
✓ Standalone application
✓ Automatic sleep prevention management

REQUIREMENTS:
-------------
- macOS (tested on current version)
- Witmotion WT9011DCL IMU sensor
- Bluetooth enabled
- Admin password (for sleep prevention)

