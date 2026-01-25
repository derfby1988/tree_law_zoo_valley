#!/bin/bash

# TREE LAW ZOO Valley PostgreSQL Auto-start Script
# Start PostgreSQL with custom data directory

echo "🚀 Starting TREE LAW ZOO Valley PostgreSQL..."

# Check if PostgreSQL is already running
if pg_isready -h localhost -p 5432 -U dave_macmini; then
    echo "✅ PostgreSQL is already running"
    exit 0
fi

# Start PostgreSQL with custom data directory
pg_ctl -D /Volumes/PostgreSQL/postgresql-data-valley -l /Volumes/PostgreSQL/postgresql-data-valley/server.log start

# Wait for PostgreSQL to start
sleep 2

# Check if started successfully
if pg_isready -h localhost -p 5432 -U dave_macmini; then
    echo "✅ PostgreSQL started successfully"
    echo "📍 Database: tree_law_zoo_valley"
    echo "💾 Data Directory: /Volumes/PostgreSQL/postgresql-data-valley"
    echo "🔗 Connection: localhost:5432"
else
    echo "❌ Failed to start PostgreSQL"
    echo "📋 Check logs: /Volumes/PostgreSQL/postgresql-data-valley/server.log"
    exit 1
fi
