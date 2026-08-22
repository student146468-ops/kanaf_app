from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils import timezone


class UserProfile(models.Model):
    ROLE_DONOR = 'donor'
    ROLE_VOLUNTEER = 'volunteer'
    ROLE_CARE_HOME = 'care_home'
    ROLE_ADMIN = 'admin'
    ROLE_CHOICES = [
        (ROLE_DONOR, 'Donor'),
        (ROLE_VOLUNTEER, 'Volunteer'),
        (ROLE_CARE_HOME, 'Care home'),
        (ROLE_ADMIN, 'Admin'),
    ]

    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='profile')
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default=ROLE_DONOR, db_index=True)
    phone_number = models.CharField(max_length=20, blank=True)
    is_verified = models.BooleanField(default=False, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['role', 'is_verified'], name='profile_role_verified_idx'),
        ]

    def __str__(self):
        return f'{self.user.username} ({self.role})'


class PasswordResetCode(models.Model):
    """رمز استعادة كلمة المرور (6 أرقام) مربوط بمستخدم.

    قرارات أمنية مقصودة:
    * **لا يُخزَّن الرمز كنص صريح** بل بصمته (SHA-256 مع SALT المشروع).
      تسريب قاعدة البيانات لا يمنح المهاجم رموزاً صالحة.
    * **صلاحية قصيرة** (15 دقيقة) وعدد محاولات محدود (5) لصد التخمين؛
      الرمز من 6 أرقام يعني مليون احتمال، وبلا حدّ محاولات يُكسر آلياً.
    * **استخدام واحد**: `used_at` يمنع إعادة استعمال الرمز نفسه.
    """

    CODE_LENGTH = 6
    MAX_ATTEMPTS = 5
    VALIDITY = timezone.timedelta(minutes=15)

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='password_reset_codes',
    )
    code_hash = models.CharField(max_length=64, db_index=True)
    created_at = models.DateTimeField(default=timezone.now, db_index=True)
    expires_at = models.DateTimeField(db_index=True)
    used_at = models.DateTimeField(null=True, blank=True)
    attempts = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'used_at'], name='reset_user_used_idx'),
        ]

    def __str__(self):
        return f'PasswordResetCode(user={self.user_id}, expires={self.expires_at})'

    @property
    def is_expired(self):
        return timezone.now() >= self.expires_at

    @property
    def is_usable(self):
        return (
            self.used_at is None
            and not self.is_expired
            and self.attempts < self.MAX_ATTEMPTS
        )


class PhoneVerificationCode(models.Model):
    """رمز تحقق الهاتف لحساب جديد.

    نفس قواعد الأمان المستخدمة في PasswordResetCode: لا نخزن الرمز
    الصريح، ونحد الصلاحية والمحاولات، ونبطل الرموز الأقدم عند إصدار
    رمز جديد.
    """

    CODE_LENGTH = 6
    MAX_ATTEMPTS = 5
    VALIDITY = timezone.timedelta(minutes=10)

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='phone_verification_codes',
    )
    phone_number = models.CharField(max_length=20, db_index=True)
    code_hash = models.CharField(max_length=64, db_index=True)
    provider = models.CharField(max_length=40, blank=True)
    provider_message_id = models.CharField(max_length=100, blank=True)
    created_at = models.DateTimeField(default=timezone.now, db_index=True)
    expires_at = models.DateTimeField(db_index=True)
    used_at = models.DateTimeField(null=True, blank=True)
    attempts = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'used_at'], name='phone_otp_user_used_idx'),
            models.Index(fields=['phone_number', 'used_at'], name='phone_otp_phone_used_idx'),
        ]

    def __str__(self):
        return f'PhoneVerificationCode(user={self.user_id}, phone={self.phone_number})'

    @property
    def is_expired(self):
        return timezone.now() >= self.expires_at


class Volunteer(models.Model):
    name = models.CharField(max_length=100, db_index=True)
    specialty = models.CharField(max_length=100, db_index=True)
    points = models.IntegerField(default=0, validators=[MinValueValidator(0)])

    class Meta:
        ordering = ['-points', 'name']
        constraints = [
            models.CheckConstraint(check=models.Q(points__gte=0), name='volunteer_points_non_negative'),
        ]
        indexes = [
            models.Index(fields=['specialty', 'points'], name='volunteer_specialty_points_idx'),
        ]

    def __str__(self):
        return self.name


class Orphan(models.Model):
    name = models.CharField(max_length=100, db_index=True)
    age = models.IntegerField(validators=[MinValueValidator(0), MaxValueValidator(18)])
    status = models.CharField(max_length=100, default='ينتظر كفالة', db_index=True)

    class Meta:
        ordering = ['name']
        constraints = [
            models.CheckConstraint(check=models.Q(age__gte=0) & models.Q(age__lte=18), name='orphan_age_between_0_18'),
        ]
        indexes = [
            models.Index(fields=['status', 'age'], name='orphan_status_age_idx'),
        ]

    def __str__(self):
        return self.name


class Donation(models.Model):
    TYPE_FINANCIAL = 'financial'
    TYPE_IN_KIND = 'in_kind'
    TYPE_CHOICES = [
        (TYPE_FINANCIAL, 'Financial'),
        (TYPE_IN_KIND, 'In-kind'),
    ]

    STATUS_PENDING = 'pending'
    STATUS_ACCEPTED = 'accepted'
    STATUS_APPROVED = STATUS_ACCEPTED
    STATUS_REJECTED = 'rejected'
    STATUS_COMPLETED = 'completed'
    STATUS_CHOICES = [
        (STATUS_PENDING, 'Pending review'),
        (STATUS_ACCEPTED, 'Accepted'),
        (STATUS_REJECTED, 'Rejected'),
        (STATUS_COMPLETED, 'Completed'),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='donations')
    need = models.ForeignKey('Need', on_delete=models.SET_NULL, null=True, blank=True, related_name='donations')
    donation_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default=TYPE_IN_KIND, db_index=True)
    amount = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True, validators=[MinValueValidator(0)])
    description = models.TextField(blank=True)
    quantity = models.CharField(max_length=100, blank=True)
    payment_method = models.CharField(max_length=100, blank=True)
    donation_mode = models.CharField(max_length=100, blank=True)
    contact = models.CharField(max_length=100, blank=True)
    notes = models.TextField(blank=True)
    donation_date = models.DateTimeField(default=timezone.now, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)
    donor_name = models.CharField(max_length=100, blank=True, db_index=True)
    item_type = models.CharField(max_length=100, blank=True, db_index=True)
    status = models.CharField(max_length=50, choices=STATUS_CHOICES, default=STATUS_PENDING, db_index=True)

    class Meta:
        ordering = ['-donation_date', '-id']
        indexes = [
            models.Index(fields=['status', 'donor_name'], name='donation_status_donor_idx'),
            models.Index(fields=['user', 'status'], name='donation_user_status_idx'),
            models.Index(fields=['need', 'status'], name='donation_need_status_idx'),
        ]

    def __str__(self):
        label = self.amount if self.donation_type == self.TYPE_FINANCIAL else self.item_type
        return f'{self.donor_name} - {label}'


class Sponsor(models.Model):
    name = models.CharField(max_length=100, db_index=True)
    phone = models.CharField(max_length=20, db_index=True)
    orphan_name = models.CharField(max_length=100, blank=True, db_index=True)

    class Meta:
        ordering = ['name']
        indexes = [
            models.Index(fields=['name', 'phone'], name='sponsor_name_phone_idx'),
        ]

    def __str__(self):
        return self.name


class InventoryItem(models.Model):
    item_name = models.CharField(max_length=100, db_index=True)
    quantity = models.IntegerField(validators=[MinValueValidator(0)])

    class Meta:
        ordering = ['item_name']
        constraints = [
            models.CheckConstraint(check=models.Q(quantity__gte=0), name='inventory_quantity_non_negative'),
        ]
        indexes = [
            models.Index(fields=['item_name', 'quantity'], name='inventory_item_quantity_idx'),
        ]

    def __str__(self):
        return self.item_name


class Need(models.Model):
    PRIORITY_LOW = 'low'
    PRIORITY_MEDIUM = 'medium'
    PRIORITY_URGENT = 'urgent'
    PRIORITY_CHOICES = [
        (PRIORITY_LOW, 'Low'),
        (PRIORITY_MEDIUM, 'Medium'),
        (PRIORITY_URGENT, 'Urgent'),
    ]

    STATUS_OPEN = 'open'
    STATUS_COMPLETED = 'completed'
    STATUS_ARCHIVED = 'archived'
    STATUS_CHOICES = [
        (STATUS_OPEN, 'Open'),
        (STATUS_COMPLETED, 'Completed'),
        (STATUS_ARCHIVED, 'Archived'),
    ]

    title = models.CharField(max_length=200, db_index=True)
    description = models.TextField(blank=True)
    category = models.CharField(max_length=100, blank=True, db_index=True)
    need_type = models.CharField(max_length=100, blank=True)
    priority = models.CharField(max_length=20, choices=PRIORITY_CHOICES, default=PRIORITY_MEDIUM, db_index=True)
    required_quantity = models.CharField(max_length=100, blank=True)
    fulfilled_quantity = models.DecimalField(max_digits=12, decimal_places=2, default=0, validators=[MinValueValidator(0)])
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_OPEN, db_index=True)
    image_url = models.URLField(blank=True)
    deadline = models.DateField(null=True, blank=True, db_index=True)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='created_needs')
    # الدار صاحبة الاحتياج. بدونها لا يستطيع المتبرع تصفح احتياجات دار
    # بعينها، ولا تستطيع الدار عرض احتياجاتها هي في ملفها.
    care_home = models.ForeignKey(
        'CareHome',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='needs',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        constraints = [
            models.CheckConstraint(check=models.Q(fulfilled_quantity__gte=0), name='need_fulfilled_quantity_non_negative'),
        ]
        indexes = [
            models.Index(fields=['status', 'priority', 'deadline'], name='need_status_prio_dead_idx'),
        ]

    def __str__(self):
        return self.title


class VolunteerOpportunity(models.Model):
    STATUS_OPEN = 'open'
    STATUS_CLOSED = 'closed'
    STATUS_COMPLETED = 'completed'
    STATUS_CHOICES = [
        (STATUS_OPEN, 'Open'),
        (STATUS_CLOSED, 'Closed'),
        (STATUS_COMPLETED, 'Completed'),
    ]

    title = models.CharField(max_length=200, db_index=True)
    description = models.TextField()
    # الدار المالكة للفرصة. بدونها لا يمكن لمدير الدار تصفية الطلبات
    # الواردة على فرصه هو، وكانت شاشة «إدارة المتطوعين» بلا مصدر بيانات.
    care_home = models.ForeignKey(
        'CareHome',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='opportunities',
    )
    required_volunteers = models.IntegerField(default=1, validators=[MinValueValidator(1)])
    current_volunteers = models.IntegerField(default=0, validators=[MinValueValidator(0)])
    start_date = models.DateTimeField(null=True, blank=True, db_index=True)
    end_date = models.DateTimeField(null=True, blank=True)
    location = models.CharField(max_length=200, blank=True, db_index=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_OPEN, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-start_date', '-created_at']
        constraints = [
            models.CheckConstraint(check=models.Q(required_volunteers__gte=1), name='opportunity_required_volunteers_positive'),
            models.CheckConstraint(check=models.Q(current_volunteers__gte=0), name='opportunity_current_volunteers_non_negative'),
            models.CheckConstraint(
                check=models.Q(end_date__isnull=True) | models.Q(start_date__isnull=True) | models.Q(end_date__gte=models.F('start_date')),
                name='opportunity_end_after_start',
            ),
        ]
        indexes = [
            models.Index(fields=['status', 'start_date'], name='opportunity_status_start_idx'),
        ]

    def __str__(self):
        return self.title


class VolunteerApplication(models.Model):
    STATUS_PENDING = 'pending'
    STATUS_ACCEPTED = 'accepted'
    STATUS_APPROVED = STATUS_ACCEPTED
    STATUS_REJECTED = 'rejected'
    STATUS_COMPLETED = 'completed'
    STATUS_CHOICES = [
        (STATUS_PENDING, 'Pending'),
        (STATUS_ACCEPTED, 'Accepted'),
        (STATUS_REJECTED, 'Rejected'),
        (STATUS_COMPLETED, 'Completed'),
    ]

    opportunity = models.ForeignKey(VolunteerOpportunity, on_delete=models.CASCADE, related_name='applications')
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='volunteer_applications')
    message = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_PENDING, db_index=True)
    # تقييم الدار للمتطوع بعد انتهاء المشاركة. كانت شاشة التقييم ترسل
    # `rating` و`rating_notes` إلى حقول لا وجود لها، فتُرمى صامتة.
    rating = models.PositiveSmallIntegerField(
        null=True,
        blank=True,
        validators=[MinValueValidator(1), MaxValueValidator(5)],
    )
    rating_notes = models.TextField(blank=True)
    rated_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        constraints = [
            models.UniqueConstraint(fields=['opportunity', 'user'], name='unique_opportunity_user_application'),
            models.CheckConstraint(
                check=models.Q(rating__isnull=True) | models.Q(rating__gte=1, rating__lte=5),
                name='volunteer_application_rating_range',
            ),
        ]
        indexes = [
            models.Index(fields=['user', 'status'], name='vol_app_user_status_idx'),
            models.Index(fields=['opportunity', 'status'], name='vol_app_opp_status_idx'),
        ]

    def __str__(self):
        return f'{self.user.username} -> {self.opportunity.title}'


class CareHome(models.Model):
    name = models.CharField(max_length=200, db_index=True)
    address = models.TextField()
    phone = models.CharField(max_length=20, db_index=True)
    email = models.EmailField(blank=True)
    manager = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='managed_care_homes')
    description = models.TextField(blank=True)
    orphan_count = models.IntegerField(default=0, validators=[MinValueValidator(0)])
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']
        constraints = [
            models.CheckConstraint(check=models.Q(orphan_count__gte=0), name='care_home_orphan_count_non_negative'),
        ]
        indexes = [
            models.Index(fields=['name', 'phone'], name='care_home_name_phone_idx'),
        ]

    def __str__(self):
        return self.name


class VisitHour(models.Model):
    """موعد زيارة أسبوعي تعلنه الدار للزوار والمتبرعين.

    كان التطبيق ينادي `/visit-hours/` بينما لا يوجد نموذج ولا مسار
    بهذا الاسم إطلاقاً — فكل عملية على الشاشة كانت ترتد بـ 404.
    """

    SATURDAY = 5
    WEEKDAY_CHOICES = [
        (0, 'الاثنين'),
        (1, 'الثلاثاء'),
        (2, 'الأربعاء'),
        (3, 'الخميس'),
        (4, 'الجمعة'),
        (5, 'السبت'),
        (6, 'الأحد'),
    ]

    care_home = models.ForeignKey(
        CareHome,
        on_delete=models.CASCADE,
        related_name='visit_hours',
    )
    weekday = models.PositiveSmallIntegerField(choices=WEEKDAY_CHOICES, db_index=True)
    start_time = models.TimeField()
    end_time = models.TimeField()
    notes = models.CharField(max_length=200, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['weekday', 'start_time']
        constraints = [
            models.UniqueConstraint(
                fields=['care_home', 'weekday', 'start_time'],
                name='unique_care_home_visit_slot',
            ),
            models.CheckConstraint(
                check=models.Q(end_time__gt=models.F('start_time')),
                name='visit_hour_end_after_start',
            ),
        ]
        indexes = [
            models.Index(fields=['care_home', 'weekday'], name='visit_hour_home_day_idx'),
        ]

    def __str__(self):
        return f'{self.care_home.name} - {self.get_weekday_display()}'


class Notification(models.Model):
    TYPE_DONATION = 'donation'
    TYPE_VOLUNTEER = 'volunteer'
    TYPE_STATUS_UPDATE = 'status_update'
    TYPE_MESSAGE = 'message'
    TYPE_CHOICES = [
        (TYPE_DONATION, 'Donation'),
        (TYPE_VOLUNTEER, 'Volunteer'),
        (TYPE_STATUS_UPDATE, 'Status update'),
        (TYPE_MESSAGE, 'Message'),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications')
    notification_type = models.CharField(max_length=20, choices=TYPE_CHOICES, default=TYPE_MESSAGE, db_index=True)
    title = models.CharField(max_length=200)
    message = models.TextField()
    is_read = models.BooleanField(default=False, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'is_read', 'created_at'], name='notif_user_read_created_idx'),
        ]

    def __str__(self):
        return f'{self.title} - {self.user.username}'
