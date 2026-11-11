import io
import os
import sqlite3
import subprocess
import tempfile
from contextlib import closing
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import SimpleTestCase, TestCase

from management.db_backup import backup_database
from management.management.commands.rename_care_home import TARGET_ADDRESS, TARGET_NAME
from management.models import CareHome, Donation, Need, VisitHour, VolunteerApplication, VolunteerOpportunity


class RenameCareHomeTests(TestCase):
    def command(self, **options):
        output = io.StringIO()
        call_command('rename_care_home', stdout=output, **options)
        return output.getvalue()

    def home(self, **values):
        return CareHome.objects.create(name='Original care home', address='Old address', phone='0910000000', **values)

    def test_empty_database_fails_without_creating_a_home(self):
        with self.assertRaisesMessage(CommandError, 'No care homes'):
            self.command(apply=True)
        self.assertEqual(CareHome.objects.count(), 0)

    @patch('management.management.commands.rename_care_home.backup_database')
    def test_single_home_dry_run_has_no_writes_or_backup(self, backup):
        home = self.home()
        original = CareHome.objects.values().get(pk=home.pk)
        output = self.command()
        self.assertIn('Dry run only', output)
        self.assertIn(f'ID={home.pk}', output)
        self.assertIn('Database engine:', output)
        self.assertEqual(CareHome.objects.values().get(pk=home.pk), original)
        backup.assert_not_called()

    @patch('management.management.commands.rename_care_home.backup_database', return_value=Path('backups/test.sqlite3'))
    def test_single_home_apply_preserves_all_other_fields_and_relationships(self, backup):
        user = get_user_model().objects.create_user(username='rename-manager')
        home = self.home(manager=user, email='home@example.com', description='Keep this description', orphan_count=12)
        need = Need.objects.create(title='Books', category='education', required_quantity='10', care_home=home)
        opportunity = VolunteerOpportunity.objects.create(title='Teaching', description='Teach', care_home=home)
        donation = Donation.objects.create(user=user, need=need, donor_name='Donor')
        application = VolunteerApplication.objects.create(user=user, opportunity=opportunity)
        visit = VisitHour.objects.create(care_home=home, weekday=0, start_time='09:00', end_time='10:00')
        related = [need, opportunity, donation, application, visit]
        snapshots = [(obj.__class__, obj.pk, obj.__class__.objects.values().get(pk=obj.pk)) for obj in related]
        original_home = CareHome.objects.values().get(pk=home.pk)
        output = self.command(apply=True, expected_name=home.name)
        self.assertIn('Updated care home', output)
        backup.assert_called_once_with('default', None)
        home.refresh_from_db()
        self.assertEqual((home.name, home.address), (TARGET_NAME, TARGET_ADDRESS))
        new_home = CareHome.objects.values().get(pk=home.pk)
        for field, original_value in original_home.items():
            if field not in {'name', 'address', 'updated_at'}:
                self.assertEqual(new_home[field], original_value)
        for model, pk, original in snapshots:
            self.assertEqual(model.objects.values().get(pk=pk), original)
            self.assertEqual(model.objects.count(), 1)
        self.assertEqual(CareHome.objects.count(), 1)

    @patch('management.management.commands.rename_care_home.backup_database')
    def test_multiple_homes_require_an_explicit_id_and_list_choices(self, backup):
        first, second = self.home(), self.home()
        output = io.StringIO()
        with self.assertRaisesMessage(CommandError, '--care-home-id'):
            call_command('rename_care_home', apply=True, stdout=output)
        self.assertIn(f'ID={first.pk}', output.getvalue())
        self.assertIn(f'ID={second.pk}', output.getvalue())
        backup.assert_not_called()

    @patch('management.management.commands.rename_care_home.backup_database', return_value=Path('backups/test.sqlite3'))
    def test_explicit_id_changes_only_the_selected_home(self, backup):
        first, second = self.home(), self.home()
        original_first = CareHome.objects.values().get(pk=first.pk)
        self.command(care_home_id=second.pk, apply=True)
        second.refresh_from_db()
        self.assertEqual(second.name, TARGET_NAME)
        self.assertEqual(CareHome.objects.values().get(pk=first.pk), original_first)

    @patch('management.management.commands.rename_care_home.backup_database')
    def test_expected_name_mismatch_aborts_before_backup(self, backup):
        home = self.home()
        with self.assertRaisesMessage(CommandError, '--expected-name'):
            self.command(care_home_id=home.pk, expected_name='Another home', apply=True)
        home.refresh_from_db()
        self.assertEqual(home.name, 'Original care home')
        backup.assert_not_called()

    def test_nonexistent_explicit_id_fails_without_creation(self):
        with self.assertRaisesMessage(CommandError, 'does not exist'):
            self.command(care_home_id=9999, apply=True)
        self.assertEqual(CareHome.objects.count(), 0)

    @patch('management.management.commands.rename_care_home.backup_database', side_effect=CommandError('Backup unavailable'))
    def test_backup_failure_leaves_the_entire_record_unchanged(self, backup):
        home = self.home()
        original = CareHome.objects.values().get(pk=home.pk)
        with self.assertRaisesMessage(CommandError, 'Backup unavailable'):
            self.command(apply=True)
        self.assertEqual(CareHome.objects.values().get(pk=home.pk), original)

    @patch('management.management.commands.rename_care_home.backup_database')
    def test_already_renamed_home_is_idempotent_without_backup_or_writes(self, backup):
        home = CareHome.objects.create(name=TARGET_NAME, address=TARGET_ADDRESS, phone='0910000000')
        original = CareHome.objects.values().get(pk=home.pk)
        output = self.command(apply=True)
        self.assertIn('Already up to date', output)
        self.assertEqual(CareHome.objects.values().get(pk=home.pk), original)
        backup.assert_not_called()

    @patch('management.management.commands.rename_care_home.backup_database')
    def test_concurrent_record_change_during_backup_aborts_rename(self, backup):
        home = self.home()

        def concurrent_backup(*args):
            CareHome.objects.filter(pk=home.pk).update(address='Changed by another manager')
            return Path('backups/test.sqlite3')

        backup.side_effect = concurrent_backup
        with self.assertRaisesMessage(CommandError, 'changed during backup'):
            self.command(apply=True)
        home.refresh_from_db()
        self.assertEqual(home.name, 'Original care home')
        self.assertEqual(home.address, 'Changed by another manager')


class DatabaseBackupTests(SimpleTestCase):
    def test_sqlite_backup_contains_original_data_and_is_unique(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'production.sqlite3'
            with closing(sqlite3.connect(source)) as connection:
                connection.execute('CREATE TABLE care_home (id INTEGER PRIMARY KEY, name TEXT)')
                connection.execute('INSERT INTO care_home VALUES (7, ?)', ['Original home'])
                connection.commit()
            configured = SimpleNamespace(vendor='sqlite', settings_dict={'NAME': source})
            with patch('management.db_backup.connections', {'default': configured}):
                first = backup_database(backup_dir=root / 'backups')
                second = backup_database(backup_dir=root / 'backups')
            self.assertNotEqual(first, second)
            with closing(sqlite3.connect(first)) as snapshot:
                self.assertEqual(snapshot.execute('SELECT * FROM care_home').fetchall(), [(7, 'Original home')])
                self.assertEqual(snapshot.execute('PRAGMA integrity_check').fetchone(), ('ok',))
            with closing(sqlite3.connect(source)) as original:
                self.assertEqual(original.execute('SELECT COUNT(*) FROM care_home').fetchone(), (1,))

    def test_sqlite_missing_source_fails_without_leaving_a_partial_backup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            configured = SimpleNamespace(vendor='sqlite', settings_dict={'NAME': root / 'missing.sqlite3'})
            with patch('management.db_backup.connections', {'default': configured}):
                with self.assertRaisesMessage(CommandError, 'does not exist'):
                    backup_database(backup_dir=root / 'backups')
            self.assertEqual(list((root / 'backups').iterdir()), [])
            self.assertFalse((root / 'missing.sqlite3').exists())

    def test_in_memory_database_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            configured = SimpleNamespace(vendor='sqlite', settings_dict={'NAME': ':memory:'})
            with patch('management.db_backup.connections', {'default': configured}):
                with self.assertRaisesMessage(CommandError, 'file-backed'):
                    backup_database(backup_dir=directory)
            self.assertEqual(list(Path(directory).iterdir()), [])

    def test_postgresql_uses_active_settings_and_never_passes_credentials_as_arguments(self):
        configured = SimpleNamespace(vendor='postgresql', settings_dict={
            'NAME': 'actual_database', 'USER': 'actual_user', 'PASSWORD': 'private_password',
            'HOST': 'actual_host', 'PORT': '5432', 'OPTIONS': {'sslmode': 'require'},
        })

        def dump(arguments, **options):
            self.assertNotIn('private_password', ' '.join(arguments))
            self.assertEqual(options['env']['PGDATABASE'], 'actual_database')
            self.assertEqual(options['env']['PGUSER'], 'actual_user')
            self.assertEqual(options['env']['PGPASSWORD'], 'private_password')
            self.assertEqual(options['env']['PGHOST'], 'actual_host')
            self.assertEqual(options['env']['PGPORT'], '5432')
            self.assertEqual(options['env']['PGSSLMODE'], 'require')
            self.assertNotIn('PGHOSTADDR', options['env'])
            Path(arguments[arguments.index('--file') + 1]).write_bytes(b'PGDMP complete fixture')

        with tempfile.TemporaryDirectory() as directory:
            with patch.dict(os.environ, {'PGDATABASE': 'wrong_database', 'PGHOSTADDR': '192.0.2.1'}), patch('management.db_backup.connections', {'default': configured}), patch('management.db_backup.subprocess.run', side_effect=dump):
                backup = backup_database(backup_dir=directory)
            self.assertEqual(backup.read_bytes(), b'PGDMP complete fixture')

    def test_failed_pg_dump_removes_partial_file_and_hides_driver_secrets(self):
        configured = SimpleNamespace(vendor='postgresql', settings_dict={'NAME': 'actual_database'})
        failure = subprocess.CalledProcessError(1, ['pg_dump'], stderr=b'private_password')
        with tempfile.TemporaryDirectory() as directory:
            with patch('management.db_backup.connections', {'default': configured}), patch('management.db_backup.subprocess.run', side_effect=failure):
                with self.assertRaises(CommandError) as captured:
                    backup_database(backup_dir=directory)
            self.assertNotIn('private_password', str(captured.exception))
            self.assertEqual(list(Path(directory).iterdir()), [])
