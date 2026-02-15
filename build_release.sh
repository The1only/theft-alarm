#!/bin/bash

# Build Release Version of Alarm System
# This creates a standalone macOS app without debugging or Terminal window

set -e

echo "🏗️  Building Release Version of Alarm System..."
echo "================================================"
echo ""

# Clean previous builds
echo "🧹 Cleaning previous builds..."
/tmp/flutter/bin/flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
/tmp/flutter/bin/flutter pub get

# Build release version
echo "🔨 Building macOS release (this may take 5-10 minutes)..."
/tmp/flutter/bin/flutter build macos --release

# Check if build succeeded
if [[ ! -d "build/macos/Build/Products/Release/Alarm.app" ]]; then
    echo "❌ Build failed - Alarm.app not found"
    exit 1
fi

echo ""
echo "✅ Release build complete!"
echo ""

# Create launcher script for release version
echo "📝 Creating release launcher..."

RELEASE_DIR="Release_Build"
mkdir -p "$RELEASE_DIR"

# Copy the release app
echo "📱 Copying Alarm.app..."
rm -rf "$RELEASE_DIR/Alarm System.app"
cp -R "build/macos/Build/Products/Release/Alarm.app" "$RELEASE_DIR/Alarm System.app"

# Create wrapper script for sleep management
cat > "$RELEASE_DIR/Launch_Alarm_System.command" << 'LAUNCHER_EOF'
#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_PATH="$SCRIPT_DIR/Alarm System.app"

echo "🚨 Alarm System Launcher"
echo "========================"
echo ""

# Request admin password and enable sleep prevention
echo "⚠️  Admin authentication required to prevent sleep while alarm is active"
osascript -e 'do shell script "pmset -b disablesleep 1" with administrator privileges' && \
    echo "✅ Sleep prevention enabled" || \
    { echo "❌ Failed to enable sleep prevention"; exit 1; }

echo ""
echo "🚀 Launching Alarm System..."

# Launch the app
open "$APP_PATH"

# Wait for app to close
echo "⏳ Waiting for app to close..."
while pgrep -f "Alarm System.app" > /dev/null; do
    sleep 1
done

echo ""
echo "🔄 Restoring sleep settings..."
echo "⚠️  Admin authentication required to restore sleep settings"

# Restore sleep settings
osascript -e 'do shell script "pmset -b disablesleep 0" with administrator privileges' && \
    echo "✅ Sleep settings restored" || \
    echo "❌ Failed to restore sleep - run: sudo pmset -b disablesleep 0"

echo ""
echo "👋 Alarm System closed"
LAUNCHER_EOF

chmod +x "$RELEASE_DIR/Launch_Alarm_System.command"

# Create README
cat > "$RELEASE_DIR/README.txt" << 'README_EOF'
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

README_EOF

echo ""
echo "🎉 Release build complete!"
echo ""
echo "📂 Location: $RELEASE_DIR/"
echo ""
echo "📝 Files created:"
echo "   • Alarm System.app         (Standalone macOS application)"
echo "   • Launch_Alarm_System.command  (Launcher with sleep management)"
echo "   • README.txt               (Instructions)"
echo ""
echo "🚀 To launch:"
echo "   cd '$RELEASE_DIR' && ./Launch_Alarm_System.command"
echo ""
echo "💾 To install permanently:"
echo "   cp -R '$RELEASE_DIR/Alarm System.app' /Applications/"
echo ""
