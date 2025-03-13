# Bluetooth Audio App

A Flutter application that captures audio from the phone's microphone, processes it, and transmits it to wireless earbuds via Bluetooth.

## Features

- Microphone audio capture
- Real-time audio processing
- Volume adjustment
- Bluetooth device discovery and connection
- Audio visualization

## Architecture

This app follows a layered architecture:

1. **Presentation Layer** (UI)
   - Screens
   - Widgets
   - UI State

2. **Business Logic Layer**
   - Providers (using Provider package)
   - State Management
   - Business Rules

3. **Service Layer**
   - Audio Service
   - Bluetooth Service
   - Platform-specific APIs

4. **Data Layer**
   - Repositories
   - Local Storage

## Prerequisites

- Flutter SDK (latest version)
- Android Studio or VS Code
- Android device with API level 21+ or iOS device with iOS 10+

## Setup

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Ensure your device has Bluetooth and microphone permissions enabled
4. Run the app with `flutter run`

## Required Permissions

### Android
Add the following permissions to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### iOS
Add the following keys to your `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to microphone to capture audio</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs access to Bluetooth to connect to audio devices</string>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs access to Bluetooth to connect to audio devices</string>
```

## Dependencies

- flutter_sound: ^9.2.13
- permission_handler: ^11.1.0
- path_provider: ^2.1.1
- flutter_blue_plus: ^1.31.13
- provider: ^6.1.1
- flutter_svg: ^2.0.9
- audio_waveforms: ^1.0.4

## Limitations

- Bluetooth audio transmission relies on system audio routing
- Audio processing capabilities limited by device hardware
- Some features may require platform-specific customization

## Future Improvements

- Add equalizer functionality
- Implement noise cancellation
- Add preset audio profiles
- Support for more Bluetooth profiles
- Background mode operation
