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
