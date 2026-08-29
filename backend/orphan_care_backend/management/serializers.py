import re
from decimal import Decimal, InvalidOperation

from rest_framework import serializers

from .models import (
    CareHome,
    Donation,
    InventoryItem,
    Need,
    Notification,
    Orphan,
    Sponsor,
    UserProfile,
    VisitHour,
    Volunteer,
    VolunteerApplication,
    VolunteerOpportunity,
)

# حد أعلى للتبرع الواحد. ليس سقفاً على كرم المتبرع، بل حاجز ضد
# القيم الخاطئة (خطأ إدخال أو تلاعب). مطابق لـ _maxDonationAmount في التطبيق.
MAX_DONATION_AMOUNT = Decimal('1000000')


def _decimal_from_text(value):
    match = re.search(r'\d+(?:\.\d+)?', str(value or '').replace(',', ''))
    if not match:
        return None
    try:
        return Decimal(match.group(0))
    except InvalidOperation:
        return None


def _validate_required_text(value, field_name):
    if value is None or not str(value).strip():
        raise serializers.ValidationError(f'{field_name} is required.')
    return str(value).strip()


class OrphanSerializer(serializers.ModelSerializer):
    class Meta:
        model = Orphan
        fields = '__all__'

    def validate_name(self, value):
        return _validate_required_text(value, 'name')

    def validate_age(self, value):
        if value is None or value < 0 or value > 18:
            raise serializers.ValidationError('age must be between 0 and 18.')
        return value


class DonationSerializer(serializers.ModelSerializer):
    need_id = serializers.PrimaryKeyRelatedField(
        queryset=Need.objects.all(),
        source='need',
        write_only=True,
        required=False,
        allow_null=True,
    )
    need_title = serializers.CharField(source='need.title', read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = Donation
        fields = [
            'id',
            'user',
            'username',
            'donor_name',
            'donation_type',
            'item_type',
            'need',
            'need_id',
            'need_title',
            'amount',
            'description',
            'quantity',
            'payment_method',
            'donation_mode',
            'contact',
            'notes',
            'status',
            'donation_date',
            'updated_at',
        ]
        read_only_fields = ['user', 'need', 'donation_date', 'updated_at']

    def validate_donor_name(self, value):
        return str(value).strip()

    def validate_item_type(self, value):
        return str(value).strip()

    def validate_status(self, value):
        if value == 'approved':
            value = Donation.STATUS_ACCEPTED
        allowed = {
            Donation.STATUS_PENDING,
            Donation.STATUS_ACCEPTED,
            Donation.STATUS_REJECTED,
            Donation.STATUS_COMPLETED,
        }
        if value not in allowed:
            raise serializers.ValidationError('status must be pending, accepted, rejected or completed.')
        return value

    def validate(self, attrs):
        donation_type = attrs.get('donation_type', getattr(self.instance, 'donation_type', Donation.TYPE_IN_KIND))
        amount = attrs.get('amount', getattr(self.instance, 'amount', None))
        quantity = attrs.get('quantity', getattr(self.instance, 'quantity', ''))
        description = attrs.get('description', getattr(self.instance, 'description', ''))
        item_type = attrs.get('item_type', getattr(self.instance, 'item_type', ''))
        need = attrs.get('need', getattr(self.instance, 'need', None))

        if need and getattr(need, 'status', None) != Need.STATUS_OPEN:
            raise serializers.ValidationError({'need_id': 'need must exist and be open.'})

        if donation_type == Donation.TYPE_FINANCIAL:
            if amount is None:
                raise serializers.ValidationError({'amount': 'amount is required for financial donations.'})
            try:
                value = Decimal(str(amount))
            except InvalidOperation:
                raise serializers.ValidationError({'amount': 'amount must be a valid number.'})
            if value <= 0:
                raise serializers.ValidationError({'amount': 'amount must be greater than zero.'})
            # لا سقف عملي على التبرع؛ الحد موجود فقط لصد القيم الخاطئة.
            # يجب أن يبقى مطابقاً لـ _maxDonationAmount في التطبيق.
            if value > MAX_DONATION_AMOUNT:
                raise serializers.ValidationError(
                    {'amount': f'amount must not exceed {MAX_DONATION_AMOUNT}.'}
                )
        if donation_type == Donation.TYPE_IN_KIND and not (str(quantity).strip() or str(description).strip() or str(item_type).strip()):
            raise serializers.ValidationError({'quantity': 'quantity or description is required for in-kind donations.'})
        return attrs

    def to_representation(self, instance):
        data = super().to_representation(instance)
        if data.get('status') == 'approved':
            data['status'] = Donation.STATUS_ACCEPTED
        return data


class VolunteerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Volunteer
        fields = '__all__'

    def validate_name(self, value):
        return _validate_required_text(value, 'name')

    def validate_specialty(self, value):
        return _validate_required_text(value, 'specialty')

    def validate_points(self, value):
        if value is None or value < 0:
            raise serializers.ValidationError('points must be zero or greater.')
        return value


class InventorySerializer(serializers.ModelSerializer):
    class Meta:
        model = InventoryItem
        fields = '__all__'

    def validate_item_name(self, value):
        return _validate_required_text(value, 'item_name')

    def validate_quantity(self, value):
        if value is None or value < 0:
            raise serializers.ValidationError('quantity must be zero or greater.')
        return value


class NeedSerializer(serializers.ModelSerializer):
    care_home_name = serializers.CharField(source='care_home.name', read_only=True)
    care_home_location = serializers.CharField(source='care_home.address', read_only=True)
    progress_percent = serializers.SerializerMethodField()
    remaining_quantity = serializers.SerializerMethodField()

    class Meta:
        model = Need
        fields = '__all__'
        read_only_fields = ['created_by', 'created_at', 'updated_at']

    def validate_title(self, value):
        return _validate_required_text(value, 'title')

    def validate_category(self, value):
        return _validate_required_text(value, 'category')

    def validate_required_quantity(self, value):
        value = _validate_required_text(value, 'required_quantity')
        target = _decimal_from_text(value)
        if target is None or target <= 0:
            raise serializers.ValidationError(
                'required_quantity must include a number greater than zero.'
            )
        return value

    def validate_fulfilled_quantity(self, value):
        if value is None or value < 0:
            raise serializers.ValidationError('fulfilled_quantity must be zero or greater.')
        return value

    def validate(self, attrs):
        attrs = super().validate(attrs)

        required_quantity = attrs.get(
            'required_quantity',
            getattr(self.instance, 'required_quantity', None),
        )
        target = _decimal_from_text(required_quantity)
        fulfilled_quantity = attrs.get(
            'fulfilled_quantity',
            getattr(self.instance, 'fulfilled_quantity', Decimal('0')),
        )

        if target is not None and fulfilled_quantity is not None:
            if Decimal(fulfilled_quantity) > target:
                raise serializers.ValidationError({
                    'fulfilled_quantity': 'fulfilled_quantity cannot exceed required_quantity.'
                })

        if 'care_home' in attrs and attrs['care_home'] is None:
            raise serializers.ValidationError({'care_home': 'care_home is required.'})

        return attrs

    def get_progress_percent(self, obj) -> int | None:
        target = _decimal_from_text(obj.required_quantity)
        if target is None or target <= 0:
            return None
        progress = (Decimal(obj.fulfilled_quantity) / target) * Decimal('100')
        return int(min(progress, Decimal('100')).quantize(Decimal('1')))

    def get_remaining_quantity(self, obj) -> float | None:
        target = _decimal_from_text(obj.required_quantity)
        if target is None:
            return None
        remaining = max(target - Decimal(obj.fulfilled_quantity), Decimal('0'))
        return float(remaining)


class SponsorSerializer(serializers.ModelSerializer):
    class Meta:
        model = Sponsor
        fields = '__all__'

    def validate_name(self, value):
        return _validate_required_text(value, 'name')

    def validate_phone(self, value):
        return _validate_required_text(value, 'phone')


class UserProfileSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.EmailField(source='user.email', read_only=True)

    class Meta:
        model = UserProfile
        fields = ['id', 'username', 'email', 'role', 'phone_number', 'is_verified', 'created_at', 'updated_at']
        read_only_fields = ['created_at', 'updated_at', 'is_verified']


class VolunteerOpportunitySerializer(serializers.ModelSerializer):
    applications_count = serializers.SerializerMethodField()
    care_home_name = serializers.CharField(source='care_home.name', read_only=True)
    care_home_location = serializers.CharField(source='care_home.address', read_only=True)
    capacity_percent = serializers.SerializerMethodField()
    remaining_slots = serializers.SerializerMethodField()
    my_application_id = serializers.SerializerMethodField()
    my_application_status = serializers.SerializerMethodField()

    class Meta:
        model = VolunteerOpportunity
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at', 'current_volunteers']
        extra_kwargs = {
            'care_home': {'required': False},
        }

    def validate_title(self, value):
        return _validate_required_text(value, 'title')

    def validate_description(self, value):
        return _validate_required_text(value, 'description')

    def validate_required_volunteers(self, value):
        if value is None or value <= 0:
            raise serializers.ValidationError('required_volunteers must be greater than zero.')
        return value

    def validate_current_volunteers(self, value):
        if value is None or value < 0:
            raise serializers.ValidationError('current_volunteers must be zero or greater.')
        return value

    def validate(self, attrs):
        request = self.context.get('request')
        user = getattr(request, 'user', None)
        care_home = attrs.get('care_home', getattr(self.instance, 'care_home', None))
        start_date = attrs.get('start_date', getattr(self.instance, 'start_date', None))
        end_date = attrs.get('end_date', getattr(self.instance, 'end_date', None))
        required_volunteers = attrs.get(
            'required_volunteers',
            getattr(self.instance, 'required_volunteers', 1),
        )
        current_volunteers = attrs.get(
            'current_volunteers',
            getattr(self.instance, 'current_volunteers', 0),
        )

        if request and request.method == 'POST' and getattr(user, 'is_staff', False):
            if care_home is None:
                raise serializers.ValidationError({'care_home': 'care_home is required.'})
        if request and not getattr(user, 'is_staff', False) and 'care_home' in attrs:
            raise serializers.ValidationError({'care_home': 'care_home is managed by the backend.'})
        if start_date and end_date and end_date < start_date:
            raise serializers.ValidationError({'end_date': 'end_date must be after start_date.'})
        if current_volunteers is not None and required_volunteers is not None:
            if current_volunteers > required_volunteers:
                raise serializers.ValidationError({
                    'current_volunteers': 'current_volunteers cannot exceed required_volunteers.'
                })
        return attrs

    def get_applications_count(self, obj) -> int:
        return obj.applications.count()

    def get_capacity_percent(self, obj) -> int:
        if not obj.required_volunteers:
            return 0
        progress = (obj.current_volunteers / obj.required_volunteers) * 100
        return int(min(progress, 100))

    def get_remaining_slots(self, obj) -> int:
        return max(obj.required_volunteers - obj.current_volunteers, 0)

    def _current_user_application(self, obj):
        request = self.context.get('request')
        user = getattr(request, 'user', None)
        if not (user and user.is_authenticated):
            return None
        return obj.applications.filter(user=user).order_by('-created_at').first()

    def get_my_application_id(self, obj):
        application = self._current_user_application(obj)
        return application.id if application else None

    def get_my_application_status(self, obj):
        application = self._current_user_application(obj)
        return application.status if application else None


class VolunteerApplicationSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    volunteer_name = serializers.SerializerMethodField()
    opportunity_title = serializers.CharField(source='opportunity.title', read_only=True)
    opportunity_description = serializers.CharField(source='opportunity.description', read_only=True)
    opportunity_location = serializers.CharField(source='opportunity.location', read_only=True)
    opportunity_status = serializers.CharField(source='opportunity.status', read_only=True)
    opportunity_start_date = serializers.DateTimeField(source='opportunity.start_date', read_only=True)
    opportunity_end_date = serializers.DateTimeField(source='opportunity.end_date', read_only=True)

    class Meta:
        model = VolunteerApplication
        fields = '__all__'
        # التقييم والحالة يملكهما الخادم؛ العميل يرسل `message` فقط.
        read_only_fields = [
            'user',
            'status',
            'created_at',
            'updated_at',
            'rating',
            'rating_notes',
            'rated_at',
        ]

    def get_volunteer_name(self, obj) -> str:
        full_name = obj.user.get_full_name().strip()
        return full_name or obj.user.username

    def validate(self, attrs):
        attrs = super().validate(attrs)
        request = self.context.get('request')
        user = getattr(request, 'user', None)
        opportunity = attrs.get('opportunity', getattr(self.instance, 'opportunity', None))
        if self.instance is None and opportunity is not None:
            if opportunity.care_home_id is None:
                raise serializers.ValidationError({'opportunity': 'opportunity must be linked to a care home.'})
            if opportunity.status != VolunteerOpportunity.STATUS_OPEN:
                raise serializers.ValidationError({'opportunity': 'opportunity is not open for applications.'})
            if opportunity.current_volunteers >= opportunity.required_volunteers:
                raise serializers.ValidationError({'opportunity': 'opportunity is already full.'})
            if (
                user
                and user.is_authenticated
                and VolunteerApplication.objects.filter(
                    opportunity=opportunity,
                    user=user,
                ).exists()
            ):
                raise serializers.ValidationError({'opportunity': 'You have already applied to this opportunity.'})
        return attrs

    def validate_status(self, value):
        if value == 'approved':
            return VolunteerApplication.STATUS_ACCEPTED
        return value

    def to_representation(self, instance):
        data = super().to_representation(instance)
        if data.get('status') == 'approved':
            data['status'] = VolunteerApplication.STATUS_ACCEPTED
        return data


class CareHomeSerializer(serializers.ModelSerializer):
    manager_username = serializers.CharField(source='manager.username', read_only=True)
    open_needs_count = serializers.SerializerMethodField()
    visit_hours_count = serializers.SerializerMethodField()

    class Meta:
        model = CareHome
        fields = '__all__'
        # المدير يُربط عبر الحساب لا عبر جسم الطلب، وإلا استطاع أي
        # مستخدم إسناد دار لنفسه أو انتزاعها من غيره.
        read_only_fields = ['created_at', 'updated_at', 'manager']

    def get_open_needs_count(self, obj) -> int:
        return Need.objects.filter(care_home=obj, status=Need.STATUS_OPEN).count()

    def get_visit_hours_count(self, obj) -> int:
        return obj.visit_hours.count()

    def validate_name(self, value):
        return _validate_required_text(value, 'name')

    def validate_address(self, value):
        return _validate_required_text(value, 'address')

    def validate_phone(self, value):
        return _validate_required_text(value, 'phone')


class VisitHourSerializer(serializers.ModelSerializer):
    care_home_name = serializers.CharField(source='care_home.name', read_only=True)
    weekday_label = serializers.CharField(source='get_weekday_display', read_only=True)

    class Meta:
        model = VisitHour
        fields = '__all__'
        # الدار تُستنتج من حساب المدير، فلا يضيف أحد مواعيد لدار غيره.
        read_only_fields = ['created_at', 'updated_at', 'care_home']

    def validate(self, attrs):
        start = attrs.get('start_time', getattr(self.instance, 'start_time', None))
        end = attrs.get('end_time', getattr(self.instance, 'end_time', None))
        if start and end and end <= start:
            raise serializers.ValidationError(
                {'end_time': 'end_time must be after start_time.'}
            )
        return attrs


class NotificationSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = Notification
        fields = '__all__'
        read_only_fields = ['created_at', 'user']

    def validate_title(self, value):
        return _validate_required_text(value, 'title')

    def validate_message(self, value):
        return _validate_required_text(value, 'message')
