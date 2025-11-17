# Generated manually

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('orders', '0004_collectionorder_assigned_users_and_more'),
    ]

    operations = [
        migrations.RemoveField(
            model_name='recommendation',
            name='restaurant',
        ),
        migrations.AddField(
            model_name='recommendation',
            name='category',
            field=models.CharField(choices=[('feature', 'New Feature'), ('improvement', 'Improvement'), ('bug', 'Bug Report'), ('ui', 'UI/UX'), ('other', 'Other')], default='other', help_text='Type of recommendation', max_length=20),
        ),
        migrations.AddField(
            model_name='recommendation',
            name='title',
            field=models.CharField(default='', help_text='Brief title for the recommendation', max_length=200),
            preserve_default=False,
        ),
    ]

