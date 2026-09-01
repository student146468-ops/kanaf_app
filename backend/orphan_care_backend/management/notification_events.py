from .models import Donation, Notification, UserProfile, VolunteerApplication
from .views_api import (
    _care_home_notification_user,
    _create_notification,
    _create_notifications_for_role,
)


def notify_need_published(need, actor=None):
    care_home = need.care_home
    if care_home is None:
        return

    care_home_user = _care_home_notification_user(care_home)
    if care_home_user:
        _create_notification(
            care_home_user,
            Notification.TYPE_STATUS_UPDATE,
            'Need published',
            f'The need "{need.title}" was published for {care_home.name}.',
        )

    excluded = [actor.pk] if actor and getattr(actor, 'pk', None) else []
    _create_notifications_for_role(
        UserProfile.ROLE_DONOR,
        Notification.TYPE_STATUS_UPDATE,
        'New urgent need',
        f'{care_home.name} published a new need: {need.title}.',
        exclude_user_ids=excluded,
    )


def notify_volunteer_opportunity_published(opportunity, actor=None):
    care_home = opportunity.care_home
    if care_home is None:
        return

    care_home_user = _care_home_notification_user(care_home)
    if care_home_user:
        _create_notification(
            care_home_user,
            Notification.TYPE_VOLUNTEER,
            'Volunteer opportunity published',
            f'The opportunity "{opportunity.title}" was published for {care_home.name}.',
        )

    excluded = [actor.pk] if actor and getattr(actor, 'pk', None) else []
    _create_notifications_for_role(
        UserProfile.ROLE_VOLUNTEER,
        Notification.TYPE_VOLUNTEER,
        'New volunteer opportunity',
        f'{care_home.name} published a new volunteer opportunity: {opportunity.title}.',
        exclude_user_ids=excluded,
    )


def notify_donation_created(donation, actor=None):
    if donation.user_id:
        _create_notification(
            donation.user,
            Notification.TYPE_DONATION,
            'Donation request received',
            'Your donation request was received and is pending review.',
        )

    care_home = getattr(getattr(donation, 'need', None), 'care_home', None)
    if care_home is None:
        return

    care_home_user = _care_home_notification_user(care_home)
    actor_id = getattr(actor, 'pk', None)
    if care_home_user and care_home_user.pk not in {donation.user_id, actor_id}:
        _create_notification(
            care_home_user,
            Notification.TYPE_DONATION,
            'New donation request',
            f'A new donation was submitted for {donation.need.title}.',
        )


def notify_donation_status_changed(donation):
    if not donation.user_id:
        return
    _create_notification(
        donation.user,
        Notification.TYPE_STATUS_UPDATE,
        'Donation status updated',
        f'Your donation request is now {donation.status}.',
    )


def notify_volunteer_application_submitted(application, actor=None):
    if application.user_id:
        _create_notification(
            application.user,
            Notification.TYPE_VOLUNTEER,
            'Volunteer application submitted',
            f'Your application for {application.opportunity.title} was submitted.',
        )

    care_home_user = _care_home_notification_user(application.opportunity.care_home)
    actor_id = getattr(actor, 'pk', None)
    if care_home_user and care_home_user.pk not in {application.user_id, actor_id}:
        _create_notification(
            care_home_user,
            Notification.TYPE_VOLUNTEER,
            'New volunteer application',
            f'A volunteer applied to {application.opportunity.title}.',
        )


def notify_volunteer_application_status_changed(application, title='Volunteer application status updated'):
    if not application.user_id:
        return
    _create_notification(
        application.user,
        Notification.TYPE_VOLUNTEER,
        title,
        f'Your application for {application.opportunity.title} is now {application.status}.',
    )


def notify_management_status_changed(record):
    if isinstance(record, Donation):
        notify_donation_status_changed(record)
    elif isinstance(record, VolunteerApplication):
        notify_volunteer_application_status_changed(record)
