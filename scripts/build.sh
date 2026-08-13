#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Building Go API..."
mkdir -p bin
go build -o bin/server main.go

echo "==> Installing EDC Node bridge dependencies..."
if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm not found. Render build must have Node.js available, or run npm install locally in edc/."
  exit 1
fi

cd edc
if [ -f package-lock.json ]; then
  npm ci --omit=dev
else
  npm install --omit=dev
fi

echo "==> EDC bridge ready ($(node -v), mssql installed)"
