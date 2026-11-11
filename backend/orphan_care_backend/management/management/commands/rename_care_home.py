from django.core.management.base import BaseCommand, CommandError
from django.db import connections, transaction
from django.utils import timezone

from management.db_backup import backup_database
from management.models import CareHome


TARGET_NAME = 'دار الطفل أبوهريدة'
TARGET_ADDRESS = 'طرابلس'


class Command(BaseCommand):
    help = 'Preview, then safely rename an existing care home while preserving its ID and relationships.'
    requires_migrations_checks = True

    def add_arguments(self, parser):
        parser.add_argument('--database', default='default')
        parser.add_argument('--care-home-id', type=int, help='Required when there is more than one care home.')
        parser.add_argument('--expected-name', help='Abort unless the selected record still has this exact name.')
        parser.add_argument('--apply', action='store_true', help='Create a verified backup and apply the update.')
        parser.add_argument('--backup-dir', help='Private backup directory (default: BASE_DIR/backups).')

    def handle(self, *args, **options):
        alias = options['database']
        connection = connections[alias]
        self.stdout.write(f"Database engine: {connection.settings_dict['ENGINE']}; name: {str(connection.settings_dict['NAME'])!r}")
        homes = CareHome.objects.using(alias)
        selected_id = options['care_home_id']
        if selected_id is None:
            choices = list(homes.order_by('id').values('id', 'name', 'address'))
            if not choices:
                raise CommandError('No care homes exist in this database. No record was created or changed.')
            if len(choices) > 1:
                for choice in choices:
                    self.stdout.write(f"ID={choice['id']}; name={choice['name']!r}; address={choice['address']!r}")
                raise CommandError('More than one care home exists. Re-run with --care-home-id after checking these records.')
            selected_id = choices[0]['id']
        try:
            home = homes.get(pk=selected_id)
        except CareHome.DoesNotExist:
            raise CommandError(f'Care home ID={selected_id} does not exist; no data was changed.') from None

        self._check_expected_name(home, options['expected_name'])
        self.stdout.write(f'ID={home.pk}; name={home.name!r}; address={home.address!r}')
        self.stdout.write(f'Target: {TARGET_NAME} – {TARGET_ADDRESS}')
        if home.name == TARGET_NAME and home.address == TARGET_ADDRESS:
            self.stdout.write(self.style.SUCCESS('Already up to date; no backup or database write was needed.'))
            return
        if not options['apply']:
            self.stdout.write('Dry run only: no data was changed and no backup was created. Add --apply to update this record.')
            return

        original = (home.name, home.address, home.updated_at)
        destination = backup_database(alias, options['backup_dir'])
        self.stdout.write(f'Backup created: {destination}')
        with transaction.atomic(using=alias):
            try:
                locked = homes.select_for_update().get(pk=home.pk)
            except CareHome.DoesNotExist:
                raise CommandError('The selected record was removed during backup. No rename was applied.') from None
            self._check_expected_name(locked, options['expected_name'])
            if (locked.name, locked.address, locked.updated_at) != original:
                raise CommandError('The selected record changed during backup. Review it and re-run; no rename was applied.')
            # QuerySet.update avoids signals or save hooks changing related records.
            homes.filter(pk=locked.pk).update(name=TARGET_NAME, address=TARGET_ADDRESS, updated_at=timezone.now())
        self.stdout.write(self.style.SUCCESS(f'Updated care home ID={home.pk}. Existing IDs and relationships were preserved.'))

    @staticmethod
    def _check_expected_name(home, expected_name):
        if expected_name is not None and home.name != expected_name:
            raise CommandError('The selected care home does not match --expected-name; no rename was applied.')
