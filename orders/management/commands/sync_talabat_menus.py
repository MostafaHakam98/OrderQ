"""
Django management command to sync menus from Talabat.

This command:
1. Reads restaurants from restaurants_to_sync.json
2. Scrapes menus from Talabat
3. Performs diff + upsert (only updates changed items)
4. Stores menus in the database
"""
import json
import sys
from pathlib import Path
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.db import transaction
from django.conf import settings

from orders.models import Restaurant, Menu, MenuItem

# Import scraper functions
# Add scripts directory to path using Django's BASE_DIR
scripts_dir = settings.BASE_DIR / 'scripts'
if not scripts_dir.exists():
    raise ImportError(f"Scripts directory not found at {scripts_dir}. Make sure scripts/talabat_scrap.py exists.")

if str(scripts_dir) not in sys.path:
sys.path.insert(0, str(scripts_dir))

try:
    from talabat_scrap import (
        fetch_html_with_retries,
        extract_next_data,
        parse_items,
        compute_menu_hash,
    )
except ImportError as e:
    raise ImportError(f"Failed to import talabat_scrap module from {scripts_dir}. Error: {e}")

User = get_user_model()


class Command(BaseCommand):
    help = 'Sync menus from Talabat restaurants using the scraper'

    def add_arguments(self, parser):
        parser.add_argument(
            '--file',
            type=str,
            default=None,
            help='Path to restaurants_to_sync.json file (required if --talabat-url is not provided)',
        )
        parser.add_argument(
            '--manager',
            type=str,
            default='manager',
            help='Username of the manager to assign restaurants to',
        )
        parser.add_argument(
            '--restaurant',
            type=str,
            default=None,
            help='Sync only a specific restaurant by name',
        )
        parser.add_argument(
            '--talabat-url',
            type=str,
            default=None,
            help='Talabat URL to sync directly (bypasses JSON file). Use this when syncing a menu that was added via API.',
        )
        parser.add_argument(
            '--timeout',
            type=int,
            default=30,
            help='HTTP timeout seconds',
        )
        parser.add_argument(
            '--retries',
            type=int,
            default=3,
            help='Number of retries (default: 3)',
        )
        parser.add_argument(
            '--backoff',
            type=float,
            default=2.0,
            help='Backoff base seconds (default: 2.0, exponential backoff)',
        )

    def handle(self, *args, **options):
        manager_username = options['manager']
        restaurant_filter = options.get('restaurant')
        talabat_url_direct = options.get('talabat_url')
        
        try:
            manager = User.objects.get(username=manager_username, role='manager')
        except User.DoesNotExist:
            self.stdout.write(self.style.ERROR(f'Manager user not found: {manager_username}'))
            return
        
        # If talabat_url is provided directly, sync that menu
        if talabat_url_direct:
            # Find the menu by URL
            menu = Menu.objects.filter(talabat_url=talabat_url_direct).first()
            if not menu:
                self.stdout.write(self.style.ERROR(f'No menu found with Talabat URL: {talabat_url_direct}'))
                return
            
            restaurant_name = menu.restaurant.name
            self.stdout.write(f'\nSyncing menu directly from URL: {talabat_url_direct}')
            self.stdout.write(f'Restaurant: {restaurant_name}')
            
            try:
                self.sync_restaurant_menu(
                    restaurant_name=restaurant_name,
                    talabat_url=talabat_url_direct,
                    manager=manager,
                    timeout=options['timeout'],
                    retries=options['retries'],
                    backoff=options['backoff'],
                )
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'  Error syncing: {e}'))
                raise
            
            self.stdout.write(self.style.SUCCESS('\nMenu syncing completed!'))
            return
        
        # Otherwise, sync from JSON file
        file_path = options.get('file')
        if not file_path:
            self.stdout.write(self.style.ERROR('Either --file or --talabat-url must be provided'))
            return
        
        file_path = Path(file_path)
        
        if not file_path.exists():
            self.stdout.write(self.style.ERROR(f'File not found: {file_path}'))
            return
        
        with open(file_path, 'r', encoding='utf-8') as f:
            restaurants_config = json.load(f)
        
        self.stdout.write(f'Loading restaurants from {file_path}...')
        
        for restaurant_config in restaurants_config:
            restaurant_name = restaurant_config.get('name')
            talabat_url = restaurant_config.get('url')
            
            if not restaurant_name or not talabat_url:
                self.stdout.write(self.style.WARNING(f'Skipping invalid entry: {restaurant_config}'))
                continue
            
            if restaurant_filter and restaurant_name.lower() != restaurant_filter.lower():
                continue
            
            self.stdout.write(f'\nProcessing: {restaurant_name}')
            self.stdout.write(f'  URL: {talabat_url}')
            
            try:
                self.sync_restaurant_menu(
                    restaurant_name=restaurant_name,
                    talabat_url=talabat_url,
                    manager=manager,
                    timeout=options['timeout'],
                    retries=options['retries'],
                    backoff=options['backoff'],
                )
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'  Error syncing {restaurant_name}: {e}'))
                continue
        
        self.stdout.write(self.style.SUCCESS('\nMenu syncing completed!'))

    def sync_restaurant_menu(self, restaurant_name, talabat_url, manager, timeout, retries, backoff):
        """Sync a single restaurant's menu from Talabat"""
        debug_path = Path('debug_blocked.html')
        
        # Get or create restaurant
        restaurant, created = Restaurant.objects.get_or_create(
            name=restaurant_name,
            defaults={
                'description': f'Auto-synced from Talabat',
                'created_by': manager,
            }
        )
        
        if created:
            self.stdout.write(self.style.SUCCESS(f'  Created restaurant: {restaurant.name}'))
        else:
            self.stdout.write(f'  Restaurant exists: {restaurant.name}')
        
        # Fetch and parse menu from Talabat
        try:
            self.stdout.write(f'  Fetching HTML from {talabat_url}...')
            html = fetch_html_with_retries(
                url=talabat_url,
                timeout=timeout,
                retries=retries,
                backoff=backoff,
                debug_path=debug_path,
            )
            self.stdout.write(f'  ✓ HTML fetched ({len(html)} bytes)')
            
            self.stdout.write('  Extracting __NEXT_DATA__...')
            next_data = extract_next_data(html)
            self.stdout.write('  ✓ __NEXT_DATA__ extracted successfully')
            
            # Debug: Check the structure
            try:
                page_props = next_data.get("props", {}).get("pageProps", {})
                initial_menu_state = page_props.get("initialMenuState", {})
                menu_data = initial_menu_state.get("menuData", {})
                items_raw = menu_data.get("items", [])
                self.stdout.write(f'  Found {len(items_raw) if items_raw else 0} raw items in menuData')
                
                if not items_raw:
                    # Try alternative paths
                    self.stdout.write('  Trying alternative paths...')
                    # Check if items are in a different location
                    if "initialMenuState" in page_props:
                        self.stdout.write(f'  initialMenuState keys: {list(initial_menu_state.keys())}')
                    if "menuData" in initial_menu_state:
                        self.stdout.write(f'  menuData keys: {list(menu_data.keys())}')
            except Exception as debug_e:
                self.stdout.write(self.style.WARNING(f'  Debug check failed: {debug_e}'))
            
            self.stdout.write('  Parsing items...')
            items, page_props = parse_items(next_data, debug_path=debug_path, raw_html_for_debug=html)
            self.stdout.write(f'  Parsed {len(items)} items')
            
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'  Failed to scrape menu: {e}'))
            if debug_path.exists():
                self.stdout.write(f'  Debug HTML saved to: {debug_path}')
            raise
        
        if not items:
            self.stdout.write(self.style.WARNING(f'  No items found in menu after parsing'))
            self.stdout.write(self.style.WARNING(f'  Check {debug_path} if it exists for debugging'))
            return
        
        # Compute menu hash
        menu_hash = compute_menu_hash(items)
        
        # Get or create menu
        menu, menu_created = Menu.objects.get_or_create(
            restaurant=restaurant,
            talabat_url=talabat_url,
            defaults={
                'name': 'Main Menu',  # Default name, can be customized
                'is_active': True,
                'menu_hash': menu_hash,
                'last_synced_at': timezone.now(),
            }
        )
        
        # Check if menu has changed
        if not menu_created and menu.menu_hash == menu_hash:
            self.stdout.write(f'  Menu unchanged (hash: {menu_hash[:16]}...)')
            return
        
        # Menu has changed or is new - perform diff + upsert
        self.stdout.write(f'  Menu changed or new (hash: {menu_hash[:16]}...)')
        
        with transaction.atomic():
            # Get existing items by hash
            existing_hashes = set(
                MenuItem.objects.filter(menu=menu, item_hash__isnull=False)
                .values_list('item_hash', flat=True)
            )
            
            new_items = []
            updated_items = []
            current_hashes = set()
            
            for talabat_item in items:
                item_hash = talabat_item.item_hash
                current_hashes.add(item_hash)
                
                # Build item data
                item_data = {
                    'name': talabat_item.name,
                    'description': talabat_item.description,
                    'price': talabat_item.price,
                    'is_available': True,
                    'talabat_id': talabat_item.id,
                    'item_hash': item_hash,
                    'section_name': talabat_item.section_name,
                }
                
                # Try to find existing item by hash
                existing_item = MenuItem.objects.filter(
                    menu=menu,
                    item_hash=item_hash
                ).first()
                
                if existing_item:
                    # Update existing item
                    for key, value in item_data.items():
                        if key != 'menu':  # Don't update the menu FK
                            setattr(existing_item, key, value)
                    existing_item.save()
                    updated_items.append(existing_item)
                else:
                    # Create new item
                    new_item = MenuItem(menu=menu, **item_data)
                    new_items.append(new_item)
            
            # Bulk create new items
            if new_items:
                MenuItem.objects.bulk_create(new_items)
                self.stdout.write(self.style.SUCCESS(f'  Created {len(new_items)} new items'))
            
            # Report updated items
            if updated_items:
                self.stdout.write(f'  Updated {len(updated_items)} existing items')
            
            # Mark items as unavailable if they're no longer in the menu
            removed_hashes = existing_hashes - current_hashes
            if removed_hashes:
                removed_count = MenuItem.objects.filter(
                    menu=menu,
                    item_hash__in=removed_hashes
                ).update(is_available=False)
                self.stdout.write(f'  Marked {removed_count} items as unavailable')
            
            # Update menu metadata
            menu.menu_hash = menu_hash
            menu.last_synced_at = timezone.now()
            menu.save()
        
        self.stdout.write(self.style.SUCCESS(f'  ✓ Synced {len(items)} items'))

