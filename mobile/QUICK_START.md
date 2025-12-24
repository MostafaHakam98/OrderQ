# Quick Start Guide

## ✅ Configuration Status

The API URL is already configured correctly:
- **API Base URL**: `http://10.100.70.13:19992/api`
- **Location**: `lib/config/app_config.dart`

## 🚀 Setup Steps

### 1. Install Flutter (if not already installed)

**Quick Install (Ubuntu/Linux):**
```bash
sudo snap install flutter --classic
```

**Or follow the detailed guide**: See `INSTALL_FLUTTER.md`

### 2. Verify Flutter Installation
```bash
flutter doctor
```

### 3. Install Dependencies

**Option A: Use the setup script**
```bash
cd /home/mostafahakam/Desktop/Personal/BrightEat/mobile
./setup.sh
```

**Option B: Manual installation**
```bash
cd /home/mostafahakam/Desktop/Personal/BrightEat/mobile
flutter pub get
```

### 4. Check Available Devices
```bash
flutter devices
```

### 5. Run the App

**On connected device/emulator:**
```bash
flutter run
```

**On specific device:**
```bash
flutter run -d <device-id>
```

## 📱 Testing on Different Platforms

### Android Emulator
1. Start Android Studio
2. Open AVD Manager
3. Start an emulator
4. Run `flutter run`

### Physical Android Device
1. Enable Developer Options on your phone
2. Enable USB Debugging
3. Connect via USB
4. Run `flutter run`

### iOS Simulator (macOS only)
1. Open Xcode
2. Start iOS Simulator
3. Run `flutter run`

## 🔧 Troubleshooting

### Flutter not found
- Install Flutter using snap: `sudo snap install flutter --classic`
- Or add Flutter to your PATH

### Dependencies fail to install
- Run `flutter clean`
- Run `flutter pub get` again
- Check your internet connection

### No devices found
- For Android: Start an emulator or connect a device
- For iOS: Start iOS Simulator (macOS only)
- Run `flutter devices` to see available devices

### API connection issues
- Verify backend is running on `http://10.100.70.13:19992`
- For emulator: Use `http://10.0.2.2:19992/api` instead
- For iOS simulator: Use `http://localhost:19992/api` instead
- Update `lib/config/app_config.dart` if needed

## 📝 Current Configuration

- **API URL**: `http://10.100.70.13:19992/api` ✅
- **Project Location**: `/home/mostafahakam/Desktop/Personal/BrightEat/mobile`
- **Flutter SDK**: Required (>=3.0.0)

## 🎯 Next Steps After Running

1. Test login with your credentials
2. Create a test order
3. Verify all features work correctly
4. Customize UI/theme as needed

