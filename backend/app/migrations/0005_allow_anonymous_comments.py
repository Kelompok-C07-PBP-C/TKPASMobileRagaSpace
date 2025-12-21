from django.db import migrations, models
from django.conf import settings


def delete_demo_comments(apps, schema_editor):
    Comment = apps.get_model('app', 'Comment')
    app_label, model_name = settings.AUTH_USER_MODEL.split('.')
    User = apps.get_model(app_label, model_name)
    demo_users = User.objects.filter(username__startswith='demo.')
    Comment.objects.filter(user__in=demo_users).delete()


class Migration(migrations.Migration):

    dependencies = [
        ('app', '0004_profile'),
    ]

    operations = [
        migrations.AlterField(
            model_name='comment',
            name='user',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=models.CASCADE,
                related_name='comments',
                to=settings.AUTH_USER_MODEL,
            ),
        ),
        migrations.RunPython(delete_demo_comments, migrations.RunPython.noop),
    ]
