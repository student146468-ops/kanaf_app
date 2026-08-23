from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('management', '0013_phoneverificationcode'),
    ]

    operations = [
        migrations.AddField(
            model_name='volunteeropportunity',
            name='required_skills',
            field=models.CharField(blank=True, max_length=300),
        ),
    ]
