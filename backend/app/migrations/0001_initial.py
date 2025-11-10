from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
from django.core.validators import MaxValueValidator, MinValueValidator
import django.utils.timezone


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='BookingDate',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('start_date', models.DateField()),
                ('end_date', models.DateField()),
            ],
            options={
                'ordering': ['start_date', 'end_date'],
            },
        ),
        migrations.CreateModel(
            name='Venue',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('title', models.CharField(max_length=255)),
                ('description', models.TextField()),
                ('facilities', models.JSONField(blank=True, default=list)),
                ('price', models.PositiveIntegerField(validators=[MinValueValidator(0)])),
                ('location', models.CharField(max_length=255)),
                ('image', models.ImageField(blank=True, upload_to='venues/')),
                ('type', models.CharField(choices=[('Tennis', 'Tennis'), ('Badminton', 'Badminton'), ('Basket', 'Basket'), ('Sepak Bola', 'Sepak Bola'), ('Mini Soccer', 'Mini Soccer'), ('Futsal', 'Futsal'), ('Billiard', 'Billiard'), ('Tenis Meja', 'Tenis Meja'), ('Volly Ball', 'Volly Ball')], default='Tennis', max_length=20)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'ordering': ['title'],
            },
        ),
        migrations.CreateModel(
            name='Comment',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('rating', models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])),
                ('comment', models.TextField()),
                ('date', models.DateField(default=django.utils.timezone.localdate)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='comments', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ['-date', '-id'],
            },
        ),
        migrations.CreateModel(
            name='Booking',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('has_been_paid', models.BooleanField(default=False)),
                ('date_paid', models.DateField(blank=True, null=True)),
                ('notes', models.TextField(blank=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('date', models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name='booking', to='app.bookingdate')),
                ('user', models.ForeignKey(null=True, on_delete=django.db.models.deletion.CASCADE, related_name='bookings', to=settings.AUTH_USER_MODEL)),
                ('venue', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='bookings', to='app.venue')),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
        migrations.CreateModel(
            name='CommentVenue',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('comment', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='venue_links', to='app.comment')),
                ('venue', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='comment_links', to='app.venue')),
            ],
            options={
                'unique_together': {('comment', 'venue')},
            },
        ),
        migrations.AddField(
            model_name='comment',
            name='venue',
            field=models.ManyToManyField(related_name='comments', through='app.CommentVenue', to='app.venue'),
        ),
    ]
