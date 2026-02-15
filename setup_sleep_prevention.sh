#!/bin/bash
# Sleep Enhancement Setup for Alarm System
# Run this once to maximize sleep prevention on battery power

echo "🔒 Alarm System - Enhanced Sleep Prevention Setup"
echo "=============================================="

# Check current status
echo "📋 Current power settings:"
pmset -g | grep -E "(SleepDisabled|disablesleep|sleep)"
echo ""

# Check if already disabled
if pmset -g | grep -q "SleepDisabled.*1"; then
    echo "✅ System sleep is already disabled!"
    echo "   Your alarm system has maximum protection."
else
    echo "⚙️  Setting up enhanced sleep prevention..."
    echo "   This requires admin privileges for system-level control."
    echo ""
    
    # Disable sleep on battery power
    echo "🔧 Disabling sleep on battery power..."
    sudo pmset -b disablesleep 1
    
    if [ $? -eq 0 ]; then
        echo "✅ Enhanced sleep prevention enabled!"
        echo "   Your MacBook will NOT sleep when running on battery"
        echo "   This ensures the alarm works even with the lid closed"
    else
        echo "❌ Failed to enable enhanced sleep prevention"
        echo "   You can run manually: sudo pmset -b disablesleep 1"
    fi
fi

echo ""
echo "🔄 To disable later (restore normal behavior):"
echo "   sudo pmset -b disablesleep 0"
echo ""
echo "🚨 Ready for alarm operation!"
echo "   Launch your Flutter app and arm the alarm"
echo "   Close your MacBook lid - it will stay awake"