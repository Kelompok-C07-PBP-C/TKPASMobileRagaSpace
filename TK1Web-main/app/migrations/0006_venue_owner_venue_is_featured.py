from django.db import migrations, models
from django.conf import settings


class Migration(migrations.Migration):

    dependencies = [
        ('app', '0005_allow_anonymous_comments'),
    ]

    operations = [
        migrations.AddField(
            model_name='venue',
            name='is_featured',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='venue',
            name='owner',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=models.CASCADE,
                related_name='owned_venues',
                to=settings.AUTH_USER_MODEL,
            ),
        ),
    ]
