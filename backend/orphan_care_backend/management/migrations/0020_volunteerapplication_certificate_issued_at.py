from django.db import migrations, models
from django.db.models import F


def preserve_existing_completion_dates(apps, schema_editor):
    applications = apps.get_model('management', 'VolunteerApplication')
    # Historical completion timestamps were not stored separately. Freeze their
    # last recorded update; do not replace them with the deployment date.
    applications.objects.using(schema_editor.connection.alias).filter(
        status='completed', certificate_issued_at__isnull=True
    ).update(certificate_issued_at=F('updated_at'))


class Migration(migrations.Migration):
    dependencies = [('management', '0019_emailverificationcode')]

    operations = [
        migrations.AddField(
            model_name='volunteerapplication',
            name='certificate_issued_at',
            field=models.DateTimeField(blank=True, editable=False, null=True),
        ),
        migrations.RunPython(
            preserve_existing_completion_dates,
            migrations.RunPython.noop,
        ),
    ]
