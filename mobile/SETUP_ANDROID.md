# Setting Up Android Emulator

## Current Status
✅ Flutter is installed  
✅ Dependencies are installed  
❌ Android SDK is not installed  
❌ No Android emulators available  

## Option 1: Run on Linux Desktop (Quickest)

You can run the app on Linux desktop right now without any additional setup:

```bash
cd /home/mostafahakam/Desktop/Personal/BrightEat/mobile
flutter run -d linux
```

This will launch the app as a Linux desktop application.

## Option 2: Set Up Android Emulator

### Step 1: Install Android Studio

1. Download Android Studio from: https://developer.android.com/studio
2. Extract and install:
   ```bash
   # Download the .tar.gz file
   cd ~/Downloads
   tar -xzf android-studio-*.tar.gz
   cd android-studio/bin
   ./studio.sh
   ```
3. Follow the setup wizard to install Android SDK

### Step 2: Configure Flutter to Use Android SDK

After Android Studio installation, run:
```bash
flutter doctor --android-licenses
# Accept all licenses by typing 'y' when prompted
```

### Step 3: Create an Android Virtual Device (AVD)

1. Open Android Studio
2. Go to **Tools** → **Device Manager**
3. Click **Create Device**
4. Select a device (e.g., Pixel 5)
5. Select a system image (e.g., Android 13 - API 33)
6. Click **Finish**

### Step 4: Start the Emulator

**From Android Studio:**
- Open Device Manager
- Click the ▶️ play button next to your AVD

**From Command Line:**
```bash
flutter emulators
flutter emulators --launch <emulator-id>
```

### Step 5: Run the App

```bash
cd /home/mostafahakam/Desktop/Personal/BrightEat/mobile
flutter run
```

## Option 3: Use Physical Android Device

### Enable Developer Options
1. Go to **Settings** → **About Phone**
2. Tap **Build Number** 7 times
3. Go back to **Settings** → **Developer Options**
4. Enable **USB Debugging**

### Connect Device
1. Connect your phone via USB
2. Accept the USB debugging prompt on your phone
3. Verify connection:
   ```bash
   flutter devices
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## Quick Commands

```bash
# Check available devices
flutter devices

# Run on Linux desktop
flutter run -d linux

# Run on Chrome (web)
flutter run -d chrome

# Run on specific device
flutter run -d <device-id>

# List emulators
flutter emulators

# Launch emulator
flutter emulators --launch <emulator-id>
```

## Troubleshooting

### Android SDK Not Found
- Install Android Studio
- Run `flutter config --android-sdk <path-to-sdk>` if SDK is in custom location
- Default location: `~/Android/Sdk`

### No Emulators Available
- Open Android Studio
- Go to Device Manager
- Create a new AVD

### USB Device Not Detected
- Enable USB Debugging on phone
- Install ADB: `sudo apt install android-tools-adb`
- Check connection: `adb devices`

## Recommended: Start with Linux Desktop

Since Linux desktop is already available, you can test the app immediately:

```bash
cd /home/mostafahakam/Desktop/Personal/BrightEat/mobile
flutter run -d linux
```

This will let you test all functionality without needing Android setup!

