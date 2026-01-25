#!/bin/bash

# TREE LAW ZOO Valley PostgreSQL Stop Script
# Stop PostgreSQL gracefully

echo "🛑 Stopping TREE LAW ZOO Valley PostgreSQL..."

# Stop PostgreSQL
pg_ctl -D /Volumes/PostgreSQL/postgresql-data-valley stop

# Wait for PostgreSQL to stop
sleep 2

# Check if stopped successfully
if ! pg_isready -h localhost -p 5432 -U dave_macmini; then
    echo "✅ PostgreSQL stopped successfully"
else
    echo "❌ PostgreSQL is still running"
    exit 1
fi
