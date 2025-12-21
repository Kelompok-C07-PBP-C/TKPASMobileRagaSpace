from django.db import migrations


def seed_categories(apps, schema_editor):
    Category = apps.get_model("manajemen_lapangan", "Category")
    defaults = [
        ("futsal", "Futsal Arenas"),
        ("basketball", "Basketball Courts"),
        ("badminton", "Badminton Halls"),
        ("tennis", "Tennis Courts"),
        ("football", "Football Fields"),
    ]
    for slug, name in defaults:
        Category.objects.get_or_create(slug=slug, defaults={"name": name})


def unseed_categories(apps, schema_editor):
    Category = apps.get_model("manajemen_lapangan", "Category")
    Category.objects.filter(slug__in=[
        "futsal",
        "basketball",
        "badminton",
        "tennis",
        "football",
    ]).delete()


class Migration(migrations.Migration):

    dependencies = [
        ("manajemen_lapangan", "0001_initial"),
    ]

    operations = [
        migrations.RunPython(seed_categories, unseed_categories),
    ]
