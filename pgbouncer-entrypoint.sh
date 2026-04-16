#!/bin/sh
# PgBouncer Entrypoint - Generate pgbouncer.ini from environment variables

set -e

# Default values
DATABASES_HOST=${DATABASES_HOST:-postgres}
DATABASES_PORT=${DATABASES_PORT:-5432}
DATABASES_USER=${DATABASES_USER:-ollama_user}
DATABASES_PASSWORD=${DATABASES_PASSWORD:-change_me_in_production}
DATABASES_DBNAME=${DATABASES_DBNAME:-ollama_db}
PGBOUNCER_POOL_MODE=${PGBOUNCER_POOL_MODE:-transaction}
PGBOUNCER_MAX_CLIENT_CONN=${PGBOUNCER_MAX_CLIENT_CONN:-1000}
PGBOUNCER_DEFAULT_POOL_SIZE=${PGBOUNCER_DEFAULT_POOL_SIZE:-25}
PGBOUNCER_MIN_POOL_SIZE=${PGBOUNCER_MIN_POOL_SIZE:-10}
PGBOUNCER_LISTEN_PORT=${PGBOUNCER_LISTEN_PORT:-16432}
PGBOUNCER_LOG_CONNECTIONS=${PGBOUNCER_LOG_CONNECTIONS:-0}
PGBOUNCER_LOG_DISCONNECTIONS=${PGBOUNCER_LOG_DISCONNECTIONS:-0}

# Generate pgbouncer.ini from environment variables
cat > /etc/pgbouncer/pgbouncer.ini <<EOF
[databases]
* = host=${DATABASES_HOST} port=${DATABASES_PORT} user=${DATABASES_USER} password=${DATABASES_PASSWORD} dbname=${DATABASES_DBNAME}

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = ${PGBOUNCER_LISTEN_PORT}
auth_type = any
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = ${PGBOUNCER_POOL_MODE}
max_client_conn = ${PGBOUNCER_MAX_CLIENT_CONN}
default_pool_size = ${PGBOUNCER_DEFAULT_POOL_SIZE}
min_pool_size = ${PGBOUNCER_MIN_POOL_SIZE}
reserve_pool_size = 5
reserve_pool_timeout = 3
max_db_connections = 100
max_user_connections = 0
ignore_startup_parameters = extra_float_digits
server_idle_timeout = 600
server_lifetime = 3600
server_connect_timeout = 15
query_timeout = 0
log_connections = ${PGBOUNCER_LOG_CONNECTIONS}
log_disconnections = ${PGBOUNCER_LOG_DISCONNECTIONS}
EOF

# Generate userlist.txt for pgbouncer
# Format: "user" "password"
cat > /etc/pgbouncer/userlist.txt <<EOF
"${DATABASES_USER}" "${DATABASES_PASSWORD}"
EOF

chmod 600 /etc/pgbouncer/userlist.txt

echo "PgBouncer configuration generated successfully"
echo "Database: ${DATABASES_DBNAME} on ${DATABASES_HOST}:${DATABASES_PORT}"
echo "Pool size: ${PGBOUNCER_DEFAULT_POOL_SIZE} (min: ${PGBOUNCER_MIN_POOL_SIZE})"

# Execute pgbouncer
exec /opt/pgbouncer/pgbouncer /etc/pgbouncer/pgbouncer.ini
