from django.core.management.base import BaseCommand
from django.db import connections

from management.db_backup import backup_database


class Command(BaseCommand):
    help = 'Back up the active Django SQLite/PostgreSQL database to a private file.'
    requires_migrations_checks = True

    def add_arguments(self, parser):
        parser.add_argument('--database', default='default')
        parser.add_argument('--backup-dir', help='Private backup directory (default: BASE_DIR/backups).')

    def handle(self, *args, **options):
        alias = options['database']
        connection = connections[alias]
        self.stdout.write(f"Database engine: {connection.settings_dict['ENGINE']}; name: {str(connection.settings_dict['NAME'])!r}")
        destination = backup_database(alias, options['backup_dir'])
        self.stdout.write(self.style.SUCCESS(f'Backup created: {destination}'))
