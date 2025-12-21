from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ("interaksi", "0001_initial"),
    ]

    operations = [
        migrations.AlterUniqueTogether(
            name="review",
            unique_together=set(),
        ),
    ]

