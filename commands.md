# Akhiyan Flutter Project - Commands Reference

## Project Setup

### Initial Setup
```bash
flutter pub get
```

### Clean Build (if needed)
```bash
flutter clean
flutter pub get
```

## Running the App

### Web (Recommended for UI iteration)
```bash
flutter run -d chrome
```

### Android Emulator
```bash
# List available emulators
emulator -list-avds

# Start an emulator
emulator -avd <emulator_name>

# Run app on Android emulator
flutter run -d emulator-5554
```

### iOS Simulator (macOS only)
```bash
# List available simulators
xcrun simctl list devices

# Start simulator
open -a Simulator

# Run app on iOS simulator
flutter run -d iPhone
```

### Physical Device (Android/iOS)
```bash
# List connected devices
flutter devices

# Run on connected device
flutter run -d <device_id>
```

## Mobile UI & Testing

### Run with specific device configuration
```bash
# Run with tablet preview
flutter run -d chrome --web-renderer html

# Profile mode (performance testing)
flutter run --profile

# Release mode
flutter run --release
```

### Device Preview (if using device_preview package)
```bash
flutter run -d chrome --dart-define=ENABLE_DEVICE_PREVIEW=true
```

## Building for Release

### Android Release
```bash
# Build APK
flutter build apk --release

# Build App Bundle (for Google Play)
flutter build appbundle --release
```

### iOS Release
```bash
flutter build ipa --release
```

### Web Release
```bash
flutter build web --release
```

## Development Commands

### Code Generation (if using Riverpod, Freezed, etc.)
```bash
flutter pub run build_runner build --delete-conflicting-outputs
flutter pub run build_runner watch  # For continuous watching
```

### Analyze Code
```bash
flutter analyze
```

### Format Code
```bash
dart format lib/
dart format --set-exit-if-changed lib/  # Fail if formatting needed
```

### Lint Code
```bash
flutter analyze --no-pub
```

### Run Tests
```bash
flutter test
flutter test --coverage  # With coverage report
```

## Hot Reload & Hot Restart

### In Running App
- **Hot Reload**: Press `r` (keeps app state)
- **Hot Restart**: Press `R` (full restart)
- **Quit**: Press `q`

## Useful Debugging Commands

### Enable Web Inspector
```bash
flutter run -d chrome --web-renderer canvaskit  # Better for complex UIs
flutter run -d chrome --web-renderer html       # Faster for simple UIs
```

### View Device Logs
```bash
flutter logs
```

### Run with Verbose Output
```bash
flutter run -v
```

## Dependencies & Pub

### Update Dependencies
```bash
flutter pub upgrade
flutter pub upgrade --major-versions  # Upgrade to latest major versions
```

### Get Specific Dependency Version
```bash
flutter pub add package_name:^version
```

### Remove Dependency
```bash
flutter pub remove package_name
```

## Emulator-Specific Commands (Android)

### Create New Emulator
```bash
flutter emulators --create --name <name>
```

### Delete Emulator
```bash
flutter emulators --delete <name>
```

### Launch Emulator via Flutter
```bash
flutter emulators --launch <emulator_id>
```

## Troubleshooting

### Commands Hanging/Not Responding

If commands freeze and don't complete, try these solutions:

#### 1. **Network Connectivity Issue** (Most Common)
```bash
# Check if you can reach pub.dev
ping pub.dev

# If blocked, set a different pub server (China/corporate networks)
flutter pub global activate fvm  # Use Flutter Version Manager to bypass issues
```

#### 2. **Clear Cache & Restart**
```bash
# Kill any stuck Flutter processes first
taskkill /F /IM flutter.exe  # Windows only - or use Activity Monitor on macOS

# Deep clean
flutter clean
rm -rf pubspec.lock
flutter pub get
```

#### 3. **Dart/Gradle Rebuild Issues**
```bash
# For Android-specific hangs
flutter clean
cd android
./gradlew clean  # Windows: .\gradlew.bat clean
cd ..
flutter pub get
flutter run -d chrome  # Try web first to isolate Android issues
```

#### 4. **Force Rebuild Dependencies**
```bash
flutter pub upgrade --major-versions
flutter pub get --offline  # Use offline mode if network is slow
```

#### 5. **Check Flutter Doctor** (if doctor itself hangs, use verbose)
```bash
flutter doctor -v  # Shows detailed diagnostics
```

#### 6. **Use Web as Default** (Fastest for iteration)
```bash
flutter run -d chrome --web-renderer=canvaskit
```

### Still Stuck?
1. **Check internet** - Verify you can access `pub.dev` directly
2. **Check antivirus/VPN** - May be blocking pub.dev
3. **Check disk space** - `pub get` needs ~500MB free
4. **Update Flutter** - `flutter upgrade` to latest stable

---

**Note**: Add more commands here as needed during development. Update with project-specific requirements.
