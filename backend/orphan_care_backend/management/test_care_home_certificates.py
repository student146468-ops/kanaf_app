from datetime import timedelta
from importlib import import_module
from types import SimpleNamespace
from unittest.mock import patch

from django.apps import apps
from django.contrib.auth import get_user_model
from django.db import connection
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from management.models import (
    CareHome,
    Donation,
    Need,
    VolunteerApplication,
    VolunteerOpportunity,
)
from management.serializers import DonationSerializer


class CareHomeCertificateTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        users = get_user_model()
        cls.manager = users.objects.create_user(username='certificate-manager')
        cls.volunteer = users.objects.create_user(username='certificate-volunteer')
        cls.staff = users.objects.create_user(username='certificate-staff', is_staff=True)
        cls.home = CareHome.objects.create(
            name='دار الطفل أبوهريدة',
            address='طرابلس',
            phone='0910000000',
            manager=cls.manager,
        )
        cls.opportunity = VolunteerOpportunity.objects.create(
            title='Reading session',
            description='Read with the children',
            care_home=cls.home,
            required_volunteers=3,
        )
        cls.need = Need.objects.create(
            title='Books',
            category='education',
            required_quantity='10',
            care_home=cls.home,
        )

    def setUp(self):
        self.client = APIClient()

    def application(self, **kwargs):
        return VolunteerApplication.objects.create(
            opportunity=self.opportunity, user=self.volunteer, **kwargs
        )

    def test_only_completed_applications_receive_an_issue_date(self):
        application = self.application()
        for state in ('pending', 'accepted', 'rejected'):
            application.status = state
            application.save(update_fields=['status'])
            application.refresh_from_db()
            self.assertIsNone(application.certificate_issued_at)

        application.status = 'completed'
        application.save(update_fields=['status'])
        application.refresh_from_db()
        self.assertIsNotNone(application.certificate_issued_at)
        self.assertIsNone(application.rating)

    def test_issue_date_survives_edits_and_status_changes(self):
        application = self.application(status='completed')
        issued_at = application.certificate_issued_at

        application.message = 'Edited after completion'
        application.rating = 5
        application.save()
        application.status = 'accepted'
        application.save(update_fields=['status', 'updated_at'])
        application.status = 'completed'
        with patch('management.models.timezone.now', return_value=issued_at + timedelta(days=2)):
            application.save(update_fields=['status', 'updated_at'])

        application.refresh_from_db()
        self.assertEqual(application.certificate_issued_at, issued_at)
        self.assertGreater(application.updated_at, issued_at)

    def test_stale_instance_cannot_clear_the_issue_date(self):
        application = self.application()
        stale = VolunteerApplication.objects.get(pk=application.pk)
        application.status = 'completed'
        application.save()
        stale.message = 'An older edit'
        stale.save()
        stale.refresh_from_db()
        self.assertEqual(stale.certificate_issued_at, application.certificate_issued_at)
        self.assertEqual(stale.status, 'pending')

    def test_partial_save_without_status_does_not_issue_a_certificate(self):
        application = self.application()
        application.status = 'completed'
        application.message = 'Still pending in the database'
        application.save(update_fields=['message'])
        application.refresh_from_db()
        self.assertEqual(application.status, 'pending')
        self.assertIsNone(application.certificate_issued_at)

    def test_manager_completion_sets_date_once_and_rating_keeps_it(self):
        application = self.application(status='accepted')
        self.client.force_authenticate(self.manager)
        endpoint = f'/api/volunteer-applications/{application.pk}'
        response = self.client.post(f'{endpoint}/complete/')
        self.assertEqual(response.status_code, 200)
        issued_at = response.json()['certificate_issued_at']
        self.assertIsNotNone(issued_at)
        self.assertEqual(response.json()['status'], 'completed')

        response = self.client.post(f'{endpoint}/rate/', {'rating': 4}, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['certificate_issued_at'], issued_at)
        response = self.client.post(f'{endpoint}/complete/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()['certificate_issued_at'], issued_at)

    def test_volunteer_cannot_confirm_own_participation(self):
        application = self.application(status='accepted')
        self.client.force_authenticate(self.volunteer)
        response = self.client.post(f'/api/volunteer-applications/{application.pk}/complete/')
        self.assertEqual(response.status_code, 403)
        application.refresh_from_db()
        self.assertEqual(application.status, 'accepted')
        self.assertIsNone(application.certificate_issued_at)

    def test_client_cannot_set_status_or_issue_date_on_create(self):
        self.client.force_authenticate(self.volunteer)
        response = self.client.post(
            '/api/volunteer-applications/',
            {
                'opportunity': self.opportunity.pk,
                'message': 'I can help',
                'status': 'completed',
                'certificate_issued_at': '2000-01-01T00:00:00Z',
            },
            format='json',
        )
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()['status'], 'pending')
        self.assertIsNone(response.json()['certificate_issued_at'])

    def test_api_issue_date_is_readonly_for_staff_too(self):
        application = self.application(status='completed')
        issued_at = application.certificate_issued_at
        self.client.force_authenticate(self.staff)
        response = self.client.patch(
            f'/api/volunteer-applications/{application.pk}/',
            {'certificate_issued_at': '2000-01-01T00:00:00Z', 'message': 'Reviewed'},
            format='json',
        )
        self.assertEqual(response.status_code, 200)
        application.refresh_from_db()
        self.assertEqual(application.certificate_issued_at, issued_at)
        self.assertEqual(application.message, 'Reviewed')

    def test_application_and_donation_identity_follow_the_linked_home(self):
        application = self.application(status='completed')
        donation = Donation.objects.create(
            need=self.need, user=self.volunteer, quantity='2', item_type='Books'
        )
        self.client.force_authenticate(self.volunteer)
        for expected_name in ('دار الطفل أبوهريدة', 'دار الطفل أبوهريدة – طرابلس'):
            self.home.name = expected_name
            self.home.save(update_fields=['name'])
            endpoints = (
                f'/api/volunteer-applications/{application.pk}/',
                f'/api/donations/{donation.pk}/',
            )
            for endpoint in endpoints:
                response = self.client.get(endpoint)
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json()['care_home_id'], self.home.pk)
                self.assertEqual(response.json()['care_home_name'], expected_name)
                self.assertEqual(response.json()['care_home_location'], 'طرابلس')

    def test_unlinked_historical_donations_have_no_invented_home(self):
        for need in (None, Need.objects.create(
            title='Historical books', category='education', required_quantity='3'
        )):
            donation = Donation.objects.create(need=need, quantity='1', item_type='Book')
            data = DonationSerializer(donation).data
            self.assertIsNone(data['care_home_id'])
            self.assertIsNone(data['care_home_name'])
            self.assertIsNone(data['care_home_location'])

    def test_migration_freezes_historical_updated_date_only_for_completed_rows(self):
        application = self.application()
        pending = VolunteerApplication.objects.create(
            opportunity=self.opportunity, user=self.staff
        )
        historical_date = timezone.now() - timedelta(days=90)
        VolunteerApplication.objects.filter(pk=application.pk).update(
            status='completed', updated_at=historical_date
        )
        migration = import_module(
            'management.migrations.0020_volunteerapplication_certificate_issued_at'
        )
        migration.preserve_existing_completion_dates(
            apps, SimpleNamespace(connection=connection)
        )
        application.refresh_from_db()
        self.assertEqual(application.certificate_issued_at, historical_date)
        pending.refresh_from_db()
        self.assertIsNone(pending.certificate_issued_at)

        # Applying the data operation again must not replace an existing date.
        VolunteerApplication.objects.filter(pk=application.pk).update(updated_at=timezone.now())
        migration.preserve_existing_completion_dates(
            apps, SimpleNamespace(connection=connection)
        )
        application.refresh_from_db()
        self.assertEqual(application.certificate_issued_at, historical_date)
