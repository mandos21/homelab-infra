markdown
# Keycloak Stack

This stack runs Keycloak and its Postgres database.

- Postgres: `keycloak-db` (image: `postgres:16`)
- Keycloak: `keycloak` (image: `quay.io/keycloak/keycloak:26.x`)
- DB volume: `keycloak-db-data` mounted at `/var/lib/postgresql/data`
- External access: proxied to `https://id.mdegenaro.com` via NPM (for now)

The `docker-compose.yml` for this stack is designed to be used with Portainer’s Git-backed stacks. Secrets such as `POSTGRES_PASSWORD` and `KC_BOOTSTRAP_ADMIN_PASSWORD` are provided via Portainer’s stack environment variables.

---

## Backups

Backups are handled by a separate script on the host (e.g. via Unraid User Scripts) using `pg_dump`.

Example backup script (runs on Unraid):

```bash
#!/bin/bash
BACKUP_DIR=/mnt/user/backups/keycloak
DATE=$(date +"%Y-%m-%d_%H-%M")
BACKUP_FILE="$BACKUP_DIR/keycloak_${DATE}.sql"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "----------------------------------------"
log "Starting Keycloak database backup job"
log "Backup directory: $BACKUP_DIR"

mkdir -p "$BACKUP_DIR" || { log "ERROR: Failed to create backup directory!"; exit 1; }

log "Creating PostgreSQL dump..."
if docker exec keycloak-db pg_dump -U keycloak keycloak > "$BACKUP_FILE"; then
  log "Backup successful: $BACKUP_FILE"
else
  log "ERROR: Backup failed!"
  rm -f "$BACKUP_FILE"
  exit 1
fi

log "Cleaning up old backups..."
DELETED=$(find "$BACKUP_DIR" -type f -mtime +14 -print -delete | wc -l)
log "Deleted $DELETED old backup file(s)"

log "Backup job completed successfully."
log "----------------------------------------"
````

Backups are stored as plain SQL dumps:

* Directory: `/mnt/user/backups/keycloak`
* Filenames: `keycloak_YYYY-MM-DD_HH-MM.sql`

---

## Restore procedure (from SQL dump)

**Warning:** Restoring a dump will overwrite the current Keycloak database contents. Make sure you really want to roll back before proceeding.

### 1. Identify the backup to restore

On the Unraid host:

```bash
ls -1 /mnt/user/backups/keycloak/
```

Pick the dump you want to restore, for example:

```text
/mnt/user/backups/keycloak/keycloak_2025-01-10_02-00.sql
```

Set an environment variable to make commands shorter:

```bash
BACKUP_FILE="/mnt/user/backups/keycloak/keycloak_2025-01-10_02-00.sql"
```

### 2. Stop Keycloak (optional but recommended)

To avoid Keycloak writing to the DB during restore:

```bash
docker stop keycloak
```

Leave `keycloak-db` running so we can connect to Postgres.

### 3. Drop and recreate the `keycloak` database (optional, but cleanest)

Connect to Postgres shell in the `keycloak-db` container:

```bash
docker exec -it keycloak-db psql -U keycloak
```

Inside `psql`:

```sql
DROP DATABASE keycloak;
CREATE DATABASE keycloak OWNER keycloak;
\q
```

This ensures you start with a clean DB before restoring.

### 4. Restore from the SQL dump

Run the restore from the host:

```bash
cat "$BACKUP_FILE" | docker exec -i keycloak-db psql -U keycloak keycloak
```

This streams the dump into `psql` running inside the `keycloak-db` container, restoring all schema and data into the freshly created `keycloak` database.

If the command exits with status `0`, the restore succeeded.

### 5. Start Keycloak again

```bash
docker start keycloak
```

Then check:

* Portainer: both `keycloak` and `keycloak-db` are running and healthy.
* `https://id.mdegenaro.com` loads as expected.
* Keycloak admin UI shows the expected realms, clients, and users.

---

## Notes

* The restore commands assume:

  * DB name: `keycloak`
  * DB user: `keycloak`
  * Container name for Postgres: `keycloak-db`
* If you change any of these in `docker-compose.yml`, update the backup and restore commands accordingly.
* For safety, you can create an additional “pre-restore” backup right before you restore:

  ```bash
  ./keycloak_pre_restore_backup.sh  # or manually run the backup script
  ```

  so you can undo a bad restore by restoring that latest snapshot if needed.

