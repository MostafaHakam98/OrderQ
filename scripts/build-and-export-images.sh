#!/bin/bash

# Script to build Docker images locally and export them for remote deployment
# Usage: ./scripts/build-and-export-images.sh

set -e

REMOTE_USER="ubuntu"
REMOTE_HOST="51.20.151.57"
REMOTE_PATH="/home/ubuntu/BrightEat"
SSH_KEY="$HOME/.ssh/ACAIPortal.pem"
EXPORT_DIR="./docker-images"

# Image names and tags
BACKEND_IMAGE="brighteat-backend:latest"
FRONTEND_IMAGE="brighteat-frontend:latest"
FLUTTER_PWA_IMAGE="brighteat-flutter-pwa:latest"

echo "🔨 Building Docker images locally..."

# Build backend image
echo "Building backend image..."
docker build -t $BACKEND_IMAGE -f Dockerfile .

# Build frontend image
echo "Building frontend image..."
docker build -t $FRONTEND_IMAGE -f frontend/Dockerfile ./frontend

# Build Flutter PWA image
echo "Building Flutter PWA image..."
docker build -t $FLUTTER_PWA_IMAGE -f mobile/Dockerfile.pwa ./mobile

echo "✅ All images built successfully!"

# Create export directory
mkdir -p $EXPORT_DIR

# Export images to tar files
echo "📦 Exporting images to tar files..."
docker save $BACKEND_IMAGE -o $EXPORT_DIR/backend.tar
docker save $FRONTEND_IMAGE -o $EXPORT_DIR/frontend.tar
docker save $FLUTTER_PWA_IMAGE -o $EXPORT_DIR/flutter-pwa.tar

echo "✅ Images exported to $EXPORT_DIR/"

# Copy images to remote server
echo "📤 Copying images to remote server..."
scp -i $SSH_KEY $EXPORT_DIR/*.tar $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/docker-images/

echo "✅ Images copied to remote server!"

# Clean up local tar files (optional - comment out if you want to keep them)
# rm -rf $EXPORT_DIR

echo "🎉 Done! Images are ready on the remote server."
echo "Next step: Run ./scripts/load-images-remote.sh to load them on the remote server"

