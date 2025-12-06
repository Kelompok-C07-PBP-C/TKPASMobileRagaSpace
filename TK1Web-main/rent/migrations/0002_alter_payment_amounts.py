from decimal import Decimal

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("rent", "0001_initial"),
    ]

    operations = [
        migrations.AlterField(
            model_name="payment",
            name="total_amount",
            field=models.DecimalField(decimal_places=2, max_digits=12),
        ),
        migrations.AlterField(
            model_name="payment",
            name="deposit_amount",
            field=models.DecimalField(decimal_places=2, default=Decimal("10000"), max_digits=12),
        ),
    ]
