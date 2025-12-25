import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.contrib.auth import get_user_model
from .models import CollectionOrder
from .serializers import CollectionOrderSerializer

User = get_user_model()


class OrderConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.order_id = self.scope['url_route']['kwargs']['order_id']
        self.room_group_name = f'order_{self.order_id}'
        
        # Verify user is authenticated
        if not self.scope['user'].is_authenticated:
            await self.close()
            return
        
        # Verify user has access to this order
        has_access = await self.check_order_access(self.order_id, self.scope['user'])
        if not has_access:
            await self.close()
            return
        
        # Join room group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )
        
        await self.accept()
        
        # Send current order state
        order_data = await self.get_order_data(self.order_id)
        if order_data:
            await self.send(text_data=json.dumps({
                'type': 'order_update',
                'order': order_data
            }))
    
    async def disconnect(self, close_code):
        # Leave room group
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )
    
    # Receive message from WebSocket
    async def receive(self, text_data):
        text_data_json = json.loads(text_data)
        message_type = text_data_json.get('type')
        
        if message_type == 'ping':
            await self.send(text_data=json.dumps({'type': 'pong'}))
    
    # Receive message from room group
    async def order_update(self, event):
        # Send message to WebSocket
        await self.send(text_data=json.dumps({
            'type': 'order_update',
            'order': event['order']
        }))
    
    @database_sync_to_async
    def check_order_access(self, order_id, user):
        """Check if user has access to this order"""
        try:
            order = CollectionOrder.objects.get(id=order_id)
            # Allow if:
            # - User is manager
            # - User is collector
            # - Order is not private
            # - User is assigned to the order
            # - User has items in the order
            if user.role == 'manager':
                return True
            if order.collector == user:
                return True
            if not order.is_private:
                return True
            if order.assigned_users.filter(id=user.id).exists():
                return True
            if order.items.filter(user=user).exists():
                return True
            return False
        except CollectionOrder.DoesNotExist:
            return False
    
    @database_sync_to_async
    def get_order_data(self, order_id):
        """Get serialized order data"""
        try:
            order = CollectionOrder.objects.prefetch_related(
                'items__user',
                'items__menu_item',
                'payments__user',
                'assigned_users'
            ).get(id=order_id)
            serializer = CollectionOrderSerializer(order)
            return serializer.data
        except CollectionOrder.DoesNotExist:
            return None

