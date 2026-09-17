from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APITestCase

from management.models import EmailVerificationCode, PasswordResetCode, PhoneVerificationCode, UserProfile
from management.views_api import (
    BrevoEmailDeliveryError,
    hash_email_verification_code,
    hash_reset_code,
    issue_email_verification_code,
)

User = get_user_model()


class EmailVerificationApiTests(APITestCase):
    def setUp(self):
        cache.clear()
        self.user = User.objects.create_user(
            username='email-verification', email='verify@example.com', password='StrongPass123!',
        )
        UserProfile.objects.create(user=self.user, phone_number='0912345678')
        email_patcher = patch('management.views_api._send_brevo_email')
        self.send_email = email_patcher.start()
        self.addCleanup(email_patcher.stop)
        sms_patcher = patch('management.sms.send_sms')
        self.send_sms = sms_patcher.start()
        self.addCleanup(sms_patcher.stop)

    def tearDown(self):
        self.send_sms.assert_not_called()

    def issue(self, code=123456):
        with patch('management.views_api.secrets.randbelow', return_value=code):
            return issue_email_verification_code(self.user)

    def verify(self, code='123456', **kwargs):
        return self.client.post(reverse('email_otp_verify'), {
            'email': self.user.email, 'code': code, **kwargs,
        }, format='json')

    def test_email_only_verification_and_replay_rejection(self):
        self.issue()
        self.assertEqual(self.send_email.call_args.kwargs['recipient_email'], self.user.email)
        response = self.verify(email=self.user.email.upper())
        self.assertEqual(response.status_code, 200)
        self.assertIn('access', response.data)
        self.user.profile.refresh_from_db()
        self.assertTrue(self.user.profile.is_verified)
        replay = self.verify()
        self.assertEqual(replay.status_code, 400)
        self.assertNotIn('access', replay.data)
        self.assertEqual(self.verify('999999').status_code, 400)
        self.assertFalse(PhoneVerificationCode.objects.exists())

    def test_expired_code_is_rejected(self):
        self.issue()
        EmailVerificationCode.objects.update(expires_at=timezone.now() - timezone.timedelta(seconds=1))
        self.assertEqual(self.verify().status_code, 400)

    def test_five_wrong_attempts_invalidate_code(self):
        self.issue()
        for _ in range(5):
            self.assertEqual(self.verify('999999').status_code, 400)
        record = EmailVerificationCode.objects.get()
        self.assertEqual(record.attempts, 5)
        self.assertIsNotNone(record.used_at)
        self.assertEqual(self.verify().status_code, 400)

    def test_resend_invalidates_previous_code(self):
        self.issue()
        with patch('management.views_api.secrets.randbelow', return_value=234567):
            response = self.client.post(reverse('email_otp_send'), {'email': self.user.email})
        self.assertEqual(response.status_code, 200)
        self.assertNotIn('234567', str(response.data))
        self.assertEqual(self.verify().status_code, 400)
        self.assertEqual(self.verify('234567').status_code, 200)

    def test_failed_resend_preserves_previous_code(self):
        self.issue()
        self.send_email.side_effect = BrevoEmailDeliveryError('test delivery failure')
        response = self.client.post(reverse('email_otp_send'), {'email': self.user.email})
        self.assertEqual(response.status_code, 503)
        self.assertEqual(EmailVerificationCode.objects.count(), 1)
        self.assertEqual(self.verify().status_code, 200)

    def test_email_and_user_id_must_match(self):
        self.issue()
        self.assertEqual(self.verify(user_id=self.user.pk + 100).status_code, 400)
        self.assertEqual(self.verify(email='other@example.com').status_code, 400)
        self.assertEqual(self.verify().status_code, 200)

    def test_code_is_bound_to_email_at_issue_time(self):
        self.issue()
        self.user.email = 'changed@example.com'
        self.user.save(update_fields=['email'])
        self.assertEqual(self.verify().status_code, 400)

    def test_inactive_user_cannot_verify_or_request_email(self):
        self.issue()
        self.send_email.reset_mock()
        self.user.is_active = False
        self.user.save(update_fields=['is_active'])
        self.assertEqual(self.verify().status_code, 400)
        response = self.client.post(reverse('email_otp_send'), {'email': self.user.email})
        self.assertEqual(response.status_code, 200)
        self.send_email.assert_not_called()

    def test_unknown_and_verified_emails_have_generic_resend_response(self):
        unknown = self.client.post(reverse('email_otp_send'), {'email': 'unknown@example.com'})
        self.user.profile.is_verified = True
        self.user.profile.save(update_fields=['is_verified'])
        verified = self.client.post(reverse('email_otp_send'), {'email': self.user.email})
        self.assertEqual(unknown.status_code, 200)
        self.assertEqual(unknown.data, verified.data)
        self.send_email.assert_not_called()
        self.assertEqual(self.verify().status_code, 400)

    def test_old_phone_routes_send_email_and_require_email_code(self):
        with patch('management.views_api.secrets.randbelow', return_value=123456):
            response = self.client.post(reverse('phone_otp_send'), {'email': self.user.email})
        self.assertEqual(response.status_code, 200)
        self.send_email.assert_called_once()
        phone_only = self.client.post(reverse('phone_otp_verify'), {
            'phone_number': '0912345678', 'code': '123456', 'user_id': self.user.pk,
        })
        self.assertEqual(phone_only.status_code, 400)
        email = self.client.post(reverse('phone_otp_verify'), {'email': self.user.email, 'code': '123456'})
        self.assertEqual(email.status_code, 200)

    def test_password_reset_code_cannot_verify_account(self):
        PasswordResetCode.objects.create(
            user=self.user, code_hash=hash_reset_code('123456'),
            expires_at=timezone.now() + timezone.timedelta(minutes=10),
        )
        self.assertNotEqual(hash_reset_code('123456'), hash_email_verification_code('123456'))
        self.assertEqual(self.verify().status_code, 400)

    def test_login_sends_email_until_verified_then_uses_password_only(self):
        data = {'email': self.user.email, 'password': 'StrongPass123!'}
        response = self.client.post(reverse('token_obtain_pair'), data)
        self.assertEqual(response.status_code, 403)
        self.assertTrue(response.data['requires_email_verification'])
        self.assertNotIn('access', response.data)
        self.send_email.assert_called_once()
        self.user.profile.is_verified = True
        self.user.profile.save(update_fields=['is_verified'])
        self.send_email.reset_mock()
        self.assertEqual(self.client.post(reverse('token_obtain_pair'), data).status_code, 200)
        self.send_email.assert_not_called()

    def test_invalid_email_and_code_are_rejected(self):
        self.assertEqual(self.verify(email='invalid').status_code, 400)
        self.assertEqual(self.verify(code='abc123').status_code, 400)
        self.assertEqual(self.verify(code='1234567').status_code, 400)
        self.assertEqual(self.client.post(reverse('email_otp_send'), {}).status_code, 400)

    def test_resend_rate_is_limited(self):
        for _ in range(8):
            response = self.client.post(reverse('email_otp_send'), {'email': 'unknown@example.com'})
            self.assertEqual(response.status_code, 200)
        response = self.client.post(reverse('email_otp_send'), {'email': 'unknown@example.com'})
        self.assertEqual(response.status_code, 429)
