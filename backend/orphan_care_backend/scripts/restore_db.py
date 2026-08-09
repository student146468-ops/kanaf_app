import os
import shutil
import subprocess
import sys
from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent


def restore_postgres(database_url, backup_path):
    subprocess.run(
        ['pg_restore', '--clean', '--if-exists', '--no-owner', '--dbname', database_url, str(backup_path)],
        check=True,
    )


def restore_sqlite(backup_path):
    destination = BASE_DIR / 'db.sqlite3'
    shutil.copy2(backup_path, destination)
    print(f'Restored database from {backup_path} to {destination}')


def main():
    backup_path = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    if not backup_path or not backup_path.exists():
        raise SystemExit('Usage: python scripts/restore_db.py <backup_file>')

    database_url = os.environ.get('DATABASE_URL', '').strip()
    if database_url:
        restore_postgres(database_url, backup_path)
        print(f'Restored PostgreSQL database from {backup_path}')
    else:
        restore_sqlite(backup_path)


if __name__ == '__main__':
    main()
