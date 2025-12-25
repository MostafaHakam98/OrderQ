"""
Celery tasks for menu syncing.
"""
from celery import shared_task
from django.core.management import call_command
from django.utils import timezone
import logging

logger = logging.getLogger(__name__)


@shared_task(name='sync_talabat_menus')
def sync_talabat_menus_task(restaurant_name=None):
    """
    Celery task to sync menus from Talabat.
    
    Args:
        restaurant_name: Optional restaurant name to sync only that restaurant.
                        If None, syncs all restaurants from restaurants_to_sync.json
    """
    logger.info(f'Starting Talabat menu sync task at {timezone.now()}')
    
    try:
        command_args = []
        if restaurant_name:
            command_args.extend(['--restaurant', restaurant_name])
        
        call_command('sync_talabat_menus', *command_args)
        logger.info('Talabat menu sync task completed successfully')
        return {'status': 'success', 'timestamp': timezone.now().isoformat()}
    except Exception as e:
        logger.error(f'Talabat menu sync task failed: {e}', exc_info=True)
        return {'status': 'error', 'error': str(e), 'timestamp': timezone.now().isoformat()}

