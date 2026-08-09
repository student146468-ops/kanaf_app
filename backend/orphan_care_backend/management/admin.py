from django.contrib import admin

from .models import (
    CareHome,
    Donation,
    InventoryItem,
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


@admin.register(VolunteerOpportunity)
class VolunteerOpportunityAdmin(admin.ModelAdmin):
    list_display = ['title', 'status', 'required_volunteers', 'current_volunteers', 'start_date']
    list_filter = ['status']
    search_fields = ['title', 'description', 'location']


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
