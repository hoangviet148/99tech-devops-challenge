#!/usr/bin/env bash
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set app_password="$APP_DB_PASSWORD" --set dbname="$POSTGRES_DB" <<'SQL'
CREATE ROLE app LOGIN PASSWORD :'app_password' CONNECTION LIMIT 25;
GRANT CONNECT ON DATABASE :"dbname" TO app;
SQL
