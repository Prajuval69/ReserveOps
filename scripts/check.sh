#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
(cd backend && RAILS_ENV=test bundle exec rails db:prepare && bundle exec rspec && bundle exec rails zeitwerk:check && bundle exec rubocop && bundle exec brakeman --no-pager --no-threads)
(cd frontend && npm run lint && npm run format:check && npm test && npm run build)
