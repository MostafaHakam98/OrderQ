# Flutter Installation Guide

## Step 1: Install Flutter

### Option A: Using Snap (Recommended for Ubuntu/Linux)
```bash
sudo snap install flutter --classic
```

### Option B: Manual Installation
1. Download Flutter SDK from: https://docs.flutter.dev/get-started/install/linux
2. Extract the archive:
   ```bash
   cd ~/development
   unzip ~/Downloads/flutter_linux_*.zip
   ```
3. Add Flutter to your PATH:
   ```bash
   export PATH="$PATH:`pwd`/flutter/bin"
   ```
   Add this to your `~/.bashrc` or `~/.zshrc` for permanent setup

## Step 2: Verify Installation
```bash
flutter doctor
```

This will check your setup and show what needs to be configured.

## Step 3: Install Dependencies
Once Flutter is installed, run:
```bash
cd /home/mostafahakam/Desktop/Personal/BrightEat/mobile
flutter pub get
```

## Step 4: Run the App

### For Android (Emulator or Physical Device)
```bash
flutter run
```

### For iOS (macOS only)
```bash
flutter run
```

## Additional Setup (if needed)

### Android Studio Setup
1. Install Android Studio from: https://developer.android.com/studio
2. Install Android SDK and tools
3. Accept Android licenses:
   ```bash
   flutter doctor --android-licenses
   ```

### VS Code Setup (Optional)
1. Install VS Code
2. Install Flutter extension
3. Install Dart extension

## Troubleshooting

If `flutter doctor` shows issues:
- **Android licenses**: Run `flutter doctor --android-licenses` and accept all
- **Missing tools**: Follow the suggestions from `flutter doctor`
- **PATH issues**: Ensure Flutter is in your PATH

## Quick Start After Installation

```bash
# Navigate to mobile directory
cd /home/mostafahakam/Desktop/Personal/BrightEat/mobile

# Get dependencies
flutter pub get

# Check for connected devices
flutter devices

# Run the app
flutter run
```

