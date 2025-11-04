#!/usr/bin/env bash
set -euo pipefail

export PGPASSWORD="qrDy;GnX4QsKQ0UL"

TABLE_NAME="${TABLE_NAME:-my_table}"
PG_USER="${PG_USER:-postgres}"
PG_DB="${PG_DB:-postgres}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-60}"
RETRY_INTERVAL="${RETRY_INTERVAL:-2}"


SQL=$(cat <<EOF
CREATE TABLE IF NOT EXISTS "${TABLE_NAME}" (
  id SERIAL PRIMARY KEY,
  data TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
EOF
)

log "creating table ${TABLE_NAME} (if not exists)"
if psql -U "$PG_USER" -d "$PG_DB" -v ON_ERROR_STOP=1 --no-align -q -c "$SQL"; then
  log "table ${TABLE_NAME} created or already exists"
  exit 0
else
  log "failed to create table ${TABLE_NAME}"
  exit 6
fi
