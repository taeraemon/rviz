#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
docker compose -f docker/rolling/compose.yaml up -d
docker exec -it rviz-rolling bash
