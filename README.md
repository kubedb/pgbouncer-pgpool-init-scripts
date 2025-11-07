# init-script.sh — verification

Quick verification steps:

3. Verify table exists (use the same password)
   - export PGPASSWORD="qrDy;GnX4QsKQ0UL"
   - psql -U postgres -d postgres -h localhost -p <db container port>
   - \dt

Expected output examples:
- "\dt" should list `public.my_table` if created.

Troubleshooting:
- Ensure the `psql` client is installed and available in PATH before running the script.
- Ensure the password file exists and contains the correct password.
- If using a different DB name or table name, set `PG_DB` and `TABLE_NAME` env vars before running:
  - PG_DB=mydb TABLE_NAME=events ./init-script.sh

