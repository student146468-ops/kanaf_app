"""Active REST API views for the Kanaf backend."""
import hashlib
import logging
import re
import secrets

from django.conf import settings
from django.contrib.auth import authenticate, get_user_model
from django.core.mail import send_mail
from django.db import IntegrityError, connection
from django.db.models import Count, F, Q, Sum
from django.db.models.deletion import ProtectedError
from django.db import transaction
from django.utils import timezone
from django.utils.translation import gettext_lazy as _
from drf_spectacular.utils import extend_schema, inline_serializer
from rest_framework import filters, serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import AllowAny, BasePermission, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.token_blacklist.models import (
    BlacklistedToken,
    OutstandingToken,
)
from rest_framework_simplejwt.tokens import RefreshToken

from .models import Donation, InventoryItem, Need, Orphan, Sponsor, Volunteer
from .serializers import (
    CareHomeSerializer,
    DonationSerializer,
    InventorySerializer,
    NeedSerializer,
    NotificationSerializer,
    OrphanSerializer,
    SponsorSerializer,
    UserProfileSerializer,
    VisitHourSerializer,
    VolunteerApplicationSerializer,
    VolunteerSerializer,
    VolunteerOpportunitySerializer,
)
from .models import (
    CareHome,
    Notification,
    PasswordResetCode,
    PhoneVerificationCode,
    UserProfile,
    VisitHour,
    VolunteerApplication,
    VolunteerOpportunity,
)
from .sms import SmsConfigurationError, SmsDeliveryError, send_sms

User = get_user_model()
logger = logging.getLogger(__name__)
VERIFICATION_TITLE_PREFIX = 'Codex verification'
VERIFICATION_DESCRIPTION_PREFIX = 'Local verification'
PHONE_NUMBER_PATTERN = re.compile(r'^(091|092|093|094)[0-9]{7}$')
PHONE_EXISTS_MESSAGE = 'رقم الهاتف مستخدم بالفعل.'
EMAIL_EXISTS_MESSAGE = 'هذا البريد الإلكتروني مستخدم بالفعل.'
USERNAME_EXISTS_MESSAGE = 'اسم المستخدم مستخدم بالفعل.'
PHONE_VALIDATION_MESSAGE = 'رقم الهاتف يجب أن يتكون من 10 أرقام ويبدأ بـ 091 أو 092 أو 093 أو 094.'
PASSWORD_VALIDATION_MESSAGE = 'كلمة المرور ضعيفة. يجب أن تتكون من 8 خانات على الأقل وتحتوي على حروف وأرقام.'


def _is_valid_phone_number(phone_number):
    if not isinstance(phone_number, str):
        return False
    return bool(PHONE_NUMBER_PATTERN.fullmatch(phone_number))


def _is_valid_registration_password(password):
    if not isinstance(password, str):
        return False
    return (
        len(password) >= 8
        and re.search(r'[A-Za-z]', password)
        and re.search(r'[0-9]', password)
    )


def _without_verification_data(queryset):
    return queryset.exclude(
        title__istartswith=VERIFICATION_TITLE_PREFIX,
    ).exclude(
        description__istartswith=VERIFICATION_DESCRIPTION_PREFIX,
    )


def hash_reset_code(code):
    """يبصم الرمز مع SECRET_KEY كملح.

    ربط البصمة بمفتاح المشروع يعني أن جدول قوس قزح (rainbow table)
    لكل الرموز الممكنة من 6 أرقام — وهي مليون فقط — لا يفيد المهاجم
    ما لم يسرّب المفتاح أيضاً.
    """
    salted = f'{settings.SECRET_KEY}:{code}'.encode('utf-8')
    return hashlib.sha256(salted).hexdigest()


def hash_phone_verification_code(code):
    salted = f'{settings.SECRET_KEY}:phone:{code}'.encode('utf-8')
    return hashlib.sha256(salted).hexdigest()


def issue_password_reset_code(user):
    """يولّد رمزاً جديداً، يبطل ما قبله، ويرسله بالبريد.

    يعيد الرمز الصريح لأجل الاختبارات؛ لا يُرجَع أبداً في استجابة API.
    """
    # إبطال الرموز السابقة: طلب رمز جديد يجب أن يُلغي القديم، وإلا
    # بقيت عدة رموز صالحة في الوقت نفسه وتضاعف سطح الهجوم.
    PasswordResetCode.objects.filter(user=user, used_at__isnull=True).update(
        used_at=timezone.now(),
    )

    code = f'{secrets.randbelow(10 ** PasswordResetCode.CODE_LENGTH):0{PasswordResetCode.CODE_LENGTH}d}'
    now = timezone.now()
    PasswordResetCode.objects.create(
        user=user,
        code_hash=hash_reset_code(code),
        created_at=now,
        expires_at=now + PasswordResetCode.VALIDITY,
    )

    _send_password_reset_email(user, code)
    return code


def _send_password_reset_email(user, code):
    minutes = int(PasswordResetCode.VALIDITY.total_seconds() // 60)
    subject = 'رمز استعادة كلمة المرور - كَنَفْ'
    body = (
        f'مرحباً {user.get_full_name() or user.username},\n\n'
        f'رمز استعادة كلمة المرور الخاص بك هو: {code}\n'
        f'الرمز صالح لمدة {minutes} دقيقة، ولمرة واحدة فقط.\n\n'
        'إن لم تكن أنت من طلب هذا الرمز فتجاهل هذه الرسالة.\n\n'
        'فريق كَنَفْ'
    )
    try:
        send_mail(
            subject=subject,
            message=body,
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=False,
        )
    except Exception:
        # فشل الإرسال لا يجوز أن يسرّب للمستخدم أن البريد مسجّل، ولا أن
        # ينهار الطلب. نسجّله للمشرف ونُبقي الاستجابة عامة.
        logger.exception('Failed to send password reset email to user id=%s', user.id)


def consume_password_reset_code(user, code):
    """يتحقق من الرمز ويستهلكه. يعيد السجل عند النجاح و`None` عند الفشل.

    يجري داخل معاملة مع `select_for_update` حتى لا يستهلك طلبان
    متزامنان الرمز نفسه.
    """
    with transaction.atomic():
        record = (
            PasswordResetCode.objects
            .select_for_update()
            .filter(user=user, used_at__isnull=True)
            .order_by('-created_at')
            .first()
        )
        if record is None or record.is_expired:
            return None

        if record.attempts >= PasswordResetCode.MAX_ATTEMPTS:
            record.used_at = timezone.now()
            record.save(update_fields=['used_at'])
            return None

        # المقارنة الثابتة الزمن تمنع استنتاج الرمز من فروق التوقيت.
        if not secrets.compare_digest(record.code_hash, hash_reset_code(code)):
            record.attempts += 1
            update_fields = ['attempts']
            if record.attempts >= PasswordResetCode.MAX_ATTEMPTS:
                record.used_at = timezone.now()
                update_fields.append('used_at')
            record.save(update_fields=update_fields)
            return None

        record.used_at = timezone.now()
        record.save(update_fields=['used_at'])
        return record


def issue_phone_verification_code(user):
    profile = getattr(user, 'profile', None)
    phone_number = getattr(profile, 'phone_number', '') if profile else ''
    if not _is_valid_phone_number(phone_number):
        raise ValueError('User has no valid phone number for OTP.')

    PhoneVerificationCode.objects.filter(
        user=user,
        used_at__isnull=True,
    ).update(used_at=timezone.now())

    code = f'{secrets.randbelow(10 ** PhoneVerificationCode.CODE_LENGTH):0{PhoneVerificationCode.CODE_LENGTH}d}'
    now = timezone.now()
    record = PhoneVerificationCode.objects.create(
        user=user,
        phone_number=phone_number,
        code_hash=hash_phone_verification_code(code),
        created_at=now,
        expires_at=now + PhoneVerificationCode.VALIDITY,
    )

    minutes = int(PhoneVerificationCode.VALIDITY.total_seconds() // 60)
    message = f'رمز تحقق كَنَفْ هو {code}. صالح لمدة {minutes} دقائق.'
    logger.info(
        'Phone OTP send requested user_id=%s phone=%s backend=%s',
        user.id,
        _mask_phone(phone_number),
        settings.SMS_BACKEND,
    )
    result = send_sms(phone_number=phone_number, message=message)
    record.provider = result.provider
    record.provider_message_id = result.message_id
    record.save(update_fields=['provider', 'provider_message_id'])
    logger.info(
        'Phone OTP send accepted user_id=%s phone=%s provider=%s message_id=%s status=%s',
        user.id,
        _mask_phone(phone_number),
        result.provider,
        result.message_id,
        result.status,
    )
    return code


def consume_phone_verification_code(user, code):
    with transaction.atomic():
        record = (
            PhoneVerificationCode.objects
            .select_for_update()
            .filter(user=user, used_at__isnull=True)
            .order_by('-created_at')
            .first()
        )
        if record is None or record.is_expired:
            return None

        if record.attempts >= PhoneVerificationCode.MAX_ATTEMPTS:
            record.used_at = timezone.now()
            record.save(update_fields=['used_at'])
            return None

        if not secrets.compare_digest(
            record.code_hash,
            hash_phone_verification_code(code),
        ):
            record.attempts += 1
            update_fields = ['attempts']
            if record.attempts >= PhoneVerificationCode.MAX_ATTEMPTS:
                record.used_at = timezone.now()
                update_fields.append('used_at')
            record.save(update_fields=update_fields)
            return None

        record.used_at = timezone.now()
        record.save(update_fields=['used_at'])
        return record


def _mask_phone(phone_number):
    phone = str(phone_number or '')
    if len(phone) <= 4:
        return '****'
    return f'{phone[:3]}***{phone[-2:]}'


def _sms_error_response(exc):
    if isinstance(exc, SmsConfigurationError):
        logger.error('Phone OTP SMS configuration error: %s', exc)
        return Response(
            {
                'detail': 'خدمة SMS غير مهيأة. أضف بيانات Twilio في ملف البيئة ثم أعد المحاولة.',
                'code': 'sms_not_configured',
                'missing_settings': [
                    'TWILIO_ACCOUNT_SID',
                    'TWILIO_AUTH_TOKEN',
                    'TWILIO_FROM_NUMBER or TWILIO_MESSAGING_SERVICE_SID',
                ],
            },
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
        )

    logger.exception('Phone OTP SMS delivery failed: %s', exc)
    return Response(
        {
            'detail': 'تعذر إرسال رمز التحقق عبر SMS حالياً. حاول مرة أخرى لاحقاً.',
            'code': 'sms_delivery_failed',
        },
        status=status.HTTP_503_SERVICE_UNAVAILABLE,
    )


class StaffDeletePermission(BasePermission):
    message = 'Only staff users can delete this record.'

    def has_permission(self, request, view):
        if request.method == 'DELETE':
            return bool(request.user and request.user.is_authenticated and request.user.is_staff)
        return bool(request.user and request.user.is_authenticated)


class StaffWriteAuthenticatedReadPermission(BasePermission):
    message = 'Only staff users can update this record.'

    def has_permission(self, request, view):
        if not (request.user and request.user.is_authenticated):
            return False
        if request.method in ('GET', 'HEAD', 'OPTIONS', 'POST'):
            return True
        return request.user.is_staff


def care_home_for_user(user):
    """الدار التي يديرها هذا الحساب، أو None.

    مدير الدار ليس `is_staff`؛ صلاحياته محصورة في داره وحدها.
    """
    if not (user and user.is_authenticated):
        return None
    return CareHome.objects.filter(manager=user).first()


def user_manages_care_home(user, care_home):
    if not (user and user.is_authenticated):
        return False
    # الطاقم يملك كل شيء، بما فيه السجلات غير المرتبطة بأي دار.
    if user.is_staff:
        return True
    return care_home is not None and care_home.manager_id == user.id


class CareHomeManagerWritePermission(BasePermission):
    """قراءة لكل مسجَّل، وكتابة لمدير الدار أو الطاقم فقط."""

    message = 'Only the care home manager can modify this record.'

    def has_permission(self, request, view):
        if not (request.user and request.user.is_authenticated):
            return False
        if request.method in ('GET', 'HEAD', 'OPTIONS'):
            return True
        return request.user.is_staff or care_home_for_user(request.user) is not None

    def has_object_permission(self, request, view, obj):
        if request.method in ('GET', 'HEAD', 'OPTIONS'):
            return True
        return user_manages_care_home(request.user, getattr(obj, 'care_home', None))


class SafeDestroyMixin:
    protected_delete_detail = 'Cannot delete this record because it is linked to other saved records.'
    protect_related_on_delete = False
    protected_related_names = ()

    def _related_counts(self, instance):
        related_counts = {}
        for relation in instance._meta.related_objects:
            accessor = relation.get_accessor_name()
            if self.protected_related_names and accessor not in self.protected_related_names:
                continue
            manager = getattr(instance, accessor, None)
            if manager is None:
                continue
            try:
                count = manager.count()
            except Exception:
                continue
            if count:
                related_counts[accessor] = count
        return related_counts

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        related_counts = self._related_counts(instance) if self.protect_related_on_delete else {}
        if related_counts:
            logger.info(
                'Delete blocked for %s id=%s because of related records: %s',
                instance.__class__.__name__,
                instance.pk,
                related_counts,
            )
            return Response(
                {'detail': self.protected_delete_detail, 'related': related_counts},
                status=status.HTTP_409_CONFLICT,
            )

        try:
            self.perform_destroy(instance)
        except ProtectedError as exc:
            logger.warning(
                'Protected delete blocked for %s id=%s: %s',
                instance.__class__.__name__,
                instance.pk,
                exc,
                exc_info=True,
            )
            return Response({'detail': self.protected_delete_detail}, status=status.HTTP_409_CONFLICT)
        except IntegrityError as exc:
            logger.warning(
                'Database delete blocked for %s id=%s: %s',
                instance.__class__.__name__,
                instance.pk,
                exc,
                exc_info=True,
            )
            return Response(
                {'detail': 'Delete was not completed because of related database records.'},
                status=status.HTTP_409_CONFLICT,
            )
        except Exception as exc:
            logger.exception(
                'Unexpected delete failure for %s id=%s: %s',
                instance.__class__.__name__,
                instance.pk,
                exc,
            )
            return Response({'detail': 'Delete was not completed.'}, status=status.HTTP_400_BAD_REQUEST)

        return Response(status=status.HTTP_204_NO_CONTENT)


def _create_notification(user, notification_type, title, message):
    if not user:
        return
    Notification.objects.create(
        user=user,
        notification_type=notification_type,
        title=title,
        message=message,
    )
ORPHAN_WAITING_STATUSES = ['ينتظر كفالة', 'ظٹظ†طھط¸ط± ظƒظپط§ظ„ط©']
DONATION_ACTIVE_STATUSES = ['قيد التنفيذ', 'ظ‚ظٹط¯ ط§ظ„طھظ†ظپظٹط°']


def _profile_role(user):
    profile = getattr(user, 'profile', None)
    return getattr(profile, 'role', '')


def _is_accepted_status(value):
    return value in (VolunteerApplication.STATUS_ACCEPTED, 'approved')


AUTH_RESPONSE_SCHEMA = inline_serializer(
    name='AuthResponse',
    fields={
        'access': serializers.CharField(),
        'refresh': serializers.CharField(),
        'access_token': serializers.CharField(),
        'refresh_token': serializers.CharField(),
        'token': serializers.CharField(),
        'user': serializers.DictField(),
    },
)


def _user_payload(user):
    profile, _ = UserProfile.objects.get_or_create(user=user)
    return {
        'id': user.id,
        'username': user.username,
        'email': user.email,
        'first_name': user.first_name,
        'last_name': user.last_name,
        'is_staff': user.is_staff,
        'is_superuser': user.is_superuser,
        'role': profile.role,
        'phone_number': profile.phone_number,
        'is_verified': profile.is_verified,
    }


def _token_payload(user):
    refresh = RefreshToken.for_user(user)
    access_token = str(refresh.access_token)
    refresh_token = str(refresh)
    return {
        'access': access_token,
        'refresh': refresh_token,
        'access_token': access_token,
        'refresh_token': refresh_token,
        'token': access_token,
        'user': _user_payload(user),
    }


class RegisterView(APIView):
    permission_classes = [AllowAny]

    @extend_schema(
        request=inline_serializer(
            name='RegisterRequest',
            fields={
                'username': serializers.CharField(required=False),
                'email': serializers.EmailField(),
                'password': serializers.CharField(write_only=True),
                'password_confirm': serializers.CharField(write_only=True),
                'first_name': serializers.CharField(required=False),
                'last_name': serializers.CharField(required=False),
            },
        ),
        responses={201: AUTH_RESPONSE_SCHEMA},
    )
    def post(self, request):
        username = request.data.get('username', '').strip()
        email = request.data.get('email', '').strip().lower()
        password = request.data.get('password', '')
        password_confirm = request.data.get('password_confirm', '')
        first_name = request.data.get('first_name', '').strip()
        last_name = request.data.get('last_name', '').strip()
        phone_number = request.data.get('phone_number', '')

        if not email:
            return Response({'detail': _('email is required')}, status=status.HTTP_400_BAD_REQUEST)
        if not username:
            username = email
        if not all([username, password, password_confirm]):
            return Response({'detail': _('username, password and password_confirm are required')}, status=status.HTTP_400_BAD_REQUEST)
        if password != password_confirm:
            return Response({'detail': _('passwords do not match')}, status=status.HTTP_400_BAD_REQUEST)
        if User.objects.filter(email__iexact=email).exists():
            return Response(
                {'email': [EMAIL_EXISTS_MESSAGE], 'detail': EMAIL_EXISTS_MESSAGE},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if User.objects.filter(username__iexact=username).exists():
            return Response(
                {'username': [USERNAME_EXISTS_MESSAGE], 'detail': USERNAME_EXISTS_MESSAGE},
                status=status.HTTP_400_BAD_REQUEST,
            )
        role = request.data.get('role') or UserProfile.ROLE_DONOR
        valid_roles = {UserProfile.ROLE_DONOR, UserProfile.ROLE_VOLUNTEER}
        if role not in valid_roles:
            return Response({'detail': _('invalid role')}, status=status.HTTP_400_BAD_REQUEST)
        if not _is_valid_phone_number(phone_number):
            return Response({'detail': PHONE_VALIDATION_MESSAGE}, status=status.HTTP_400_BAD_REQUEST)
        if UserProfile.objects.filter(phone_number=phone_number).exists():
            return Response(
                {'phone_number': [PHONE_EXISTS_MESSAGE], 'detail': PHONE_EXISTS_MESSAGE},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not _is_valid_registration_password(password):
            return Response({'detail': PASSWORD_VALIDATION_MESSAGE}, status=status.HTTP_400_BAD_REQUEST)

        try:
            with transaction.atomic():
                user = User.objects.create_user(
                    username=username,
                    email=email,
                    password=password,
                    first_name=first_name,
                    last_name=last_name,
                )
                UserProfile.objects.create(
                    user=user,
                    role=role,
                    phone_number=phone_number,
                )
        except IntegrityError:
            if User.objects.filter(email__iexact=email).exists():
                return Response(
                    {'email': [EMAIL_EXISTS_MESSAGE], 'detail': EMAIL_EXISTS_MESSAGE},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if User.objects.filter(username__iexact=username).exists():
                return Response(
                    {'username': [USERNAME_EXISTS_MESSAGE], 'detail': USERNAME_EXISTS_MESSAGE},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if UserProfile.objects.filter(phone_number=phone_number).exists():
                return Response(
                    {'phone_number': [PHONE_EXISTS_MESSAGE], 'detail': PHONE_EXISTS_MESSAGE},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            return Response(
                {'detail': _('could not create account')},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            issue_phone_verification_code(user)
        except (SmsConfigurationError, SmsDeliveryError) as exc:
            logger.warning('Registration rolled back after SMS failure user_id=%s phone=%s', user.id, _mask_phone(phone_number))
            user.delete()
            return _sms_error_response(exc)

        logger.info('Registration created pending phone verification user_id=%s phone=%s', user.id, _mask_phone(phone_number))
        return Response(
            {
                'detail': 'تم إنشاء الحساب وإرسال رمز التحقق إلى رقم الهاتف.',
                'requires_phone_verification': True,
                'user_id': user.id,
                'email': user.email,
                'phone_number': phone_number,
                'role': role,
            },
            status=status.HTTP_201_CREATED,
        )


class PhoneOtpSendView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'phone_otp'

    @extend_schema(
        request=inline_serializer(
            name='PhoneOtpSendRequest',
            fields={
                'email': serializers.EmailField(required=False),
                'phone_number': serializers.CharField(),
            },
        ),
        responses={200: inline_serializer(
            name='PhoneOtpSendResponse',
            fields={
                'detail': serializers.CharField(),
                'requires_phone_verification': serializers.BooleanField(),
                'user_id': serializers.IntegerField(),
                'phone_number': serializers.CharField(),
            },
        )},
    )
    def post(self, request):
        phone_number = (request.data.get('phone_number') or '').strip()
        email = (request.data.get('email') or '').strip().lower()

        if not _is_valid_phone_number(phone_number):
            return Response({'detail': PHONE_VALIDATION_MESSAGE}, status=status.HTTP_400_BAD_REQUEST)

        queryset = User.objects.select_related('profile').filter(
            profile__phone_number=phone_number,
            profile__is_verified=False,
        )
        if email:
            queryset = queryset.filter(email__iexact=email)
        user = queryset.order_by('-id').first()
        if user is None:
            return Response(
                {'detail': 'لا يوجد حساب غير موثق بهذا الرقم.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            issue_phone_verification_code(user)
        except (SmsConfigurationError, SmsDeliveryError) as exc:
            return _sms_error_response(exc)

        return Response(
            {
                'detail': 'تم إرسال رمز تحقق جديد إلى رقم الهاتف.',
                'requires_phone_verification': True,
                'user_id': user.id,
                'phone_number': phone_number,
            },
            status=status.HTTP_200_OK,
        )


class PhoneOtpVerifyView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'phone_otp'

    INVALID_CODE_MESSAGE = 'رمز التحقق غير صحيح أو منتهي الصلاحية. اطلب رمزاً جديداً.'

    @extend_schema(
        request=inline_serializer(
            name='PhoneOtpVerifyRequest',
            fields={
                'user_id': serializers.IntegerField(required=False),
                'email': serializers.EmailField(required=False),
                'phone_number': serializers.CharField(),
                'code': serializers.CharField(),
            },
        ),
        responses={200: AUTH_RESPONSE_SCHEMA},
    )
    def post(self, request):
        user_id = request.data.get('user_id')
        email = (request.data.get('email') or '').strip().lower()
        phone_number = (request.data.get('phone_number') or '').strip()
        code = (request.data.get('code') or '').strip()

        errors = {}
        if not _is_valid_phone_number(phone_number):
            errors['phone_number'] = [PHONE_VALIDATION_MESSAGE]
        if not code:
            errors['code'] = ['رمز التحقق مطلوب.']
        elif not re.fullmatch(r'\d{6}', code):
            errors['code'] = ['رمز التحقق يتكون من 6 أرقام.']
        if errors:
            return Response(errors, status=status.HTTP_400_BAD_REQUEST)

        queryset = User.objects.select_related('profile').filter(
            profile__phone_number=phone_number,
        )
        if user_id:
            queryset = queryset.filter(id=user_id)
        if email:
            queryset = queryset.filter(email__iexact=email)
        user = queryset.order_by('-id').first()
        if user is None:
            logger.info('Phone OTP verify failed for unknown phone=%s', _mask_phone(phone_number))
            return Response({'detail': self.INVALID_CODE_MESSAGE}, status=status.HTTP_400_BAD_REQUEST)

        profile = user.profile
        if profile.is_verified:
            logger.info('Phone OTP verify skipped already verified user_id=%s', user.id)
            payload = _token_payload(user)
            payload.update({'id': user.id, 'username': user.username, 'email': user.email})
            return Response(payload, status=status.HTTP_200_OK)

        record = consume_phone_verification_code(user, code)
        if record is None:
            logger.warning('Phone OTP verify rejected user_id=%s phone=%s', user.id, _mask_phone(phone_number))
            return Response({'detail': self.INVALID_CODE_MESSAGE}, status=status.HTTP_400_BAD_REQUEST)

        profile.is_verified = True
        profile.save(update_fields=['is_verified', 'updated_at'])
        logger.info('Phone OTP verified user_id=%s phone=%s', user.id, _mask_phone(phone_number))

        payload = _token_payload(user)
        payload.update({'id': user.id, 'username': user.username, 'email': user.email})
        return Response(payload, status=status.HTTP_200_OK)


class LoginView(APIView):
    permission_classes = [AllowAny]

    @extend_schema(
        request=inline_serializer(
            name='LoginRequest',
            fields={
                'username': serializers.CharField(required=False),
                'email': serializers.EmailField(required=False),
                'password': serializers.CharField(write_only=True),
            },
        ),
        responses={200: AUTH_RESPONSE_SCHEMA},
    )
    def post(self, request):
        username_or_email = (request.data.get('username') or request.data.get('email') or '').strip()
        password = request.data.get('password', '')

        if not username_or_email or not password:
            return Response({'detail': _('username/email and password are required')}, status=status.HTTP_400_BAD_REQUEST)

        user = User.objects.filter(username__iexact=username_or_email).first()
        if user is None:
            user = User.objects.filter(email__iexact=username_or_email).first()
        if user is None:
            return Response({'detail': _('invalid credentials')}, status=status.HTTP_401_UNAUTHORIZED)

        authenticated_user = authenticate(request, username=user.username, password=password)
        if authenticated_user is None:
            return Response({'detail': _('invalid credentials')}, status=status.HTTP_401_UNAUTHORIZED)

        profile, _created_profile = UserProfile.objects.get_or_create(user=authenticated_user)
        if profile.phone_number and not profile.is_verified:
            return Response(
                {
                    'detail': 'رقم الهاتف غير موثق. أدخل رمز التحقق لإكمال الدخول.',
                    'code': 'phone_verification_required',
                    'requires_phone_verification': True,
                    'user_id': authenticated_user.id,
                    'email': authenticated_user.email,
                    'phone_number': profile.phone_number,
                    'role': profile.role,
                },
                status=status.HTTP_403_FORBIDDEN,
            )

        return Response(_token_payload(authenticated_user), status=status.HTTP_200_OK)


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(
        request=None,
        responses=inline_serializer(name='LogoutResponse', fields={'detail': serializers.CharField()}),
    )
    def post(self, request):
        return Response({'detail': _('logged out')}, status=status.HTTP_200_OK)


def _revoke_other_sessions(user):
    """يبطل كل رموز التحديث القائمة للمستخدم.

    ضروري بعد تغيير كلمة المرور أو البريد: لو بقيت جلسة مهاجم نشطة
    على جهاز آخر، فتغيير كلمة المرور لا يطرده — وهو بالضبط ما يفعله
    المستخدم عند شكّه في اختراق حسابه.
    """
    try:
        for token in OutstandingToken.objects.filter(user=user):
            BlacklistedToken.objects.get_or_create(token=token)
    except Exception:
        # تعطّل القائمة السوداء لا يجوز أن يمنع تغيير كلمة المرور نفسه.
        logger.exception('Failed to revoke sessions for user id=%s', user.id)


class ChangePasswordView(APIView):
    """تغيير كلمة المرور من داخل الحساب.

    يشترط كلمة المرور الحالية: بدونها يستطيع من يجد الجهاز مفتوحاً
    الاستيلاء على الحساب نهائياً.
    """

    permission_classes = [IsAuthenticated]

    @extend_schema(
        request=inline_serializer(
            name='ChangePasswordRequest',
            fields={
                'current_password': serializers.CharField(write_only=True),
                'new_password': serializers.CharField(write_only=True),
                'new_password_confirm': serializers.CharField(write_only=True),
            },
        ),
        responses={200: AUTH_RESPONSE_SCHEMA},
    )
    def post(self, request):
        user = request.user
        current_password = request.data.get('current_password') or ''
        new_password = request.data.get('new_password') or ''
        new_password_confirm = request.data.get('new_password_confirm') or ''

        errors = {}
        if not current_password:
            errors['current_password'] = ['أدخل كلمة المرور الحالية.']
        elif not user.check_password(current_password):
            errors['current_password'] = ['كلمة المرور الحالية غير صحيحة.']

        if not new_password:
            errors['new_password'] = ['أدخل كلمة المرور الجديدة.']
        elif not _is_valid_registration_password(new_password):
            errors['new_password'] = [PASSWORD_VALIDATION_MESSAGE]
        elif new_password != new_password_confirm:
            errors['new_password_confirm'] = ['كلمة المرور وتأكيدها غير متطابقين.']
        elif current_password == new_password:
            errors['new_password'] = ['كلمة المرور الجديدة مطابقة للحالية.']

        if errors:
            return Response(errors, status=status.HTTP_400_BAD_REQUEST)

        user.set_password(new_password)
        user.save(update_fields=['password'])
        _revoke_other_sessions(user)
        logger.info('Password changed for user id=%s', user.id)

        # نعيد رموزاً جديدة حتى لا يُطرد الجهاز الحالي بعد إبطال الجلسات.
        payload = _token_payload(user)
        payload['detail'] = 'تم تغيير كلمة المرور. سُجّل خروج الأجهزة الأخرى.'
        return Response(payload, status=status.HTTP_200_OK)


class ChangeEmailView(APIView):
    """تغيير البريد الإلكتروني للحساب.

    يشترط كلمة المرور الحالية أيضاً، لأن البريد هو وسيلة استعادة
    الحساب: من يغيّره يملك الحساب فعلياً.
    """

    permission_classes = [IsAuthenticated]

    @extend_schema(
        request=inline_serializer(
            name='ChangeEmailRequest',
            fields={
                'new_email': serializers.EmailField(),
                'current_password': serializers.CharField(write_only=True),
            },
        ),
        responses={200: AUTH_RESPONSE_SCHEMA},
    )
    def post(self, request):
        user = request.user
        new_email = (request.data.get('new_email') or '').strip()
        current_password = request.data.get('current_password') or ''

        errors = {}
        if not current_password:
            errors['current_password'] = ['أدخل كلمة المرور الحالية.']
        elif not user.check_password(current_password):
            errors['current_password'] = ['كلمة المرور الحالية غير صحيحة.']

        if not new_email:
            errors['new_email'] = ['أدخل البريد الإلكتروني الجديد.']
        elif not re.fullmatch(r'[^@\s]+@[^@\s]+\.[^@\s]+', new_email):
            errors['new_email'] = ['صيغة البريد الإلكتروني غير صحيحة.']
        elif new_email.lower() == (user.email or '').lower():
            errors['new_email'] = ['هذا هو بريدك الحالي بالفعل.']
        elif User.objects.filter(email__iexact=new_email).exclude(pk=user.pk).exists():
            errors['new_email'] = [EMAIL_EXISTS_MESSAGE]

        if errors:
            return Response(errors, status=status.HTTP_400_BAD_REQUEST)

        previous_email = user.email
        # التسجيل يضبط username = email، فإبقاؤهما متطابقين يمنع حالة
        # يسجل فيها المستخدم دخوله ببريده القديم إلى الأبد.
        username_follows_email = (user.username or '').lower() == (previous_email or '').lower()
        update_fields = ['email']
        user.email = new_email
        if username_follows_email and not User.objects.filter(
            username__iexact=new_email
        ).exclude(pk=user.pk).exists():
            user.username = new_email
            update_fields.append('username')

        try:
            user.save(update_fields=update_fields)
        except IntegrityError:
            return Response(
                {'new_email': [EMAIL_EXISTS_MESSAGE]},
                status=status.HTTP_400_BAD_REQUEST,
            )

        _revoke_other_sessions(user)
        _notify_email_changed(user, previous_email)
        logger.info('Email changed for user id=%s', user.id)

        payload = _token_payload(user)
        payload['detail'] = 'تم تحديث البريد الإلكتروني.'
        return Response(payload, status=status.HTTP_200_OK)


def _notify_email_changed(user, previous_email):
    """يُعلم البريد **القديم** بالتغيير.

    إشعار العنوان القديم هو ما يمنح المالك الحقيقي فرصة الانتباه إذا
    كان التغيير نتيجة اختراق. إشعار الجديد وحده عديم الفائدة أمنياً.
    """
    if not previous_email:
        return
    try:
        send_mail(
            subject='تم تغيير البريد الإلكتروني - كَنَفْ',
            message=(
                f'مرحباً {user.get_full_name() or user.username},\n\n'
                f'تم تغيير البريد الإلكتروني لحسابك إلى: {user.email}\n\n'
                'إن لم تكن أنت من أجرى هذا التغيير فتواصل مع الإدارة فوراً.\n\n'
                'فريق كَنَفْ'
            ),
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[previous_email],
            fail_silently=False,
        )
    except Exception:
        logger.exception('Failed to notify previous email for user id=%s', user.id)


class PasswordResetRequestView(APIView):
    """يطلب رمز استعادة ويرسله إلى بريد المستخدم.

    **يعيد 200 دائماً** ولو كان البريد غير مسجّل. الفرق في الاستجابة بين
    بريد موجود وغير موجود يمنح المهاجم أداة لجرد حسابات المنصة
    (account enumeration)، ولا يفيد المستخدم الشرعي بشيء.
    """

    permission_classes = [AllowAny]
    # تجاوز مقصود للحدود الافتراضية بحدّ أضيق خاص بهذه النقطة.
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'password_reset'

    GENERIC_MESSAGE = 'إن كان البريد مسجلاً لدينا فسيصلك رمز تحقق خلال دقائق.'

    @extend_schema(
        request=inline_serializer(
            name='PasswordResetRequest',
            fields={'email': serializers.EmailField()},
        ),
        responses={200: inline_serializer(
            name='PasswordResetRequestResponse',
            fields={'detail': serializers.CharField()},
        )},
    )
    def post(self, request):
        email = (request.data.get('email') or '').strip()
        if not email:
            return Response(
                {'email': ['البريد الإلكتروني مطلوب.']},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = User.objects.filter(email__iexact=email).first()
        if user is not None and user.is_active:
            issue_password_reset_code(user)
        else:
            logger.info('Password reset requested for unknown email')

        return Response({'detail': self.GENERIC_MESSAGE}, status=status.HTTP_200_OK)


class PasswordResetConfirmView(APIView):
    """يتحقق من الرمز ويعيّن كلمة المرور الجديدة."""

    permission_classes = [AllowAny]
    # تجاوز مقصود للحدود الافتراضية بحدّ أضيق خاص بهذه النقطة.
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'password_reset'

    INVALID_CODE_MESSAGE = 'الرمز غير صحيح أو منتهي الصلاحية. اطلب رمزاً جديداً.'

    @extend_schema(
        request=inline_serializer(
            name='PasswordResetConfirm',
            fields={
                'email': serializers.EmailField(),
                'code': serializers.CharField(),
                'password': serializers.CharField(write_only=True),
                'password_confirm': serializers.CharField(write_only=True),
            },
        ),
        responses={200: inline_serializer(
            name='PasswordResetConfirmResponse',
            fields={'detail': serializers.CharField()},
        )},
    )
    def post(self, request):
        email = (request.data.get('email') or '').strip()
        code = (request.data.get('code') or '').strip()
        password = request.data.get('password') or ''
        password_confirm = request.data.get('password_confirm') or ''

        errors = {}
        if not email:
            errors['email'] = ['البريد الإلكتروني مطلوب.']
        if not code:
            errors['code'] = ['رمز التحقق مطلوب.']
        if not password:
            errors['password'] = ['كلمة المرور مطلوبة.']
        elif not _is_valid_registration_password(password):
            errors['password'] = [PASSWORD_VALIDATION_MESSAGE]
        elif password != password_confirm:
            errors['password_confirm'] = ['كلمة المرور وتأكيدها غير متطابقين.']
        if errors:
            return Response(errors, status=status.HTTP_400_BAD_REQUEST)

        user = User.objects.filter(email__iexact=email).first()
        if user is None or not user.is_active:
            # نفس رسالة الرمز الخاطئ: لا نكشف وجود الحساب.
            return Response(
                {'detail': self.INVALID_CODE_MESSAGE},
                status=status.HTTP_400_BAD_REQUEST,
            )

        record = consume_password_reset_code(user, code)
        if record is None:
            return Response(
                {'detail': self.INVALID_CODE_MESSAGE},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.set_password(password)
        user.save(update_fields=['password'])
        logger.info('Password reset completed for user id=%s', user.id)

        return Response(
            {'detail': 'تم تحديث كلمة المرور. يمكنك تسجيل الدخول الآن.'},
            status=status.HTTP_200_OK,
        )


class HealthView(APIView):
    permission_classes = [AllowAny]

    @extend_schema(responses=inline_serializer(name='HealthResponse', fields={'status': serializers.CharField(), 'database': serializers.CharField()}))
    def get(self, request):
        try:
            connection.ensure_connection()
        except Exception:
            return Response({'status': 'error', 'database': 'unavailable'}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
        return Response({'status': 'ok', 'database': 'ok'})


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(responses=inline_serializer(name='MeResponse', fields={'id': serializers.IntegerField()}))
    def get(self, request):
        return Response(_user_payload(request.user))


class OrphanViewSet(SafeDestroyMixin, viewsets.ModelViewSet):
    queryset = Orphan.objects.all()
    serializer_class = OrphanSerializer
    permission_classes = [StaffDeletePermission]
    pagination_class = None
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name', 'status']
    ordering_fields = ['id', 'name', 'age', 'status']
    ordering = ['-id']

    @action(detail=False, methods=['get'])
    def statistics(self, request):
        total = Orphan.objects.count()
        by_status = Orphan.objects.values('status').annotate(count=Count('id'))
        return Response({'total': total, 'by_status': list(by_status)})


class DonationViewSet(SafeDestroyMixin, viewsets.ModelViewSet):
    queryset = Donation.objects.all()
    serializer_class = DonationSerializer
    permission_classes = [StaffWriteAuthenticatedReadPermission]
    pagination_class = None
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['donor_name', 'item_type', 'status', 'description', 'need__title']
    ordering_fields = ['id', 'status', 'donation_date']
    ordering = ['-donation_date', '-id']

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return Donation.objects.none()
        queryset = Donation.objects.select_related('user', 'need')
        if self.request.user.is_staff:
            return queryset
        return queryset.filter(user=self.request.user)

    def perform_create(self, serializer):
        if _profile_role(self.request.user) != UserProfile.ROLE_DONOR:
            raise serializers.ValidationError({'detail': 'Only donor users can create donations.'})
        donor_name = (
            self.request.user.get_full_name()
            or self.request.user.username
            or self.request.user.email
        )
        serializer.save(
            user=self.request.user,
            donor_name=donor_name,
            status=Donation.STATUS_PENDING,
        )

    def perform_update(self, serializer):
        previous_status = serializer.instance.status
        donation = serializer.save()
        if donation.user_id and previous_status != donation.status:
            _create_notification(
                donation.user,
                Notification.TYPE_DONATION,
                'Donation status updated',
                f'Your donation request is now {donation.status}.',
            )

    @action(detail=False, methods=['get'], url_path='my-donations')
    def my_donations(self, request):
        donations = self.get_queryset()
        serializer = self.get_serializer(donations, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def statistics(self, request):
        queryset = self.get_queryset()
        total = queryset.count()
        by_status = queryset.values('status').annotate(count=Count('id'))
        total_amount = queryset.aggregate(Sum('amount'))['amount__sum'] or 0
        return Response({'total': total, 'total_amount': total_amount, 'by_status': list(by_status)})


class VolunteerViewSet(SafeDestroyMixin, viewsets.ModelViewSet):
    queryset = Volunteer.objects.all()
    serializer_class = VolunteerSerializer
    permission_classes = [StaffDeletePermission]
    pagination_class = None
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name', 'specialty']
    ordering_fields = ['id', 'name', 'points']
    ordering = ['-points']

    @action(detail=False, methods=['post'])
    def apply(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['get'])
    def statistics(self, request):
        total = Volunteer.objects.count()
        total_points = Volunteer.objects.aggregate(Sum('points'))['points__sum'] or 0
        return Response({
            'total': total,
            'total_points': total_points,
            'average_points': total_points / total if total > 0 else 0,
        })


class SponsorViewSet(SafeDestroyMixin, viewsets.ModelViewSet):
    queryset = Sponsor.objects.all()
    serializer_class = SponsorSerializer
    permission_classes = [StaffDeletePermission]
    pagination_class = None
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name', 'phone']
    ordering_fields = ['id', 'name']
    ordering = ['-id']


class InventoryViewSet(SafeDestroyMixin, viewsets.ModelViewSet):
    queryset = InventoryItem.objects.all()
    serializer_class = InventorySerializer
    permission_classes = [StaffDeletePermission]
    pagination_class = None
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['item_name']
    ordering_fields = ['id', 'quantity']
    ordering = ['-id']

    @action(detail=False, methods=['get'])
    def statistics(self, request):
        total_items = InventoryItem.objects.count()
        total_quantity = InventoryItem.objects.aggregate(Sum('quantity'))['quantity__sum'] or 0
        return Response({'total_items': total_items, 'total_quantity': total_quantity})


class NeedViewSet(SafeDestroyMixin, viewsets.ModelViewSet):
    queryset = _without_verification_data(
        Need.objects.exclude(status=Need.STATUS_ARCHIVED)
    )
    serializer_class = NeedSerializer
    permission_classes = [StaffDeletePermission]
    pagination_class = None
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['title', 'description', 'category', 'priority', 'status']
    ordering_fields = ['id', 'title', 'priority', 'deadline', 'created_at']
    ordering = ['-created_at']

    def perform_create(self, serializer):
        # نربط الاحتياج بدار منشئه تلقائياً حتى يظهر في ملف الدار
        # وفي تصفح المتبرع، بدل أن يبقى معلّقاً بلا صاحب.
        serializer.save(
            created_by=self.request.user,
            care_home=care_home_for_user(self.request.user),
        )

    def destroy(self, request, *args, **kwargs):
        need = self.get_object()
        need.status = Need.STATUS_ARCHIVED
        need.save(update_fields=['status', 'updated_at'])
        logger.info('Need id=%s was archived through DELETE by user id=%s', need.pk, request.user.pk)
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=['post'])
    def archive(self, request, pk=None):
        need = self.get_object()
        need.status = Need.STATUS_ARCHIVED
        need.save(update_fields=['status', 'updated_at'])
        return Response(self.get_serializer(need).data)

    @action(detail=False, methods=['get'])
    def statistics(self, request):
        total = self.get_queryset().count()
        by_status = Need.objects.values('status').annotate(count=Count('id'))
        return Response({'total': total, 'by_status': list(by_status)})


class VolunteerOpportunityViewSet(SafeDestroyMixin, viewsets.ModelViewSet):
    queryset = _without_verification_data(
        VolunteerOpportunity.objects.select_related('care_home')
    )
    serializer_class = VolunteerOpportunitySerializer
    permission_classes = [StaffDeletePermission]
    protect_related_on_delete = True
    protected_related_names = ('applications',)
    protected_delete_detail = 'Cannot delete this volunteer opportunity because it has saved applications.'
    pagination_class = None
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['title', 'description', 'location', 'status']
    ordering_fields = ['id', 'title', 'start_date', 'status']
    ordering = ['-start_date', '-created_at']

    def perform_create(self, serializer):
        serializer.save(care_home=care_home_for_user(self.request.user))

    @action(detail=True, methods=['post'])
    def apply(self, request, pk=None):
        if _profile_role(request.user) != UserProfile.ROLE_VOLUNTEER:
            return Response({'detail': 'Only volunteer users can apply to opportunities.'}, status=status.HTTP_403_FORBIDDEN)
        opportunity = self.get_object()
        application, created = VolunteerApplication.objects.get_or_create(
            opportunity=opportunity,
            user=request.user,
            defaults={'message': request.data.get('message', '')},
        )
        serializer = VolunteerApplicationSerializer(application)
        return Response(serializer.data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK)


class VolunteerApplicationViewSet(SafeDestroyMixin, viewsets.ModelViewSet):
    serializer_class = VolunteerApplicationSerializer
    permission_classes = [StaffWriteAuthenticatedReadPermission]
    pagination_class = None
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['opportunity__title', 'message', 'status']
    ordering_fields = ['id', 'created_at', 'status']
    ordering = ['-created_at']

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return VolunteerApplication.objects.none()
        queryset = VolunteerApplication.objects.select_related(
            'user', 'opportunity', 'opportunity__care_home'
        )
        user = self.request.user
        if user.is_staff:
            return queryset
        # مدير الدار يرى طلبات فرصه هو بالإضافة إلى طلباته الشخصية.
        # قبل هذا كان الاستعلام يقصره على طلباته وحدها، فكانت شاشة
        # «إدارة المتطوعين» فارغة دائماً مهما بلغ عدد الطلبات.
        care_home = care_home_for_user(user)
        if care_home is not None:
            return queryset.filter(
                Q(user=user) | Q(opportunity__care_home=care_home)
            ).distinct()
        return queryset.filter(user=user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    def _may_review(self, application):
        """من يملك البتّ في هذا الطلب: الطاقم أو مدير الدار صاحبة الفرصة."""
        return user_manages_care_home(
            self.request.user, application.opportunity.care_home
        )

    def perform_update(self, serializer):
        previous_status = serializer.instance.status
        application = serializer.save()
        if previous_status != application.status:
            _create_notification(
                application.user,
                Notification.TYPE_VOLUNTEER,
                'Volunteer application status updated',
                f'Your application for {application.opportunity.title} is now {application.status}.',
            )

    def perform_destroy(self, instance):
        with transaction.atomic():
            if _is_accepted_status(instance.status):
                VolunteerOpportunity.objects.filter(
                    pk=instance.opportunity_id,
                    current_volunteers__gt=0,
                ).update(current_volunteers=F('current_volunteers') - 1)
            instance.delete()

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        application = self.get_object()
        if not self._may_review(application):
            return Response(
                {'detail': 'Only the care home managing this opportunity can approve applications.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        with transaction.atomic():
            opportunity = VolunteerOpportunity.objects.select_for_update().get(pk=application.opportunity_id)
            if not _is_accepted_status(application.status):
                if opportunity.current_volunteers >= opportunity.required_volunteers:
                    return Response({'detail': 'Opportunity is already full.'}, status=status.HTTP_400_BAD_REQUEST)
                application.status = VolunteerApplication.STATUS_ACCEPTED
                application.save(update_fields=['status', 'updated_at'])
                VolunteerOpportunity.objects.filter(pk=opportunity.pk).update(current_volunteers=F('current_volunteers') + 1)
        application.refresh_from_db()
        _create_notification(
            application.user,
            Notification.TYPE_VOLUNTEER,
            'Volunteer application approved',
            f'Your application for {application.opportunity.title} was approved.',
        )
        return Response(self.get_serializer(application).data)

    @action(detail=False, methods=['get'], url_path='my-applications')
    def my_applications(self, request):
        applications = self.get_queryset()
        serializer = self.get_serializer(applications, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        application = self.get_object()
        if not self._may_review(application):
            return Response(
                {'detail': 'Only the care home managing this opportunity can reject applications.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        application.status = VolunteerApplication.STATUS_REJECTED
        application.save(update_fields=['status', 'updated_at'])
        _create_notification(
            application.user,
            Notification.TYPE_VOLUNTEER,
            'Volunteer application rejected',
            f'Your application for {application.opportunity.title} was rejected.',
        )
        return Response(self.get_serializer(application).data)

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        application = self.get_object()
        if not self._may_review(application):
            return Response(
                {'detail': 'Only the care home managing this opportunity can complete applications.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        application.status = VolunteerApplication.STATUS_COMPLETED
        application.save(update_fields=['status', 'updated_at'])
        _create_notification(
            application.user,
            Notification.TYPE_VOLUNTEER,
            'Volunteer application completed',
            f'Your application for {application.opportunity.title} was completed.',
        )
        return Response(self.get_serializer(application).data)

    @extend_schema(
        request=inline_serializer(
            name='VolunteerApplicationRateRequest',
            fields={
                'rating': serializers.IntegerField(min_value=1, max_value=5),
                'rating_notes': serializers.CharField(required=False, allow_blank=True),
            },
        ),
        responses=VolunteerApplicationSerializer,
    )
    @action(detail=True, methods=['post'])
    def rate(self, request, pk=None):
        """تقييم الدار للمتطوع بعد المشاركة.

        الشاشة كانت ترسل هذا منذ البداية إلى مسار غير موجود، وإلى
        حقول غير موجودة، ثم تُغلق نفسها معلنةً النجاح.
        """
        application = self.get_object()
        if not self._may_review(application):
            return Response(
                {'detail': 'Only the care home managing this opportunity can rate volunteers.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        if application.status not in (
            VolunteerApplication.STATUS_ACCEPTED,
            VolunteerApplication.STATUS_COMPLETED,
        ):
            return Response(
                {'detail': 'Only accepted or completed applications can be rated.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            rating = int(request.data.get('rating'))
        except (TypeError, ValueError):
            return Response(
                {'rating': 'rating must be an integer between 1 and 5.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not 1 <= rating <= 5:
            return Response(
                {'rating': 'rating must be between 1 and 5.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        application.rating = rating
        application.rating_notes = str(request.data.get('rating_notes') or '').strip()
        application.rated_at = timezone.now()
        application.save(
            update_fields=['rating', 'rating_notes', 'rated_at', 'updated_at']
        )
        _create_notification(
            application.user,
            Notification.TYPE_VOLUNTEER,
            'Volunteer participation rated',
            f'Your participation in {application.opportunity.title} was rated {rating}/5.',
        )
        return Response(self.get_serializer(application).data)


class CareHomeViewSet(SafeDestroyMixin, viewsets.ModelViewSet):
    queryset = CareHome.objects.all()
    serializer_class = CareHomeSerializer
    permission_classes = [StaffDeletePermission]
    pagination_class = None
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['name', 'address', 'phone', 'email']
    ordering_fields = ['id', 'name', 'orphan_count']
    ordering = ['name']

    def perform_create(self, serializer):
        # من ينشئ داراً يصبح مديرها، ما لم يكن للحساب دار بالفعل.
        if not self.request.user.is_staff and care_home_for_user(self.request.user):
            raise serializers.ValidationError(
                {'detail': 'هذا الحساب يدير داراً بالفعل.'}
            )
        serializer.save(manager=self.request.user)

    def update(self, request, *args, **kwargs):
        if not user_manages_care_home(request.user, self.get_object()):
            return Response(
                {'detail': 'Only the care home manager can update this record.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return super().update(request, *args, **kwargs)

    @extend_schema(responses=CareHomeSerializer)
    @action(detail=False, methods=['get', 'patch'], url_path='me')
    def me(self, request):
        """ملف الدار التي يديرها الحساب الحالي.

        كان التطبيق ينادي `/care-home/profile/me/` — مسار لا وجود له،
        فكانت شاشتا «ملف الدار» و«تعديل الملف» تعملان على قاموس فارغ
        وتعرضان قيماً مكتوبة يدوياً (اسم دار، مدينة، تقييم 4.8) كأنها
        بيانات حقيقية.
        """
        care_home = care_home_for_user(request.user)
        if care_home is None:
            return Response(
                {'detail': 'لا توجد دار مرتبطة بهذا الحساب.'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if request.method == 'PATCH':
            serializer = self.get_serializer(care_home, data=request.data, partial=True)
            serializer.is_valid(raise_exception=True)
            serializer.save()
            return Response(serializer.data)

        return Response(self.get_serializer(care_home).data)


class VisitHourViewSet(SafeDestroyMixin, viewsets.ModelViewSet):
    """مواعيد الزيارة الأسبوعية.

    يقرؤها أي مستخدم مسجَّل (المتبرع يحتاج معرفة أوقات الزيارة)،
    ولا يكتبها إلا مدير الدار صاحبة الموعد.
    """

    serializer_class = VisitHourSerializer
    permission_classes = [CareHomeManagerWritePermission]
    pagination_class = None
    filter_backends = [filters.OrderingFilter]
    ordering_fields = ['weekday', 'start_time']
    ordering = ['weekday', 'start_time']

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return VisitHour.objects.none()
        queryset = VisitHour.objects.select_related('care_home')
        care_home_id = self.request.query_params.get('care_home')
        if care_home_id:
            return queryset.filter(care_home_id=care_home_id)
        # بلا تحديد: يعرض مواعيد دار المستخدم إن كان مديراً، وإلا الكل.
        care_home = care_home_for_user(self.request.user)
        if care_home is not None and not self.request.user.is_staff:
            return queryset.filter(care_home=care_home)
        return queryset

    def perform_create(self, serializer):
        care_home = care_home_for_user(self.request.user)
        if care_home is None:
            raise serializers.ValidationError(
                {'detail': 'لا توجد دار مرتبطة بهذا الحساب.'}
            )
        try:
            serializer.save(care_home=care_home)
        except IntegrityError as exc:
            raise serializers.ValidationError(
                {'detail': 'هذا الموعد مضاف بالفعل.'}
            ) from exc


class NotificationViewSet(SafeDestroyMixin, viewsets.ModelViewSet):
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = None
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['title', 'message', 'notification_type']
    ordering_fields = ['id', 'created_at', 'is_read']
    ordering = ['-created_at']

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return Notification.objects.none()
        if self.request.user.is_staff:
            return Notification.objects.select_related('user').all()
        return Notification.objects.select_related('user').filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=False, methods=['get'])
    def unread_count(self, request):
        return Response({'unread_count': self.get_queryset().filter(is_read=False).count()})

    @action(detail=True, methods=['post'])
    def mark_as_read(self, request, pk=None):
        notification = self.get_object()
        notification.is_read = True
        notification.save(update_fields=['is_read'])
        return Response({'status': 'read'})

    @action(detail=False, methods=['post'])
    def mark_all_as_read(self, request):
        self.get_queryset().filter(is_read=False).update(is_read=True)
        return Response({'status': 'read'})


class ProfileViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = UserProfileSerializer
    permission_classes = [IsAuthenticated]
    pagination_class = None

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return UserProfile.objects.none()
        if self.request.user.is_staff:
            return UserProfile.objects.select_related('user').all()
        return UserProfile.objects.select_related('user').filter(user=self.request.user)


class DashboardStatsView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(responses=inline_serializer(name='DashboardStatsResponse', fields={'total_orphans': serializers.IntegerField()}))
    def get(self, request):
        return Response({
            'total_orphans': Orphan.objects.count(),
            'total_donations': Donation.objects.count(),
            'total_volunteers': Volunteer.objects.count(),
            'total_sponsors': Sponsor.objects.count(),
            'total_inventory_items': InventoryItem.objects.count(),
            'total_care_homes': CareHome.objects.count(),
            'total_needs': Need.objects.exclude(status=Need.STATUS_ARCHIVED).count(),
            'open_needs': Need.objects.filter(status=Need.STATUS_OPEN).count(),
            'total_volunteer_opportunities': VolunteerOpportunity.objects.count(),
            'unread_notifications': Notification.objects.filter(is_read=False).count() if request.user.is_staff else Notification.objects.filter(user=request.user, is_read=False).count(),
            'orphans_waiting': Orphan.objects.filter(status__in=ORPHAN_WAITING_STATUSES).count(),
            'active_donations': Donation.objects.filter(status__in=DONATION_ACTIVE_STATUSES).count(),
        })


class ReportsView(APIView):
    permission_classes = [IsAuthenticated]

    @extend_schema(responses=inline_serializer(name='ReportsResponse', fields={'orphans': serializers.DictField()}))
    def get(self, request):
        return Response({
            'orphans': {
                'total': Orphan.objects.count(),
                'by_status': list(Orphan.objects.values('status').annotate(count=Count('id'))),
            },
            'donations': {
                'total': Donation.objects.count(),
                'total_amount': 0,
                'by_status': list(Donation.objects.values('status').annotate(count=Count('id'))),
            },
            'volunteers': {
                'total': Volunteer.objects.count(),
                'total_points': Volunteer.objects.aggregate(Sum('points'))['points__sum'] or 0,
            },
            'inventory': {
                'total_items': InventoryItem.objects.count(),
                'total_quantity': InventoryItem.objects.aggregate(Sum('quantity'))['quantity__sum'] or 0,
            },
            'needs': {
                'total': Need.objects.exclude(status=Need.STATUS_ARCHIVED).count(),
                'open': Need.objects.filter(status=Need.STATUS_OPEN).count(),
                'by_status': list(Need.objects.values('status').annotate(count=Count('id'))),
            },
            'care_homes': {
                'total': CareHome.objects.count(),
                'total_orphans': CareHome.objects.aggregate(Sum('orphan_count'))['orphan_count__sum'] or 0,
            },
            'volunteer_opportunities': {
                'total': VolunteerOpportunity.objects.count(),
                'open': VolunteerOpportunity.objects.filter(status=VolunteerOpportunity.STATUS_OPEN).count(),
                'applications': VolunteerApplication.objects.count(),
            },
        })
