#!/bin/bash
set -e

# Build script for GPU-enabled Kubeflow notebook with Astral UV
# Usage: ./build.sh [TAG] [--push] [--scan]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAG="${1:-latest}"
PUSH_IMAGE=false
SCAN_IMAGE=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --push) PUSH_IMAGE=true ;;
    --scan) SCAN_IMAGE=true ;;
  esac
done

# Default Docker Hub repository (can be overridden by env var)
DOCKER_REGISTRY="${DOCKER_REGISTRY:-docker.io}"
DOCKER_USERNAME="${DOCKER_USERNAME:-yourusername}"
IMAGE_NAME="code-server-astraluv"
FULL_IMAGE="${DOCKER_REGISTRY}/${DOCKER_USERNAME}/${IMAGE_NAME}:${TAG}"

echo "================================"
echo "Building Docker Image"
echo "================================"
echo "Image: ${FULL_IMAGE}"
echo "Push: ${PUSH_IMAGE}"
echo "Scan: ${SCAN_IMAGE}"
echo ""

# Build the image
echo "📦 Building image..."
docker build \
  --tag "${FULL_IMAGE}" \
  --tag "${DOCKER_REGISTRY}/${DOCKER_USERNAME}/${IMAGE_NAME}:latest" \
  -f "${SCRIPT_DIR}/Dockerfile" \
  "${SCRIPT_DIR}"

echo "✅ Build complete!"

# Optional: Scan with Trivy
if [ "$SCAN_IMAGE" = true ]; then
  echo ""
  echo "🔍 Scanning image with Trivy..."

  if ! command -v trivy &> /dev/null; then
    echo "❌ Trivy not installed. Install from https://github.com/aquasecurity/trivy"
    exit 1
  fi

  trivy image --severity HIGH,CRITICAL "${FULL_IMAGE}"
  echo "✅ Scan complete!"
fi

# Optional: Push to registry
if [ "$PUSH_IMAGE" = true ]; then
  echo ""
  echo "📤 Pushing image to registry..."

  if ! docker info &> /dev/null; then
    echo "❌ Docker daemon not running or not authenticated"
    exit 1
  fi

  docker push "${FULL_IMAGE}"
  docker push "${DOCKER_REGISTRY}/${DOCKER_USERNAME}/${IMAGE_NAME}:latest"
  echo "✅ Push complete!"
fi

echo ""
echo "================================"
echo "Done!"
echo "================================"
