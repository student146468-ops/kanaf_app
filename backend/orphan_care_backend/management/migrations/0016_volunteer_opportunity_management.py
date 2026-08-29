import django.db.models.deletion
from django.db import migrations, models


def attach_existing_opportunities_to_only_home(apps, schema_editor):
    VolunteerOpportunity = apps.get_model('management', 'VolunteerOpportunity')
    CareHome = apps.get_model('management', 'CareHome')

    orphaned = VolunteerOpportunity.objects.filter(care_home__isnull=True)
    if not orphaned.exists():
        return

    homes = list(CareHome.objects.order_by('id')[:2])
    if len(homes) == 1:
        orphaned.update(care_home=homes[0])
        return

    raise RuntimeError(
        'Volunteer opportunities without care_home exist. Link them to real care homes before applying this migration.'
    )


class Migration(migrations.Migration):

    dependencies = [
        ('management', '0015_alter_need_category_alter_need_required_quantity'),
    ]

    operations = [
        migrations.AddField(
            model_name='volunteeropportunity',
            name='category',
            field=models.CharField(
                choices=[
                    ('general', 'General'),
                    ('education', 'Education'),
                    ('logistics', 'Logistics'),
                    ('health', 'Health'),
                    ('psychological', 'Psychological support'),
                    ('events', 'Events'),
                ],
                db_index=True,
                default='general',
                max_length=40,
            ),
        ),
        migrations.AddField(
            model_name='volunteeropportunity',
            name='image_url',
            field=models.URLField(blank=True, default=''),
            preserve_default=False,
        ),
        migrations.RunPython(
            attach_existing_opportunities_to_only_home,
            migrations.RunPython.noop,
        ),
        migrations.AlterField(
            model_name='volunteeropportunity',
            name='care_home',
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.CASCADE,
                related_name='opportunities',
                to='management.carehome',
            ),
        ),
        migrations.AddConstraint(
            model_name='volunteeropportunity',
            constraint=models.CheckConstraint(
                check=models.Q(current_volunteers__lte=models.F('required_volunteers')),
                name='opportunity_current_not_over_required',
            ),
        ),
    ]
