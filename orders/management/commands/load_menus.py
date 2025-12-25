from django.core.management.base import BaseCommand
import json
from pathlib import Path
from django.contrib.auth import get_user_model
from orders.models import Restaurant, Menu, MenuItem

User = get_user_model()


class Command(BaseCommand):
    help = 'Load restaurants and menus from JSON configuration file'

    def add_arguments(self, parser):
        parser.add_argument(
            '--file',
            type=str,
            required=True,
            help='Path to JSON configuration file',
        )
        parser.add_argument(
            '--manager',
            type=str,
            default='manager',
            help='Username of the manager to assign restaurants to',
        )

    def handle(self, *args, **options):
        file_path = Path(options['file'])
        manager_username = options['manager']
        
        if not file_path.exists():
            self.stdout.write(self.style.ERROR(f'File not found: {file_path}'))
            return
        
        try:
            manager = User.objects.get(username=manager_username, role='manager')
        except User.DoesNotExist:
            self.stdout.write(self.style.ERROR(f'Manager user not found: {manager_username}'))
            return
        
        with open(file_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        self.stdout.write(f'Loading menus from {file_path}...')
        
        for restaurant_data in config.get('restaurants', []):
            restaurant, created = Restaurant.objects.get_or_create(
                name=restaurant_data['name'],
                defaults={
                    'description': restaurant_data.get('description', ''),
                    'created_by': manager,
                }
            )
            
            if created:
                self.stdout.write(self.style.SUCCESS(f'Created restaurant: {restaurant.name}'))
            else:
                self.stdout.write(f'Restaurant already exists: {restaurant.name}')
            
            for menu_data in restaurant_data.get('menus', []):
                menu, created = Menu.objects.get_or_create(
                    restaurant=restaurant,
                    name=menu_data['name'],
                    defaults={
                        'is_active': menu_data.get('is_active', True),
                    }
                )
                
                if created:
                    self.stdout.write(self.style.SUCCESS(f'  Created menu: {menu.name}'))
                else:
                    self.stdout.write(f'  Menu already exists: {menu.name}')
                
                for item_data in menu_data.get('items', []):
                    item, created = MenuItem.objects.get_or_create(
                        menu=menu,
                        name=item_data['name'],
                        defaults={
                            'description': item_data.get('description', ''),
                            'price': item_data['price'],
                            'is_available': item_data.get('is_available', True),
                        }
                    )
                    
                    if created:
                        self.stdout.write(self.style.SUCCESS(f'    Created item: {item.name} - {item.price} EGP'))
                    else:
                        # Update existing item
                        item.description = item_data.get('description', item.description)
                        item.price = item_data['price']
                        item.is_available = item_data.get('is_available', item.is_available)
                        item.save()
                        self.stdout.write(f'    Updated item: {item.name} - {item.price} EGP')
        
        self.stdout.write(self.style.SUCCESS('\nMenu loading completed!'))

