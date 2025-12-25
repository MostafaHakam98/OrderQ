"""
Utility functions for broadcasting order updates via WebSocket
"""
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from .serializers import CollectionOrderSerializer


def broadcast_order_update(order):
    """
    Broadcast order update to all connected WebSocket clients for this order
    """
    channel_layer = get_channel_layer()
    if not channel_layer:
        return  # Channels not configured
    
    # Serialize order data
    serializer = CollectionOrderSerializer(order)
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

