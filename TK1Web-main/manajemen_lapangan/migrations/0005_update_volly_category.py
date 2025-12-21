from django.db import migrations


def update_volly_category(apps, schema_editor):
    Category = apps.get_model("manajemen_lapangan", "Category")

    try:
        category = Category.objects.get(slug="volley-ball")
    except Category.DoesNotExist:
        category = Category.objects.filter(name__iexact="Volley Ball").first()

    if category is None:
        Category.objects.get_or_create(slug="volly-ball", defaults={"name": "Volly Ball"})
        return

    updated_fields = []
    if category.slug != "volly-ball":
        category.slug = "volly-ball"
        updated_fields.append("slug")
    if category.name != "Volly Ball":
        category.name = "Volly Ball"
        updated_fields.append("name")
    if updated_fields:
        category.save(update_fields=updated_fields)


def revert_volly_category(apps, schema_editor):
    Category = apps.get_model("manajemen_lapangan", "Category")

    try:
        category = Category.objects.get(slug="volly-ball")
    except Category.DoesNotExist:
        category = Category.objects.filter(name__iexact="Volly Ball").first()

    if category is None:
        return

    updated_fields = []
    if category.slug != "volley-ball":
        category.slug = "volley-ball"
        updated_fields.append("slug")
    if category.name != "Volley Ball":
        category.name = "Volley Ball"
        updated_fields.append("name")
    if updated_fields:
        category.save(update_fields=updated_fields)


class Migration(migrations.Migration):
    dependencies = [
        ("manajemen_lapangan", "0004_alter_venue_available_end_time_and_more"),
    ]

    operations = [
        migrations.RunPython(update_volly_category, revert_volly_category),
    ]
