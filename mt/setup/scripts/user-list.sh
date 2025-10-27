#!/bin/bash
# List users from Open WebUI database
# Usage: ./user-list.sh CONTAINER_NAME [filter]
# Filters: all (default), admin, non-admin, pending

CONTAINER_NAME="$1"
FILTER="${2:-all}"

if [ -z "$CONTAINER_NAME" ]; then
    echo "Error: Container name required"
    exit 1
fi

# Build SQL query based on filter
case "$FILTER" in
    admin)
        WHERE_CLAUSE="WHERE role = 'admin'"
        ;;
    non-admin)
        WHERE_CLAUSE="WHERE role = 'user' OR role = 'pending'"
        ;;
    pending)
        WHERE_CLAUSE="WHERE role = 'pending'"
        ;;
    user)
        WHERE_CLAUSE="WHERE role = 'user'"
        ;;
    *)
        WHERE_CLAUSE=""
        ;;
esac

# Query database and return JSON
docker exec "$CONTAINER_NAME" python3 -c "
import sqlite3
import json

conn = sqlite3.connect('/app/backend/data/webui.db')
cursor = conn.cursor()

query = 'SELECT id, email, role, created_at, name FROM user $WHERE_CLAUSE ORDER BY created_at'
cursor.execute(query)

users = []
for row in cursor.fetchall():
    users.append({
        'id': row[0],
        'email': row[1],
        'role': row[2],
        'created_at': row[3],
        'name': row[4] if row[4] else ''
    })

conn.close()
print(json.dumps(users))
"
