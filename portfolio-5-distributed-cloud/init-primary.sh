#!/bin/bash
set -e
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres -c "CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replpass';"
echo "host replication replicator all scram-sha-256" >> "$PGDATA/pg_hba.conf"
