# Generated manually

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0011_orderitem_note'),
    ]

    operations = [
        migrations.AlterField(
            model_name='user',
            name='role',
            field=models.CharField(
                choices=[('admin', 'Administrator'), ('manager', 'Menu Manager'), ('user', 'Normal User')],
                default='user',
                max_length=10
            ),
        ),
    ]

