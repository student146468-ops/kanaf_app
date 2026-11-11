"""Private backups of the database selected by Django's active settings."""

import os
import sqlite3
import subprocess
import tempfile
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path

from django.conf import settings
from django.core.management.base import CommandError
from django.db import connections


def backup_database(database='default', backup_dir=None):
    """Return a complete backup, or fail without leaving a partial backup behind."""
    connection = connections[database]
    config = connection.settings_dict
    if connection.vendor not in {'sqlite', 'postgresql'}:
        raise CommandError('Automatic backup supports SQLite and PostgreSQL only; no data was changed.')

    directory = Path(backup_dir) if backup_dir else Path(settings.BASE_DIR) / 'backups'
    destination = None
    try:
        directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        # Backups contain private user data. Restrict an existing backup directory too.
        directory.chmod(0o700)
        timestamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
        suffix = '.sqlite3' if connection.vendor == 'sqlite' else '.dump'
        descriptor, filename = tempfile.mkstemp(prefix=f'database_{timestamp}_', suffix=suffix, dir=directory)
        os.close(descriptor)
        destination = Path(filename)
        destination.chmod(0o600)

        if connection.vendor == 'sqlite':
            database_name = str(config['NAME'])
            if database_name == ':memory:' or database_name.startswith('file:'):
                raise CommandError('A file-backed SQLite database is required for a production backup.')
            source_path = Path(database_name).resolve()
            if not source_path.is_file():
                raise CommandError('The configured SQLite database file does not exist.')
            # mode=ro prevents a typo from silently creating an empty source database.
            with closing(sqlite3.connect(f'{source_path.as_uri()}?mode=ro', uri=True)) as source:
                with closing(sqlite3.connect(destination)) as target:
                    source.backup(target)
                    if target.execute('PRAGMA integrity_check').fetchone() != ('ok',):
                        raise CommandError('SQLite backup integrity verification failed.')
        else:
            _backup_postgresql(config, destination)

        if not destination.stat().st_size:
            raise CommandError('The database backup is empty.')
        return destination.resolve()
    except Exception as error:
        if destination is not None:
            destination.unlink(missing_ok=True)
        if isinstance(error, CommandError):
            raise
        # Database credentials can occur in driver/process errors; never echo them.
        raise CommandError('Database backup failed. Check the backup directory, database access, and backup tools; no data was changed.') from None


def _backup_postgresql(config, destination):
    option_environment = {
        'sslmode': 'PGSSLMODE',
        'sslcert': 'PGSSLCERT',
        'sslkey': 'PGSSLKEY',
        'sslrootcert': 'PGSSLROOTCERT',
        'sslcrl': 'PGSSLCRL',
        'service': 'PGSERVICE',
        'servicefile': 'PGSERVICEFILE',
        'passfile': 'PGPASSFILE',
        'connect_timeout': 'PGCONNECT_TIMEOUT',
        'options': 'PGOPTIONS',
        'target_session_attrs': 'PGTARGETSESSIONATTRS',
    }
    field_environment = {
        'NAME': 'PGDATABASE', 'USER': 'PGUSER', 'PASSWORD': 'PGPASSWORD',
        'HOST': 'PGHOST', 'PORT': 'PGPORT',
    }
    environment = os.environ.copy()
    for variable in {*field_environment.values(), *option_environment.values(), 'PGHOSTADDR'}:
        environment.pop(variable, None)
    for field, variable in field_environment.items():
        if config.get(field) not in (None, ''):
            environment[variable] = str(config[field])
    for option, variable in option_environment.items():
        value = config.get('OPTIONS', {}).get(option)
        if value not in (None, ''):
            environment[variable] = str(value)

    # The command line and captured output never expose the database password.
    subprocess.run(
        ['pg_dump', '--no-password', '--format=custom', '--file', str(destination)],
        env=environment, check=True, capture_output=True, timeout=600,
    )
