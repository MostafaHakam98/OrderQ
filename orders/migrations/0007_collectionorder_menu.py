# Generated manually

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0006_alter_recommendation_text'),
    ]

    operations = [
        migrations.AddField(
            model_name='collectionorder',
            name='menu',
            field=models.ForeignKey(blank=True, help_text='Optional menu for this order', null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='orders', to='orders.menu'),
        ),
    ]

