#!/usr/bin/env bash
set -euo pipefail

# Start a local Qdrant instance using Docker.
# Usage: bash scripts/start-qdrant.sh [version]
# Default version: latest

VERSION="${1:-latest}"
CONTAINER_NAME="qdrant-dev"
REST_PORT=6333
GRPC_PORT=6334
STORAGE_DIR="${QDRANT_STORAGE:-$(pwd)/qdrant_storage}"

if ! command -v docker &> /dev/null; then
    echo "error: docker is not installed"
    exit 1
fi

# Stop existing container if running
if docker ps -q --filter "name=${CONTAINER_NAME}" | grep -q .; then
    echo "stopping existing ${CONTAINER_NAME} container..."
    docker stop "${CONTAINER_NAME}" > /dev/null
    docker rm "${CONTAINER_NAME}" > /dev/null
fi

# Remove stopped container with same name
if docker ps -aq --filter "name=${CONTAINER_NAME}" | grep -q .; then
    docker rm "${CONTAINER_NAME}" > /dev/null
fi

echo "starting qdrant ${VERSION}..."
echo "  REST: http://localhost:${REST_PORT}"
echo "  gRPC: localhost:${GRPC_PORT}"
echo "  storage: ${STORAGE_DIR}"

mkdir -p "${STORAGE_DIR}"

docker run -d \
    --name "${CONTAINER_NAME}" \
    -p "${REST_PORT}:6333" \
    -p "${GRPC_PORT}:6334" \
    -v "${STORAGE_DIR}:/qdrant/storage:z" \
    "qdrant/qdrant:${VERSION}"

echo "qdrant is running (container: ${CONTAINER_NAME})"
