#!/bin/bash

# Complete deployment script: build, export, copy, and load images
# Usage: ./scripts/deploy-images.sh

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

echo "🚀 Starting deployment process..."

# Step 1: Build images
echo "🔨 Step 1: Building Docker images locally..."
docker build -t $BACKEND_IMAGE -f Dockerfile .
docker build -t $FRONTEND_IMAGE -f frontend/Dockerfile ./frontend
docker build -t $FLUTTER_PWA_IMAGE -f mobile/Dockerfile.pwa ./mobile
echo "✅ Images built successfully!"

# Step 2: Export images
echo "📦 Step 2: Exporting images to tar files..."
mkdir -p $EXPORT_DIR
docker save $BACKEND_IMAGE -o $EXPORT_DIR/backend.tar
docker save $FRONTEND_IMAGE -o $EXPORT_DIR/frontend.tar
docker save $FLUTTER_PWA_IMAGE -o $EXPORT_DIR/flutter-pwa.tar
echo "✅ Images exported!"

# Step 3: Create remote directory
echo "📁 Step 3: Creating remote directory..."
ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST "mkdir -p $REMOTE_PATH/docker-images"

# Step 4: Copy images to remote server
echo "📤 Step 4: Copying images to remote server..."
scp -i $SSH_KEY $EXPORT_DIR/*.tar $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH/docker-images/
echo "✅ Images copied to remote server!"

# Step 5: Load images on remote server
echo "📥 Step 5: Loading images on remote server..."
ssh -i $SSH_KEY $REMOTE_USER@$REMOTE_HOST << 'ENDSSH'
cd /home/ubuntu/BrightEat
if [ -f "docker-images/backend.tar" ]; then
    echo "Loading backend image..."
    docker load -i docker-images/backend.tar
fi
if [ -f "docker-images/frontend.tar" ]; then
    echo "Loading frontend image..."
    docker load -i docker-images/frontend.tar
fi
if [ -f "docker-images/flutter-pwa.tar" ]; then
    echo "Loading Flutter PWA image..."
    docker load -i docker-images/flutter-pwa.tar
fi
echo "✅ All images loaded on remote server!"
ENDSSH

# Step 6: Clean up local tar files (optional)
read -p "Do you want to clean up local tar files? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf $EXPORT_DIR
    echo "✅ Local tar files cleaned up!"
fi

echo "🎉 Deployment complete!"
echo ""
echo "Next steps on the remote server:"
echo "1. cd $REMOTE_PATH"
echo "2. docker-compose -f docker-compose.prod.yml down"
echo "3. docker-compose -f docker-compose.prod.yml up -d"

