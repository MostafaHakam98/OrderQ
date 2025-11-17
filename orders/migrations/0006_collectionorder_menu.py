# Generated manually

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0005_update_recommendation_model'),
    ]

    operations = [
        migrations.AddField(
            model_name='collectionorder',
            name='menu',
            field=models.ForeignKey(blank=True, help_text='Optional menu for this order', null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='orders', to='orders.menu'),
        ),
    ]

