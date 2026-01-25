#!/bin/bash

# TREE LAW ZOO Valley PostgreSQL Backup Script
# Backup database จาก External SSD

# Configuration
DB_NAME="tree_law_zoo_valley"
DB_USER="dave_macmini"
DB_HOST="localhost"
BACKUP_DIR="/Volumes/PostgreSQL/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/tree_law_zoo_valley_$DATE.sql"
COMPRESSED_FILE="$BACKUP_FILE.gz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔄 TREE LAW ZOO Valley PostgreSQL Backup${NC}"
echo -e "${YELLOW}========================================${NC}"

# Create backup directory if not exists
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    echo -e "${GREEN}✅ Created backup directory: $BACKUP_DIR${NC}"
fi

# Check if PostgreSQL is running
if ! pg_isready -h $DB_HOST -p 5432 -U $DB_USER; then
    echo -e "${RED}❌ PostgreSQL is not running${NC}"
    exit 1
fi

echo -e "${YELLOW}📦 Starting backup...${NC}"

# Create backup
pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Backup created: $BACKUP_FILE${NC}"
    
    # Compress backup
    gzip "$BACKUP_FILE"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Backup compressed: $COMPRESSED_FILE${NC}"
        
        # Get file size
        FILE_SIZE=$(du -h "$COMPRESSED_FILE" | cut -f1)
        echo -e "${GREEN}📊 Backup size: $FILE_SIZE${NC}"
        
        # Keep only last 7 days of backups
        find "$BACKUP_DIR" -name "tree_law_zoo_valley_*.sql.gz" -mtime +7 -delete
        echo -e "${YELLOW}🗑️  Cleaned up old backups (older than 7 days)${NC}"
        
        # List all backups
        echo -e "${YELLOW}📋 Current backups:${NC}"
        ls -lh "$BACKUP_DIR"/tree_law_zoo_valley_*.sql.gz | tail -5
        
        echo -e "${GREEN}🎉 Backup completed successfully!${NC}"
        
    else
        echo -e "${RED}❌ Failed to compress backup${NC}"
        exit 1
    fi
else
    echo -e "${RED}❌ Failed to create backup${NC}"
    exit 1
fi

# Check disk space
DISK_USAGE=$(df -h /Volumes/PostgreSQL | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 90 ]; then
    echo -e "${YELLOW}⚠️  Warning: External SSD is $DISK_USAGE% full${NC}"
fi

echo -e "${GREEN}✨ Backup process completed at $(date)${NC}"
