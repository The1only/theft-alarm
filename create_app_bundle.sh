#!/bin/bash
# Create macOS App Bundle for Alarm System

echo "📦 Creating Alarm System.app bundle..."

# Create app bundle structure
mkdir -p "Alarm System.app/Contents/MacOS"
mkdir -p "Alarm System.app/Contents/Resources"

# Copy the run script as the main executable
cp run.sh "Alarm System.app/Contents/MacOS/Alarm System"
chmod +x "Alarm System.app/Contents/MacOS/Alarm System"

# Copy Info.plist
echo "📄 Adding app metadata..."
cp Info.plist "Alarm System.app/Contents/Info.plist"

# Copy app icons from the Flutter app if they exist
if [ -f "icon.icns" ]; then
    echo "📱 Using generated .icns icon..."
    cp icon.icns "Alarm System.app/Contents/Resources/AppIcon.icns"
elif [ -f "alarm-system-icon-18947.png" ]; then
    echo "📱 Using PNG icon..."
    cp alarm-system-icon-18947.png "Alarm System.app/Contents/Resources/AppIcon.icns"
elif [ -d "macos/Runner/Assets.xcassets/AppIcon.appiconset" ]; then
    echo "📱 Copying app icons from Flutter app..."
    cp macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png "Alarm System.app/Contents/Resources/AppIcon.icns" 2>/dev/null || \
    cp macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png "Alarm System.app/Contents/Resources/AppIcon.icns" 2>/dev/null || \
    cp macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png "Alarm System.app/Contents/Resources/AppIcon.icns" 2>/dev/null
else
    echo "⚠️  No icon found, using default"
fi

echo "✅ Alarm System.app created successfully!"
echo "📱 You can now double-click 'Alarm System.app' to launch"
echo "🗂️  Or drag it to Applications folder for permanent installation"