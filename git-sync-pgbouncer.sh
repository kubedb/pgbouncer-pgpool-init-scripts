#!/usr/bin/env bash
set -euo pipefail

TABLE_NAME="${TABLE_NAME:-my_table}"
PG_USER="${PG_USER:-postgres}"
PG_DB="${PG_DB:-postgres}"
PASSWORD_FILE="${PASSWORD_FILE:-/var/run/pgbouncer/secret/password}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-60}"
RETRY_INTERVAL="${RETRY_INTERVAL:-2}"

log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

install_psql() {
  if command -v psql >/dev/null 2>&1; then
    return 0
  fi
  log "psql not found, attempting to install client..."

  # helper to run package manager with sudo if needed
  run_install() {
    cmd="$1"
    shift
    if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
      sudo "$cmd" "$@"
    else
      "$cmd" "$@"
    fi
  }

  if command -v apt-get >/dev/null 2>&1; then
    run_install apt-get update -y
    run_install apt-get install -y postgresql-client || run_install apt-get install -y postgresql
  elif command -v apk >/dev/null 2>&1; then
    run_install apk add --no-cache postgresql-client
  elif command -v dnf >/dev/null 2>&1; then
    run_install dnf install -y postgresql
  elif command -v yum >/dev/null 2>&1; then
    run_install yum install -y postgresql
  elif command -v zypper >/dev/null 2>&1; then
    run_install zypper --non-interactive install postgresql
  else
    log "no known package manager found, cannot install psql"
    return 1
  fi

  if command -v psql >/dev/null 2>&1; then
    log "psql installed"
    return 0
  else
    log "psql installation attempted but psql still missing"
    return 1
  fi
}

read_password_file() {
  if [ ! -f "$PASSWORD_FILE" ]; then
    log "password file not found: $PASSWORD_FILE"
    return 1
  fi
  # read and trim newline
  PGPASSWORD="$(tr -d '\r\n' < "$PASSWORD_FILE" || true)"
  export PGPASSWORD
  if [ -z "${PGPASSWORD:-}" ]; then
    log "password file is empty"
    return 1
  fi
  return 0
}

wait_for_db() {
  local start ts
  start=$(date +%s)
  while true; do
    # connect using unix socket (no -h, no -p)
    if psql -U "$PG_USER" -d "$PG_DB" -c '\q' >/dev/null 2>&1; then
      return 0
    fi
    ts=$(( $(date +%s) - start ))
    if [ "$ts" -ge "$CONNECT_TIMEOUT" ]; then
      return 1
    fi
    sleep "$RETRY_INTERVAL"
  done
}

# Basic table name validation (letters, numbers, underscore, not starting with digit)
if ! [[ "$TABLE_NAME" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
  log "invalid TABLE_NAME: $TABLE_NAME"
  exit 2
fi

log "ensuring psql is available..."
if ! install_psql; then
  log "failed to ensure psql availability"
  exit 3
fi

log "reading password from $PASSWORD_FILE"
if ! read_password_file; then
  log "failed to read password"
  exit 4
fi

log "waiting for local DB socket (user=$PG_USER db=$PG_DB) up to ${CONNECT_TIMEOUT}s..."
if ! wait_for_db; then
  log "timed out waiting for DB"
  exit 5
fi

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
