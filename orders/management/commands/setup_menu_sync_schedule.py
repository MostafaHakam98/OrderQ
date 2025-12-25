"""
Django management command to set up periodic menu syncing with Celery Beat.

This command creates a periodic task that syncs menus from Talabat on a schedule.
"""
from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta

try:
    from django_celery_beat.models import PeriodicTask, IntervalSchedule
    CELERY_BEAT_AVAILABLE = True
except ImportError:
    CELERY_BEAT_AVAILABLE = False


class Command(BaseCommand):
    help = 'Set up periodic menu syncing with Celery Beat'

    def add_arguments(self, parser):
        parser.add_argument(
            '--interval',
            type=int,
            default=6,
            help='Sync interval in hours (default: 6)',
        )
        parser.add_argument(
            '--task-name',
            type=str,
            default='sync-talabat-menus-periodic',
            help='Name for the periodic task',
        )

    def handle(self, *args, **options):
        if not CELERY_BEAT_AVAILABLE:
            self.stdout.write(
                self.style.ERROR(
                    'django-celery-beat is not installed. '
                    'Install it with: pip install django-celery-beat'
                )
            )
            return

        interval_hours = options['interval']
        task_name = options['task_name']

        # Create or get interval schedule
        schedule, created = IntervalSchedule.objects.get_or_create(
            every=interval_hours,
            period=IntervalSchedule.HOURS,
        )

        if created:
            self.stdout.write(
                self.style.SUCCESS(f'Created interval schedule: every {interval_hours} hours')
            )
        else:
            self.stdout.write(f'Using existing interval schedule: every {interval_hours} hours')

        # Create or update periodic task
        task, created = PeriodicTask.objects.get_or_create(
            name=task_name,
            defaults={
                'task': 'sync_talabat_menus',
                'interval': schedule,
                'enabled': True,
            }
        )

        if not created:
            # Update existing task
            task.task = 'sync_talabat_menus'
            task.interval = schedule
            task.enabled = True
            task.save()
            self.stdout.write(
                self.style.SUCCESS(f'Updated periodic task: {task_name}')
            )
        else:
            self.stdout.write(
                self.style.SUCCESS(f'Created periodic task: {task_name}')
            )

        self.stdout.write(
            self.style.SUCCESS(
                f'\nMenu syncing is now scheduled to run every {interval_hours} hours.\n'
                f'Make sure Celery Beat is running: celery -A BrightEat beat -l info'
            )
        )

