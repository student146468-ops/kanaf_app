import json
import logging

from django.contrib import messages
from django.contrib.auth import authenticate, login, logout
from django.contrib.auth.decorators import user_passes_test
from django.db import IntegrityError
from django.db.models import ProtectedError
from django.shortcuts import get_object_or_404, redirect, render
from django.utils.http import url_has_allowed_host_and_scheme
from django.views.decorators.http import require_POST

from management.models import (
    CareHome,
    Donation,
    InventoryItem,
    Need,
    Orphan,
    Sponsor,
    Volunteer,
    VolunteerApplication,
    VolunteerOpportunity,
)
from management.serializers import (
    DonationSerializer,
    InventorySerializer,
    OrphanSerializer,
    SponsorSerializer,
    VolunteerOpportunitySerializer,
    VolunteerSerializer,
)

logger = logging.getLogger(__name__)


staff_required = user_passes_test(
    lambda user: user.is_active and user.is_staff,
    login_url='login',
)


STATUS_LABELS_AR = {
    'pending': 'قيد الانتظار',
    'accepted': 'مقبول',
    'rejected': 'مرفوض',
    'completed': 'مكتمل',
}


def _status_label(value):
    return STATUS_LABELS_AR.get(value, value)


def _save_from_serializer(request, serializer_class, data, redirect_name, template_name, context):
    serializer = serializer_class(data=data)
    if serializer.is_valid():
        serializer.save()
        return redirect(redirect_name)
    context['form_errors'] = serializer.errors
    return render(request, template_name, context)


def _safe_next_url(request):
    next_url = request.POST.get('next') or request.GET.get('next') or ''
    if url_has_allowed_host_and_scheme(next_url, allowed_hosts={request.get_host()}):
        return next_url
    return ''


def login_view(request):
    if request.user.is_authenticated and request.user.is_staff:
        return redirect(_safe_next_url(request) or 'dashboard')

    if request.method == 'POST':
        username = request.POST.get('username', '').strip()
        password = request.POST.get('password', '')
        user = authenticate(request, username=username, password=password)

        if user is not None and user.is_active and user.is_staff:
            login(request, user)
            return redirect(_safe_next_url(request) or 'dashboard')

        if user is not None and not user.is_staff:
            messages.error(request, 'هذا الحساب لا يملك صلاحية الدخول إلى منظومة الإدارة.')
        else:
            messages.error(request, 'اسم المستخدم أو كلمة المرور غير صحيحة.')

    return render(request, 'login.html', {'next': _safe_next_url(request)})


def logout_view(request):
    logout(request)
    messages.success(request, 'تم تسجيل الخروج بنجاح.')
    return redirect('login')


@staff_required
def dashboard(request):
    context = {
        'total_orphans': Orphan.objects.count(),
        'total_donations': Donation.objects.count(),
        'total_volunteers': Volunteer.objects.count(),
    }
    return render(request, 'dashboard.html', context)


@staff_required
def orphans_list(request):
    context = {'orphans': Orphan.objects.all(), 'total_count': Orphan.objects.count()}
    if request.method == 'POST':
        return _save_from_serializer(
            request,
            OrphanSerializer,
            {'name': request.POST.get('o_name'), 'age': request.POST.get('o_age')},
            'orphans_list',
            'orphans.html',
            context,
        )
    return render(request, 'orphans.html', context)


@staff_required
def needs_list(request):
    care_homes = CareHome.objects.order_by('name')
    context = {
        'care_homes': care_homes,
        'care_homes_count': care_homes.count(),
        'need_status_choices': Need.STATUS_CHOICES,
        'need_priority_choices': Need.PRIORITY_CHOICES,
    }
    return render(request, 'needs.html', context)


@staff_required
def volunteers_view(request):
    context = {'volunteers': Volunteer.objects.all(), 'total_count': Volunteer.objects.count()}
    if request.method == 'POST':
        return _save_from_serializer(
            request,
            VolunteerSerializer,
            {'name': request.POST.get('v_name'), 'specialty': request.POST.get('v_specialty')},
            'volunteers_list',
            'volunteers.html',
            context,
        )
    return render(request, 'volunteers.html', context)


@staff_required
def volunteer_applications_view(request):
    context = {
        'applications': VolunteerApplication.objects.select_related('user', 'opportunity').all(),
        'application_status_choices': VolunteerApplication.STATUS_CHOICES,
    }
    return render(request, 'volunteer_applications.html', context)


@staff_required
def volunteer_opportunities_view(request):
    care_homes = CareHome.objects.order_by('name')
    opportunities = VolunteerOpportunity.objects.select_related('care_home').prefetch_related('applications').all()
    context = {
        'care_homes': care_homes,
        'care_homes_count': care_homes.count(),
        'opportunities': opportunities,
        'opportunity_category_choices': VolunteerOpportunity.CATEGORY_CHOICES,
        'opportunity_status_choices': VolunteerOpportunity.STATUS_CHOICES,
    }

    if request.method == 'POST':
        data = {
            'title': request.POST.get('title', '').strip(),
            'description': request.POST.get('description', '').strip(),
            'category': request.POST.get('category', '').strip(),
            'care_home': request.POST.get('care_home') or None,
            'required_volunteers': request.POST.get('required_volunteers') or 1,
            'required_skills': request.POST.get('required_skills', '').strip(),
            'location': request.POST.get('location', '').strip(),
            'start_date': request.POST.get('start_date') or None,
            'end_date': request.POST.get('end_date') or None,
            'status': request.POST.get('status') or VolunteerOpportunity.STATUS_OPEN,
            'image_url': request.POST.get('image_url', '').strip(),
        }
        serializer = VolunteerOpportunitySerializer(data=data, context={'request': request})
        if serializer.is_valid():
            serializer.save()
            messages.success(request, 'تمت إضافة فرصة التطوع بنجاح.')
            return redirect('volunteer_opportunities_list')
        context['form_errors'] = serializer.errors

    return render(request, 'volunteer_opportunities.html', context)


@staff_required
def donations_list(request):
    context = {
        'donations': Donation.objects.select_related('user', 'need').all(),
        'donation_status_choices': Donation.STATUS_CHOICES,
    }
    if request.method == 'POST':
        return _save_from_serializer(
            request,
            DonationSerializer,
            {'donor_name': request.POST.get('d_name'), 'item_type': request.POST.get('d_item')},
            'donations_list',
            'donations.html',
            context,
        )
    return render(request, 'donations.html', context)


@staff_required
@require_POST
def update_donation_status(request, pk):
    return _update_management_status(
        request,
        Donation,
        pk,
        Donation.STATUS_CHOICES,
        'donations_list',
        'التبرع',
    )


@staff_required
@require_POST
def update_volunteer_application_status(request, pk):
    return _update_management_status(
        request,
        VolunteerApplication,
        pk,
        VolunteerApplication.STATUS_CHOICES,
        'volunteer_applications_list',
        'طلب التطوع',
    )


@staff_required
def sponsors_list(request):
    context = {'sponsors': Sponsor.objects.all()}
    if request.method == 'POST':
        return _save_from_serializer(
            request,
            SponsorSerializer,
            {'name': request.POST.get('s_name'), 'phone': request.POST.get('s_phone')},
            'sponsors_list',
            'sponsors.html',
            context,
        )
    return render(request, 'sponsors.html', context)


@staff_required
def inventory_view(request):
    context = {'items': InventoryItem.objects.all()}
    if request.method == 'POST':
        return _save_from_serializer(
            request,
            InventorySerializer,
            {'item_name': request.POST.get('i_name'), 'quantity': request.POST.get('i_qty')},
            'inventory_view',
            'inventory.html',
            context,
        )
    return render(request, 'inventory.html', context)


@staff_required
def reports_view(request):
    context = {
        'total_orphans': Orphan.objects.count(),
        'total_volunteers': Volunteer.objects.count(),
        'total_donations': Donation.objects.count(),
        'total_sponsors': Sponsor.objects.count(),
        'total_items': InventoryItem.objects.count(),
    }
    return render(request, 'reports.html', context)


@staff_required
def settings_view(request):
    return render(request, 'settings.html')


@staff_required
def delete_orphan(request, pk):
    return _delete_management_record(request, Orphan, pk, 'orphans_list', 'orphan')


@staff_required
def delete_volunteer(request, pk):
    return _delete_management_record(request, Volunteer, pk, 'volunteers_list', 'volunteer')


@staff_required
def delete_donation(request, pk):
    return _delete_management_record(request, Donation, pk, 'donations_list', 'donation')


@staff_required
def delete_sponsor(request, pk):
    return _delete_management_record(request, Sponsor, pk, 'sponsors_list', 'sponsor')


@staff_required
def delete_inventory(request, pk):
    return _delete_management_record(request, InventoryItem, pk, 'inventory_view', 'inventory item')


def _delete_management_record(request, model_class, pk, redirect_name, label):
    if request.method != 'POST':
        messages.error(request, 'لم تكتمل عملية الحذف. يرجى استخدام زر التأكيد.')
        return redirect(redirect_name)

    record = get_object_or_404(model_class, pk=pk)
    record_name = str(record)

    if request.POST.get('confirm_delete') != 'yes':
        messages.error(request, f'لم تكتمل عملية حذف {record_name}؛ التأكيد مطلوب.')
        return redirect(redirect_name)

    try:
        record.delete()
    except ProtectedError as exc:
        logger.warning('Protected delete blocked for %s id=%s: %s', label, pk, exc, exc_info=True)
        messages.error(request, f'لا يمكن حذف {record_name} لأنه مرتبط بسجلات محفوظة أخرى.')
    except IntegrityError as exc:
        logger.warning('Database delete blocked for %s id=%s: %s', label, pk, exc, exc_info=True)
        messages.error(request, f'لم تكتمل عملية حذف {record_name} بسبب سجلات مرتبطة في قاعدة البيانات.')
    except Exception as exc:
        logger.exception('Unexpected delete failure for %s id=%s: %s', label, pk, exc)
        messages.error(request, f'لم تكتمل عملية حذف {record_name}.')
    else:
        messages.success(request, f'تم حذف {record_name} بنجاح.')

    return redirect(redirect_name)


def _update_management_status(request, model_class, pk, allowed_choices, redirect_name, label):
    record = get_object_or_404(model_class, pk=pk)
    new_status = request.POST.get('status', '').strip()
    allowed_values = {value for value, _ in allowed_choices}

    if new_status not in allowed_values:
        messages.error(request, f'لم يتم تحديث حالة {label}؛ الحالة غير صالحة.')
        return redirect(redirect_name)

    if record.status == new_status:
        messages.success(request, f'حالة {label} هي بالفعل {_status_label(new_status)}.')
        return redirect(redirect_name)

    record.status = new_status
    record.save(update_fields=['status', 'updated_at'])
    messages.success(request, f'تم تحديث حالة {label} إلى {_status_label(new_status)}.')
    return redirect(redirect_name)


@staff_required
def api_dashboard(request):
    orphans_data = OrphanSerializer(Orphan.objects.all(), many=True).data
    donations_data = DonationSerializer(Donation.objects.all(), many=True).data
    context = {
        'orphans_json': json.dumps(orphans_data, indent=4, ensure_ascii=False),
        'donations_json': json.dumps(donations_data, indent=4, ensure_ascii=False),
    }
    return render(request, 'api_dashboard.html', context)
