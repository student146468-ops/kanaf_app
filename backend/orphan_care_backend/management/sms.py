"""SMS delivery helpers for phone OTP.

The production backend uses direct HTTPS calls instead of an extra Twilio
package so deployment does not require additional PythonAnywhere disk space.
"""
import base64
import json
import logging
from dataclasses import dataclass
from urllib import error, parse, request

from django.conf import settings

logger = logging.getLogger(__name__)


class SmsConfigurationError(RuntimeError):
    """Raised when SMS cannot be sent because credentials are missing."""


class SmsDeliveryError(RuntimeError):
    """Raised when the provider rejects or cannot complete the SMS request."""


@dataclass(frozen=True)
class SmsResult:
    provider: str
    message_id: str = ''
    status: str = ''


def normalize_phone_for_sms(phone_number):
    """Convert local Libyan mobile numbers such as 0912345678 to E.164."""
    phone = (phone_number or '').strip().replace(' ', '')
    if phone.startswith('+'):
        return phone
    if phone.startswith('00'):
        return f'+{phone[2:]}'
    if phone.startswith('0') and len(phone) == 10:
        return f'{settings.SMS_DEFAULT_COUNTRY_CODE}{phone[1:]}'
    return phone


def send_sms(*, phone_number, message):
    backend = settings.SMS_BACKEND.lower()
    destination = normalize_phone_for_sms(phone_number)

    if backend in {'development', 'console', 'log'}:
        if not settings.DEBUG:
            raise SmsConfigurationError(
                'Development SMS backend is not allowed when DEBUG=False.'
            )
        logger.info(
            'SMS development backend accepted message to phone=%s length=%s',
            _masked_phone(destination),
            len(message),
        )
        logger.warning(
            'DEVELOPMENT OTP SMS phone=%s message=%s',
            _masked_phone(destination),
            message,
        )
        return SmsResult(provider='development', status='logged')

    if backend == 'twilio':
        return _send_twilio_sms(destination, message)

    raise SmsConfigurationError(f'Unsupported SMS_BACKEND={settings.SMS_BACKEND!r}')


def _send_twilio_sms(destination, message):
    account_sid = settings.TWILIO_ACCOUNT_SID
    auth_token = settings.TWILIO_AUTH_TOKEN
    from_number = settings.TWILIO_FROM_NUMBER
    messaging_service_sid = settings.TWILIO_MESSAGING_SERVICE_SID

    if not account_sid or not auth_token:
        raise SmsConfigurationError('TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN are required.')
    if not from_number and not messaging_service_sid:
        raise SmsConfigurationError(
            'TWILIO_FROM_NUMBER or TWILIO_MESSAGING_SERVICE_SID is required.'
        )

    form = {
        'To': destination,
        'Body': message,
    }
    if messaging_service_sid:
        form['MessagingServiceSid'] = messaging_service_sid
    else:
        form['From'] = from_number

    url = f'https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json'
    payload = parse.urlencode(form).encode('utf-8')
    token = base64.b64encode(f'{account_sid}:{auth_token}'.encode('utf-8')).decode('ascii')
    req = request.Request(
        url,
        data=payload,
        headers={
            'Authorization': f'Basic {token}',
            'Content-Type': 'application/x-www-form-urlencoded',
        },
        method='POST',
    )

    try:
        with request.urlopen(req, timeout=settings.SMS_TIMEOUT) as response:
            body = response.read().decode('utf-8')
    except error.HTTPError as exc:
        body = exc.read().decode('utf-8', errors='replace')
        logger.warning(
            'Twilio SMS rejected phone=%s status=%s body=%s',
            _masked_phone(destination),
            exc.code,
            _safe_provider_body(body),
        )
        raise SmsDeliveryError(f'Twilio rejected SMS with HTTP {exc.code}') from exc
    except error.URLError as exc:
        logger.warning('Twilio SMS connection failed phone=%s error=%s', _masked_phone(destination), exc)
        raise SmsDeliveryError('Could not reach Twilio SMS API.') from exc

    try:
        data = json.loads(body)
    except json.JSONDecodeError as exc:
        logger.warning('Twilio SMS returned non-JSON response phone=%s', _masked_phone(destination))
        raise SmsDeliveryError('Twilio returned an invalid response.') from exc

    sid = str(data.get('sid') or '')
    status = str(data.get('status') or '')
    logger.info(
        'Twilio SMS accepted phone=%s sid=%s status=%s',
        _masked_phone(destination),
        sid,
        status,
    )
    return SmsResult(provider='twilio', message_id=sid, status=status)


def _masked_phone(phone_number):
    phone = str(phone_number or '')
    if len(phone) <= 4:
        return '****'
    return f'{phone[:4]}***{phone[-2:]}'


def _safe_provider_body(body):
    text = str(body or '')
    for secret in (settings.TWILIO_AUTH_TOKEN, settings.TWILIO_ACCOUNT_SID):
        if secret:
            text = text.replace(secret, '***')
    return text[:500]
