#!/usr/bin/env bash
set -euo pipefail

# -------------------------------
# Configuration
# -------------------------------
IMAGE_NAME="local/languagetool"
IMAGE_TAG="latest"
CONTAINER_NAME="languagetool"
HOST_PORT=9006
CONTAINER_PORT=9006

# -------------------------------
# Helper functions
# -------------------------------
log_info() {
  echo "[INFO] $*"
}

log_error() {
  echo "[ERROR] $*" >&2
}

log_success() {
  echo "[SUCCESS] $*"
}

# -------------------------------
# Pre-checks
# -------------------------------
if ! command -v docker >/dev/null 2>&1; then
  log_error "Docker is not installed or not in PATH."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  log_error "curl is required for health check but not found."
  exit 1
fi

# -------------------------------
# Build image
# -------------------------------
log_info "Building Docker image ${IMAGE_NAME}:${IMAGE_TAG} from Dockerfile..."
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

# -------------------------------
# Stop and remove existing container (if any)
# -------------------------------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log_info "Container ${CONTAINER_NAME} already exists. Stopping and removing it..."
  docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  docker rm "${CONTAINER_NAME}" >/dev/null 2>&1 || true
fi

# -------------------------------
# Run new container
# -------------------------------
log_info "Starting new container ${CONTAINER_NAME} on port ${HOST_PORT}..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  -p "${HOST_PORT}:${CONTAINER_PORT}" \
  --restart always \
  "${IMAGE_NAME}:${IMAGE_TAG}" >/dev/null

# -------------------------------
# Health check
# -------------------------------
log_info "Waiting for LanguageTool server to start..."
sleep 10

HEALTH_URL="http://localhost:${HOST_PORT}/v2/check?language=en-US&text=test"
log_info "Checking server health at ${HEALTH_URL}..."

if curl -fsS "${HEALTH_URL}" >/dev/null 2>&1; then
  log_success "LanguageTool server is up and responding on port ${HOST_PORT}."
  exit 0
else
  log_error "LanguageTool server did not respond correctly on port ${HOST_PORT}."
  log_error "Check container logs with: docker logs ${CONTAINER_NAME}"
  exit 1
fi

