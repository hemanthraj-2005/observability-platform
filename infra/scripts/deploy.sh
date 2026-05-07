#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/observability-platform}"
COMPOSE_FILES="-f docker-compose.yml -f docker-compose.prod.yml"

cd "$APP_DIR"

if [ ! -f ".env" ]; then
  cp .env.example .env
fi

docker compose $COMPOSE_FILES pull
docker compose $COMPOSE_FILES up -d --build --remove-orphans
docker image prune -f

docker compose $COMPOSE_FILES ps
