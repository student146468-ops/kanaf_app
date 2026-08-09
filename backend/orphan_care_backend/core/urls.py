from django.contrib import admin
from django.urls import include, path

from . import views

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', views.dashboard, name='dashboard'),
    path('orphans/', views.orphans_list, name='orphans_list'),
    path('volunteers/', views.volunteers_view, name='volunteers_list'),
    path('volunteer-applications/', views.volunteer_applications_view, name='volunteer_applications_list'),
    path('donations/', views.donations_list, name='donations_list'),
    path('sponsors/', views.sponsors_list, name='sponsors_list'),
    path('inventory/', views.inventory_view, name='inventory_view'),
    path('reports/', views.reports_view, name='reports_view'),
    path('settings/', views.settings_view, name='settings_view'),
    path('delete_orphan/<int:pk>/', views.delete_orphan, name='delete_orphan'),
    path('delete_volunteer/<int:pk>/', views.delete_volunteer, name='delete_volunteer'),
    path('delete_donation/<int:pk>/', views.delete_donation, name='delete_donation'),
    path('donations/<int:pk>/status/', views.update_donation_status, name='update_donation_status'),
    path('volunteer-applications/<int:pk>/status/', views.update_volunteer_application_status, name='update_volunteer_application_status'),
    path('delete_sponsor/<int:pk>/', views.delete_sponsor, name='delete_sponsor'),
    path('delete_inventory/<int:pk>/', views.delete_inventory, name='delete_inventory'),
    # مصدر الحقيقة الوحيد للـ API. لا تُضف مسارات تحت 'api/' خارج هذا الملف،
    # فأي مسار مكرر هنا يحجب الـ ViewSet الحقيقي ويكسر الكتابة بصمت.
    path('api/', include('core.urls_api')),
    path('dashboard/api/', views.api_dashboard, name='api_dashboard'),
]
