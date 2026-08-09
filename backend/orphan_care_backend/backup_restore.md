# Backup and Restore

## SQLite Development Backup

```bash
python scripts/backup_db.py
python scripts/restore_db.py backups/sqlite_backup_YYYYMMDD_HHMMSS.sqlite3
```

## PostgreSQL Production Backup

Set `DATABASE_URL` and ensure `pg_dump` / `pg_restore` are installed in the runtime or maintenance container.

```bash
export DATABASE_URL=postgres://kanaf_user:strong-password@db:5432/kanaf_db
python scripts/backup_db.py
python scripts/restore_db.py backups/postgres_backup_YYYYMMDD_HHMMSS.dump
```

## Production Schedule

- Run backups at least daily for normal production traffic.
- Store backups outside the application container, preferably encrypted object storage.
- Keep a retention window such as 7 daily, 4 weekly, and 12 monthly backups.
- Test restore into a separate environment before relying on a backup policy.
