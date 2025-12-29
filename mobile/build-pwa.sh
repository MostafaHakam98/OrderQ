#!/bin/bash

# Build script for Flutter PWA
# This script builds the Flutter web app and prepares it for deployment

set -e

echo "🚀 Building Flutter PWA..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    exit 1
fi

# Get Flutter dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Build for web
echo "🔨 Building Flutter web app..."
flutter build web --release --base-href / --web-renderer canvaskit

echo "✅ Build complete! Output is in build/web/"
echo ""
echo "To test locally, you can run:"
echo "  cd build/web && python3 -m http.server 8080"
echo ""
echo "To build Docker image:"
echo "  docker build -f Dockerfile.pwa -t orderq-pwa ."
echo ""
echo "To run with docker-compose:"
echo "  docker-compose -f docker-compose.pwa.yml up -d"

