#!/bin/bash

# BrightEat Mobile App Setup Script

echo "========================================="
echo "BrightEat Mobile App Setup"
echo "========================================="
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed."
    echo ""
    echo "Please install Flutter first:"
    echo "  Option 1 (Snap): sudo snap install flutter --classic"
    echo "  Option 2: Follow instructions at https://docs.flutter.dev/get-started/install/linux"
    echo ""
    echo "After installation, run this script again."
    exit 1
fi

echo "✅ Flutter is installed"
echo ""

# Check Flutter version
FLUTTER_VERSION=$(flutter --version | head -n 1)
echo "Flutter version: $FLUTTER_VERSION"
echo ""

# Run flutter doctor
echo "Running flutter doctor to check setup..."
flutter doctor
echo ""

# Get dependencies
echo "Installing dependencies..."
flutter pub get

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Dependencies installed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Connect a device or start an emulator"
    echo "2. Run: flutter run"
    echo ""
    echo "To check available devices: flutter devices"
else
    echo ""
    echo "❌ Failed to install dependencies"
    exit 1
fi

