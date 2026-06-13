#!/usr/bin/env bash
# Build (and optionally push) the patched seafile-pro-mc image.
#
# The build runs on the x86_64 deploy host (sf3) via DOCKER_HOST=ssh, because:
#   - the deploy target is x86_64 (this Mac is arm64),
#   - sf3 already has the base image layers cached,
#   - the resulting image lands on the daemon that will run it / push it.
#
# Usage:
#   ./docker/build.sh                 # build only
#   PUSH=1 ./docker/build.sh          # build + push (needs `docker login` on the build host)
set -euo pipefail

REGISTRY="${REGISTRY:-docker.iocloudhost.net}"
IMAGE="${IMAGE:-seafile/seafile-pro-mc}"
VERSION="${VERSION:-13.0.19-patched.2}"          # immutable per-patch revision
ROLLING="${ROLLING:-13.0-patched-latest}"        # rolling tag for Coolify to track
BUILD_HOST="${BUILD_HOST:-ssh://root@popos-sf3.com}"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FULL="${REGISTRY}/${IMAGE}:${VERSION}"
LATEST="${REGISTRY}/${IMAGE}:${ROLLING}"

echo ">> building ${FULL}"
echo "   (+ ${LATEST}) on ${BUILD_HOST}"
DOCKER_HOST="${BUILD_HOST}" docker build \
  -f "${REPO_ROOT}/docker/Dockerfile" \
  -t "${FULL}" -t "${LATEST}" \
  "${REPO_ROOT}"

if [[ "${PUSH:-0}" == "1" ]]; then
  echo ">> pushing to ${REGISTRY} (requires prior: docker login ${REGISTRY})"
  DOCKER_HOST="${BUILD_HOST}" docker push "${FULL}"
  DOCKER_HOST="${BUILD_HOST}" docker push "${LATEST}"
fi

echo ">> done: ${FULL}"
