#!/bin/bash

# Script to load Docker images on remote server
# This script should be run on the remote server or via SSH
# Usage: ssh -i ~/.ssh/ACAIPortal.pem ubuntu@51.20.151.57 'bash -s' < ./scripts/load-images-remote.sh

set -e

REMOTE_PATH="/home/ubuntu/BrightEat"
IMAGES_DIR="$REMOTE_PATH/docker-images"

echo "📥 Loading Docker images on remote server..."

# Load images from tar files
if [ -f "$IMAGES_DIR/backend.tar" ]; then
    echo "Loading backend image..."
    docker load -i $IMAGES_DIR/backend.tar
fi

if [ -f "$IMAGES_DIR/frontend.tar" ]; then
    echo "Loading frontend image..."
    docker load -i $IMAGES_DIR/frontend.tar
fi

if [ -f "$IMAGES_DIR/flutter-pwa.tar" ]; then
    echo "Loading Flutter PWA image..."
    docker load -i $IMAGES_DIR/flutter-pwa.tar
fi

echo "✅ All images loaded successfully!"
echo "You can now use docker-compose with the pre-built images."

