#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${DEMO_PASSWORD:?Set DEMO_PASSWORD to a local password of at least 12 characters}"
for tool in ruby bundle node npm psql; do command -v "$tool" >/dev/null || { echo "Missing $tool; see README"; exit 1; }; done
(cd backend && bundle install && ruby bin/rails db:create db:migrate db:seed)
(cd frontend && npm ci)
