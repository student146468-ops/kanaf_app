from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings

from management.models import CareHome, Donation, Need, VolunteerApplication, VolunteerOpportunity


@override_settings(STORAGES={
    'default': {'BACKEND': 'django.core.files.storage.FileSystemStorage'},
    'staticfiles': {'BACKEND': 'django.contrib.staticfiles.storage.StaticFilesStorage'},
})
class CareHomeDashboardTests(TestCase):
    def setUp(self):
        user = get_user_model().objects.create_user('dashboard-staff', is_staff=True)
        self.client.force_login(user)
        self.home = CareHome.objects.create(
            name='دار الطفل أبوهريدة', address='طرابلس', phone='0910000000',
        )

    def test_settings_uses_registered_home_and_admin_edit_link(self):
        response = self.client.get('/settings/')
        self.assertContains(response, self.home.name)
        self.assertContains(response, self.home.address)
        self.assertContains(response, f'/django-admin/management/carehome/{self.home.pk}/change/')
        self.assertNotContains(response, 'جمعية رعاية الأيتام')

    def test_settings_handles_no_homes(self):
        self.home.delete()
        self.assertContains(self.client.get('/settings/'), 'لا توجد دار رعاية مسجلة بعد.')

    def test_donation_and_application_display_current_linked_home(self):
        need = Need.objects.create(
            title='School supplies', category='education', required_quantity='10',
            care_home=self.home,
        )
        Donation.objects.create(need=need, donor_name='Donor', item_type='Books')
        opportunity = VolunteerOpportunity.objects.create(
            title='Teaching', description='Classroom support', care_home=self.home,
        )
        volunteer = get_user_model().objects.create_user('dashboard-volunteer')
        VolunteerApplication.objects.create(opportunity=opportunity, user=volunteer)
        for path in ('/donations/', '/volunteer-applications/'):
            with self.subTest(path=path):
                response = self.client.get(path)
                self.assertContains(response, self.home.name)
                self.assertContains(response, self.home.address)
        self.home.name = 'Updated home name'
        self.home.save(update_fields=['name'])
        self.assertContains(self.client.get('/donations/'), self.home.name)
