from django.contrib import admin

from .models import (
    CareHome,
    Donation,
    InventoryItem,
    Need,
    Notification,
    Orphan,
    Sponsor,
    UserProfile,
    Volunteer,
    VolunteerApplication,
    VolunteerOpportunity,
)


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ['user', 'role', 'phone_number', 'is_verified', 'created_at']
    list_filter = ['role', 'is_verified']
    search_fields = ['user__username', 'user__email', 'phone_number']


@admin.register(Orphan)
class OrphanAdmin(admin.ModelAdmin):
    list_display = ['name', 'age', 'status']
    list_filter = ['status']
    search_fields = ['name']


@admin.register(Donation)
class DonationAdmin(admin.ModelAdmin):
    list_display = ['donor_name', 'item_type', 'status']
    list_filter = ['status']
    search_fields = ['donor_name', 'item_type']


@admin.register(Volunteer)
class VolunteerAdmin(admin.ModelAdmin):
    list_display = ['name', 'specialty', 'points']
    list_filter = ['specialty']
    search_fields = ['name', 'specialty']


@admin.register(Sponsor)
class SponsorAdmin(admin.ModelAdmin):
    list_display = ['name', 'phone', 'orphan_name']
    search_fields = ['name', 'phone', 'orphan_name']


@admin.register(InventoryItem)
class InventoryItemAdmin(admin.ModelAdmin):
    list_display = ['item_name', 'quantity']
    search_fields = ['item_name']


@admin.register(Need)
class NeedAdmin(admin.ModelAdmin):
    list_display = [
        'title',
        'care_home',
        'category',
        'required_quantity',
        'fulfilled_quantity',
        'priority',
        'status',
        'created_at',
    ]
    list_filter = ['status', 'priority', 'category', 'care_home']
    search_fields = ['title', 'description', 'category', 'care_home__name']
    readonly_fields = ['created_at', 'updated_at']
    autocomplete_fields = ['care_home', 'created_by']
    fieldsets = (
        (None, {
            'fields': (
                'title',
                'description',
                'care_home',
                'category',
                'need_type',
                'priority',
                'status',
            )
        }),
        ('Quantities', {
            'fields': ('required_quantity', 'fulfilled_quantity')
        }),
        ('Media and timing', {
            'fields': ('image_url', 'deadline')
        }),
        ('Audit', {
            'fields': ('created_by', 'created_at', 'updated_at')
        }),
    )


@admin.register(VolunteerOpportunity)
class VolunteerOpportunityAdmin(admin.ModelAdmin):
    list_display = ['title', 'care_home', 'category', 'status', 'required_volunteers', 'current_volunteers', 'start_date']
    list_filter = ['status', 'category', 'care_home']
    search_fields = ['title', 'description', 'required_skills', 'location', 'care_home__name']
    readonly_fields = ['current_volunteers', 'created_at', 'updated_at']
    fieldsets = (
        (None, {
            'fields': ('title', 'description', 'care_home', 'category', 'status')
        }),
        ('Volunteer capacity', {
            'fields': ('required_volunteers', 'current_volunteers', 'required_skills')
        }),
        ('Location and timing', {
            'fields': ('location', 'start_date', 'end_date')
        }),
        ('Media', {
            'fields': ('image_url',)
        }),
        ('Audit', {
            'fields': ('created_at', 'updated_at')
        }),
    )


@admin.register(VolunteerApplication)
class VolunteerApplicationAdmin(admin.ModelAdmin):
    list_display = ['opportunity', 'user', 'status', 'created_at']
    list_filter = ['status']
    search_fields = ['opportunity__title', 'user__username', 'message']


@admin.register(CareHome)
class CareHomeAdmin(admin.ModelAdmin):
    list_display = ['name', 'phone', 'email', 'orphan_count']
    search_fields = ['name', 'phone', 'email', 'address']


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ['title', 'user', 'notification_type', 'is_read', 'created_at']
    list_filter = ['notification_type', 'is_read']
    search_fields = ['title', 'message', 'user__username']
