# git-sync-pgbouncer.sh — verification

This script ensures `psql` is available, reads the Postgres password from
`/var/run/pgbouncer/secret/password`, connects via the local UNIX socket (no
host/port), and creates `TABLE_NAME` (default `my_table`).

Quick verification steps:

1. Inspect password file
   - cat /var/run/pgbouncer/secret/password

3. Verify table exists (use the same password)
   - export PGPASSWORD="$(cat /var/run/pgbouncer/secret/password)"
   - psql -U postgres -d postgres -c "\dt"

Expected output examples:
- "\dt" should list `public.my_table` if created.
- "SELECT to_regclass(...)" should return the table name if present, otherwise NULL.

Troubleshooting:
- If `psql` is missing, the script tries to install a client using the system package manager (apt, apk, dnf, yum, zypper).
- Ensure the password file exists and contains the correct password.
- If using a different DB name or table name, set `PG_DB` and `TABLE_NAME` env vars before running:
  - PG_DB=mydb TABLE_NAME=events ./git-sync-pgbouncer.sh
````
