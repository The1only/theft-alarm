#!/bin/bash
# Alarm System Sleep Prevention Helper
# This script ensures your Mac stays awake while the alarm is monitoring

echo "🛌 Alarm System Sleep Prevention Helper"
echo "======================================"

# Check if running on battery
if pmset -g batt | grep -q "Battery Power"; then
    echo "⚠️  WARNING: Running on battery power"
    echo "   Sleep prevention may be limited to preserve battery"
    echo ""
fi

# Function to prevent sleep
prevent_sleep() {
    echo "🔒 Preventing system sleep..."
    
    # Multiple methods for maximum compatibility
    caffeinate -d -s &
    CAFFEINATE_PID=$!
    echo "   caffeinate started (PID: $CAFFEINATE_PID)"
    
    # Also set temporary system sleep to never (requires sudo) 
    if sudo -n pmset -c sleep 0 2>/dev/null; then
        echo "   System sleep disabled via pmset"
        PMSET_CHANGED=1
    else
        echo "   ⚠️  Could not change system sleep settings (sudo required)"
        PMSET_CHANGED=0
    fi
    
    echo "✅ Sleep prevention active!"
    echo "   Your Mac will stay awake even with the lid closed"
}

# Function to restore sleep
restore_sleep() {
    echo ""
    echo "😴 Restoring normal sleep behavior..."
    
    if [ ! -z "$CAFFEINATE_PID" ]; then
        kill $CAFFEINATE_PID 2>/dev/null
        echo "   caffeinate stopped"
    fi
    
    if [ "$PMSET_CHANGED" = "1" ]; then
        sudo pmset -c sleep 1 2>/dev/null
        echo "   System sleep settings restored"
    fi
    
    echo "✅ Normal power management restored"
}

# Trap to cleanup on exit
trap restore_sleep EXIT INT TERM

# Prevent sleep
prevent_sleep

echo ""
echo "🚨 READY FOR ALARM OPERATION"
echo "   1. Start your Flutter alarm app now"
echo "   2. Close your MacBook lid safely" 
echo "   3. The system will stay awake"
echo ""
echo "Press Ctrl+C or close this terminal to restore normal sleep"
echo ""

# Keep the script running
while true; do
    sleep 10
    # Verify caffeinate is still running
    if ! kill -0 $CAFFEINATE_PID 2>/dev/null; then
        echo "⚠️  caffeinate died, restarting..."
        caffeinate -d -s &
        CAFFEINATE_PID=$!
    fi
done