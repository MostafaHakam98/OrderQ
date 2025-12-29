"""
Utility functions for broadcasting order updates via WebSocket
"""
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from django.db.models import Prefetch
from .serializers import CollectionOrderSerializer
from .models import OrderItem, Payment


def broadcast_order_update(order):
    """
    Broadcast order update to all connected WebSocket clients for this order
    Refreshes the order from database with all related data before serializing
    """
    channel_layer = get_channel_layer()
    if not channel_layer:
        return  # Channels not configured
    
    # Refresh order from database with all related data to ensure latest items/payments are included
    from .models import CollectionOrder
    refreshed_order = CollectionOrder.objects.prefetch_related(
        Prefetch('items', queryset=OrderItem.objects.select_related('user', 'menu_item').order_by('-created_at')),
        Prefetch('payments', queryset=Payment.objects.select_related('user').order_by('-created_at')),
        'assigned_users'
    ).select_related('restaurant', 'menu', 'collector').get(id=order.id)
    
    # Serialize order data with request context (if available)
    # Note: We can't pass request context here, but serializer should work without it for most fields
    serializer = CollectionOrderSerializer(refreshed_order)
    order_data = serializer.data
    
    # Broadcast to the order's room group
    room_group_name = f'order_{order.id}'
    
    async_to_sync(channel_layer.group_send)(
        room_group_name,
        {
            'type': 'order_update',
            'order': order_data
        }
    )


def broadcast_new_order(order):
    """
    Broadcast new order creation to all connected WebSocket clients via the general notifications channel
    This allows all users to be notified when a new order is created, regardless of which device created it
    """
    channel_layer = get_channel_layer()
    if not channel_layer:
        return  # Channels not configured
    
    # Refresh order from database with all related data
    from .models import CollectionOrder
    refreshed_order = CollectionOrder.objects.prefetch_related(
        Prefetch('items', queryset=OrderItem.objects.select_related('user', 'menu_item').order_by('-created_at')),
        Prefetch('payments', queryset=Payment.objects.select_related('user').order_by('-created_at')),
        'assigned_users'
    ).select_related('restaurant', 'menu', 'collector').get(id=order.id)
    
    # Serialize order data
    serializer = CollectionOrderSerializer(refreshed_order)
    order_data = serializer.data
    
    # Broadcast to the general notifications group
    async_to_sync(channel_layer.group_send)(
        'notifications',
        {
            'type': 'new_order',
            'order': order_data
        }
    )
    
    # Also broadcast to the specific order's room group
    broadcast_order_update(order)

