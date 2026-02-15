# Learn Something Flutter App

A cross-platform Flutter application for iOS, Android, and macOS.

## Getting Started

This project is a Flutter application for learning cross-platform development.

### Prerequisites

- Flutter SDK (3.0.0 or later)
- Dart SDK
- For iOS development: Xcode
- For Android development: Android Studio
- For macOS development: Xcode

### Installation

1. Install Flutter from https://flutter.dev/docs/get-started/install
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the app

### Running the App

```bash
# Get dependencies
flutter pub get

# Run on your connected device/emulator
flutter run

# Run on specific platform
flutter run -d ios
flutter run -d android
flutter run -d macos
```

### Project Structure

```
lib/
├── main.dart          # App entry point
├── screens/           # App screens
├── widgets/           # Reusable widgets
└── utils/             # Utility functions
```

### Features

- Cross-platform support (iOS, Android, macOS)
- Material Design 3
- Responsive layout
- State management ready

### Building for Release

```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release

# macOS
flutter build macos --release
```

## Contributing

1. Fork the project
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request# theft-alarm
