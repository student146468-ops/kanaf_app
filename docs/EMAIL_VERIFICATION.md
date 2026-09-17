# Email-only account verification

New accounts receive a six-digit code at their registered email address through
the existing Brevo HTTP email integration. The phone number remains contact data;
registration, login and resend do not send SMS. Password reset remains a separate
email flow. Existing verified accounts retain password-only login.

## Deployment

Deploy the backend before installing the updated Flutter APK. Old APKs still show
phone-verification wording and do not understand the new registration flag.
The old phone-otp URLs are email-only aliases, not SMS fallbacks.

1. Back up the production database and preserve any server-local Git changes.
2. Pull the shared main branch on PythonAnywhere.
3. Activate the same Python environment used by the web application, then run:

```bash
cd /home/kanafapp/kanaf-app/backend/orphan_care_backend
python manage.py migrate --noinput
python manage.py check
```

4. Configure `BREVO_API_KEY` and `BREVO_SENDER_EMAIL` in the server environment
   or its private `.env`. The sender must be verified in Brevo. Never commit
   credentials. The optional `EMAIL_OTP_THROTTLE` defaults to `8/hour` per IP,
   shared by send and verify requests.
5. Reload the web app from PythonAnywhere's Web tab.
6. Install the rebuilt APK and register a test account with an inbox you control.
   Confirm receipt, verify once, sign out, and sign back in using the password.

Automated tests mock email delivery. Passing tests do not establish that the
production credentials work or that a message reached an actual inbox.

## API contract

- Register returns `requires_email_verification`, `user_id`, `email` and `role`,
  without authentication tokens. Failed email delivery returns 503 and removes
  the newly created account so registration can be retried.
- Login to a pending account sends an email and returns 403 with
  `code: email_verification_required` and the same verification fields.
- `POST /api/auth/email-otp/send/` accepts `email`. Unknown, inactive and already
  verified accounts receive the same generic success response without an email.
- `POST /api/auth/email-otp/verify/` accepts `email`, `code` and optional `user_id`.
  Tokens are returned only after successful verification.

Codes expire after ten minutes, allow five wrong attempts, are stored hashed and
can be used only once. Resending invalidates the preceding code; a delivery failure
rolls back that replacement. Codes are bound to the destination email. Legacy SMS
codes and password-reset codes cannot verify an account.
