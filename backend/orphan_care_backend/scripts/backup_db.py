import os
import shutil
import subprocess
from datetime import datetime
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent
BACKUP_DIR = BASE_DIR / 'backups'
BACKUP_DIR.mkdir(exist_ok=True)


def backup_postgres(database_url, destination):
    subprocess.run(
        ['pg_dump', '--format=custom', '--file', str(destination), database_url],
        check=True,
    )


def backup_sqlite(destination):
    source = BASE_DIR / 'db.sqlite3'
    if not source.exists():
        raise SystemExit('No SQLite database file found to back up.')
    shutil.copy2(source, destination)


def main():
    timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
    database_url = os.environ.get('DATABASE_URL', '').strip()

    if database_url:
        destination = BACKUP_DIR / f'postgres_backup_{timestamp}.dump'
        backup_postgres(database_url, destination)
    else:
        destination = BACKUP_DIR / f'sqlite_backup_{timestamp}.sqlite3'
        backup_sqlite(destination)

    print(f'Backup created: {destination}')


if __name__ == '__main__':
    main()
