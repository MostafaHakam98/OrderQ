from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.exceptions import ValidationError
from django.db.models import Q, Sum, Count
from django.utils import timezone
from django.db import transaction
from .models import (
    User, Restaurant, Menu, MenuItem, CollectionOrder, 
    OrderItem, Payment, AuditLog, FeePreset, Recommendation
)
from .serializers import (
    UserSerializer, UserRegistrationSerializer, LoginSerializer, ChangePasswordSerializer,
    RestaurantSerializer, MenuSerializer, MenuItemSerializer, CollectionOrderSerializer,
    OrderItemSerializer, PaymentSerializer, AuditLogSerializer, FeePresetSerializer,
    RecommendationSerializer
)
from rest_framework_simplejwt.tokens import RefreshToken


class IsManagerOrReadOnly(permissions.BasePermission):
    """Permission for managers to edit, others can only read"""
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return True
        return request.user.is_authenticated and request.user.role == 'manager'


class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        # All authenticated users can see all users (needed for assignment feature)
        return User.objects.all()
    
    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
    
    @action(detail=False, methods=['get'])
    def me(self, request):
        serializer = self.get_serializer(request.user)
        return Response(serializer.data)
    
    @action(detail=False, methods=['post'])
    def change_password(self, request):
        """Change user password"""
        serializer = ChangePasswordSerializer(data=request.data, context={'request': request})
        if serializer.is_valid():
            user = request.user
            user.set_password(serializer.validated_data['new_password'])
            user.save()
            return Response({'message': 'Password changed successfully'}, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class LoginView(APIView):
    """Custom login view that accepts username or email"""
    permission_classes = [permissions.AllowAny]
    
    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.validated_data['user']
            refresh = RefreshToken.for_user(user)
            return Response({
                'access': str(refresh.access_token),
                'refresh': str(refresh),
            }, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class RegisterView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        # Only managers/admins can create accounts
        if request.user.role != 'manager':
            return Response(
                {'error': 'Only managers can create user accounts'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        serializer = UserRegistrationSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            return Response({
                'user': UserSerializer(user).data,
                'message': 'User created successfully'
            }, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class RestaurantViewSet(viewsets.ModelViewSet):
    queryset = Restaurant.objects.all()
    serializer_class = RestaurantSerializer
    permission_classes = [IsManagerOrReadOnly]
    
    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


class MenuViewSet(viewsets.ModelViewSet):
    queryset = Menu.objects.all()
    serializer_class = MenuSerializer
    permission_classes = [IsManagerOrReadOnly]
    
    def get_queryset(self):
        restaurant_id = self.request.query_params.get('restaurant')
        if restaurant_id:
            return Menu.objects.filter(restaurant_id=restaurant_id)
        return Menu.objects.all()
    
    def perform_create(self, serializer):
        serializer.save()


class MenuItemViewSet(viewsets.ModelViewSet):
    queryset = MenuItem.objects.all()
    serializer_class = MenuItemSerializer
    permission_classes = [IsManagerOrReadOnly]
    
    def get_queryset(self):
        menu_id = self.request.query_params.get('menu')
        restaurant_id = self.request.query_params.get('restaurant')
        queryset = MenuItem.objects.all()
        
        if menu_id:
            queryset = queryset.filter(menu_id=menu_id)
        elif restaurant_id:
            queryset = queryset.filter(menu__restaurant_id=restaurant_id)
        
        return queryset
    
    def perform_create(self, serializer):
        serializer.save()


class CollectionOrderViewSet(viewsets.ModelViewSet):
    queryset = CollectionOrder.objects.all()
    serializer_class = CollectionOrderSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        status_filter = self.request.query_params.get('status')
        queryset = CollectionOrder.objects.all()
        
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        
        # Show public orders to everyone, private orders only to participants/managers
        # Also show orders where user is assigned
        if user.role != 'manager':
            queryset = queryset.filter(
                Q(is_private=False) |  # Public orders
                Q(collector=user) |    # Orders I collected
                Q(items__user=user) |  # Orders I'm participating in
                Q(assigned_users=user) # Orders I'm assigned to
            ).distinct()
        
        return queryset
    
    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context
    
    def perform_create(self, serializer):
        assigned_users = serializer.validated_data.pop('assigned_users', [])
        order = serializer.save(collector=self.request.user)
        
        # If assigned_users is provided, set them and make order private
        if assigned_users:
            order.assigned_users.set(assigned_users)
            order.is_private = True
            order.save()
        
        AuditLog.objects.create(
            order=order,
            user=self.request.user,
            action='created',
            details={'restaurant': order.restaurant.name, 'assigned_users': [u.username for u in assigned_users] if assigned_users else None}
        )
    
    def update(self, request, *args, **kwargs):
        """Allow updating assigned_users for open orders"""
        instance = self.get_object()
        if instance.status != 'OPEN':
            return Response(
                {'error': 'Can only update assigned users for open orders'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Handle assigned_users separately - many-to-many fields need special handling
        assigned_users_data = request.data.get('assigned_users')
        assignment_items = request.data.get('assignment_items')
        assignment_total_cost = request.data.get('assignment_total_cost')
        
        # Call parent update first (this handles other fields)
        response = super().update(request, *args, **kwargs)
        
        # Now handle assigned_users if provided
        if assigned_users_data is not None:
            instance.refresh_from_db()
            if assigned_users_data:
                instance.assigned_users.set(assigned_users_data)
                instance.is_private = True
                
                # If assignment_items and assignment_total_cost are provided, create items for each assigned user
                if assignment_items and assignment_total_cost:
                    from decimal import Decimal
                    from .models import OrderItem
                    
                    num_users = len(assigned_users_data)
                    if num_users > 0:
                        cost_per_user = Decimal(str(assignment_total_cost)) / Decimal(str(num_users))
                        unit_price = cost_per_user / Decimal(str(assignment_items))
                        
                        # Delete existing items for assigned users (to avoid duplicates)
                        OrderItem.objects.filter(
                            order=instance,
                            user__in=assigned_users_data
                        ).delete()
                        
                        # Create items for each assigned user
                        for user_id in assigned_users_data:
                            user = User.objects.get(id=user_id)
                            for i in range(assignment_items):
                                OrderItem.objects.create(
                                    order=instance,
                                    user=user,
                                    custom_name=f"Shared Item {i+1}",
                                    custom_price=unit_price,
                                    quantity=1,
                                    unit_price=unit_price,
                                    total_price=unit_price
                                )
                        
                        AuditLog.objects.create(
                            order=instance,
                            user=request.user,
                            action='items_auto_created',
                            details={
                                'assigned_users': [u.username for u in User.objects.filter(id__in=assigned_users_data)],
                                'items_per_user': assignment_items,
                                'total_cost': float(assignment_total_cost),
                                'cost_per_user': float(cost_per_user)
                            }
                        )
            else:
                instance.assigned_users.clear()
            instance.save()
            # Return updated data with assigned_users
            serializer = self.get_serializer(instance, context={'request': request})
            return Response(serializer.data)
        
        return response
    
    def destroy(self, request, *args, **kwargs):
        order = self.get_object()
        # Only collector or manager can delete
        if order.collector != request.user and request.user.role != 'manager':
            return Response(
                {'error': 'Only collector or manager can delete order'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Collectors can only delete OPEN orders, managers can delete any order
        if order.status != 'OPEN' and request.user.role != 'manager':
            return Response(
                {'error': 'Can only delete open orders'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        AuditLog.objects.create(
            order=order,
            user=request.user,
            action='deleted',
            details={'restaurant': order.restaurant.name, 'code': order.code, 'status': order.status}
        )
        
        return super().destroy(request, *args, **kwargs)
    
    @action(detail=True, methods=['post'])
    def lock(self, request, pk=None):
        order = self.get_object()
        if order.status != 'OPEN':
            return Response(
                {'error': 'Order is not open'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if order.collector != request.user:
            return Response(
                {'error': 'Only collector can lock order'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        order.status = 'LOCKED'
        order.locked_at = timezone.now()
        order.save()
        
        # Calculate payments based on fee split rule
        self._calculate_payments(order)
        
        AuditLog.objects.create(
            order=order,
            user=request.user,
            action='locked',
            details={}
        )
        
        return Response(CollectionOrderSerializer(order).data)
    
    @action(detail=True, methods=['post'])
    def unlock(self, request, pk=None):
        order = self.get_object()
        if order.status != 'LOCKED':
            return Response(
                {'error': 'Order is not locked'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Collector or manager can unlock
        if order.collector != request.user and request.user.role != 'manager':
            return Response(
                {'error': 'Only collector or manager can unlock order'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        order.status = 'OPEN'
        order.locked_at = None
        order.save()
        
        # Delete payments when unlocking (they'll be recalculated on next lock)
        Payment.objects.filter(order=order).delete()
        
        AuditLog.objects.create(
            order=order,
            user=request.user,
            action='unlocked',
            details={}
        )
        
        return Response(CollectionOrderSerializer(order).data)
    
    @action(detail=True, methods=['post'])
    def mark_ordered(self, request, pk=None):
        order = self.get_object()
        if order.status != 'LOCKED':
            return Response(
                {'error': 'Order must be locked first'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if order.collector != request.user:
            return Response(
                {'error': 'Only collector can mark as ordered'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        order.status = 'ORDERED'
        order.ordered_at = timezone.now()
        order.save()
        
        AuditLog.objects.create(
            order=order,
            user=request.user,
            action='ordered',
            details={}
        )
        
        return Response(CollectionOrderSerializer(order).data)
    
    @action(detail=True, methods=['post'])
    def close(self, request, pk=None):
        order = self.get_object()
        if order.status not in ['ORDERED', 'LOCKED']:
            return Response(
                {'error': 'Order must be ordered or locked first'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if order.collector != request.user and request.user.role != 'manager':
            return Response(
                {'error': 'Only collector or manager can close order'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        order.status = 'CLOSED'
        order.closed_at = timezone.now()
        order.save()
        
        AuditLog.objects.create(
            order=order,
            user=request.user,
            action='closed',
            details={}
        )
        
        return Response(CollectionOrderSerializer(order).data)
    
    @action(detail=False, methods=['get'])
    def by_code(self, request):
        code = request.query_params.get('code')
        if not code:
            return Response(
                {'error': 'Code parameter required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            order = CollectionOrder.objects.get(code=code.upper())
            
            # Check if order has assigned users - if so, only they can access it
            if order.assigned_users.exists():
                if request.user not in order.assigned_users.all() and request.user.role != 'manager' and order.collector != request.user:
                    return Response(
                        {'error': 'You are not assigned to this order'}, 
                        status=status.HTTP_403_FORBIDDEN
                    )
            
            serializer = self.get_serializer(order, context={'request': request})
            return Response(serializer.data)
        except CollectionOrder.DoesNotExist:
            return Response(
                {'error': 'Order not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
    
    @action(detail=True, methods=['post'])
    def transfer_collector(self, request, pk=None):
        """Transfer collector role to another participant"""
        order = self.get_object()
        new_collector_id = request.data.get('new_collector_id')
        
        if not new_collector_id:
            return Response(
                {'error': 'new_collector_id is required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Only current collector or manager can transfer
        if order.collector != request.user and request.user.role != 'manager':
            return Response(
                {'error': 'Only collector or manager can transfer collector role'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Only allow transfer if order is OPEN
        if order.status != 'OPEN':
            return Response(
                {'error': 'Can only transfer collector for open orders'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            new_collector = User.objects.get(id=new_collector_id)
        except User.DoesNotExist:
            return Response(
                {'error': 'User not found'}, 
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Check if new collector is a participant
        if not order.items.filter(user=new_collector).exists() and new_collector != order.collector:
            return Response(
                {'error': 'New collector must be a participant in the order'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        old_collector = order.collector
        order.collector = new_collector
        order.save()
        
        AuditLog.objects.create(
            order=order,
            user=request.user,
            action='fee_updated',
            details={'action': 'collector_transferred', 'old_collector': old_collector.username, 'new_collector': new_collector.username}
        )
        
        return Response(CollectionOrderSerializer(order, context={'request': request}).data)
    
    @action(detail=False, methods=['get'])
    def pending_payments(self, request):
        """Get all orders where the user has pending payments"""
        payments = Payment.objects.filter(
            user=request.user,
            is_paid=False,
            order__status__in=['LOCKED', 'ORDERED', 'CLOSED']
        ).select_related('order', 'order__restaurant', 'order__collector')
        
        result = []
        for payment in payments:
            result.append({
                'order_id': payment.order.id,
                'order_code': payment.order.code,
                'restaurant_name': payment.order.restaurant.name,
                'collector_name': payment.order.collector.username,
                'amount': float(payment.amount),
                'payment_id': payment.id,
                'order_status': payment.order.status,
            })
        
        return Response(result)
    
    @action(detail=False, methods=['get'])
    def monthly_report(self, request):
        """Monthly report: total spend, collector count, unpaid incidents"""
        user_id = request.query_params.get('user_id', request.user.id)
        if request.user.role != 'manager' and str(request.user.id) != str(user_id):
            return Response(
                {'error': 'Permission denied'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        user = User.objects.get(id=user_id)
        now = timezone.now()
        start_of_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        
        # Total spend (as participant)
        total_spend = Payment.objects.filter(
            user=user,
            order__created_at__gte=start_of_month
        ).aggregate(total=Sum('amount'))['total'] or 0
        
        # Number of times as collector
        collector_count = CollectionOrder.objects.filter(
            collector=user,
            created_at__gte=start_of_month
        ).count()
        
        # Unpaid incidents
        unpaid_count = Payment.objects.filter(
            user=user,
            is_paid=False,
            order__status__in=['LOCKED', 'ORDERED', 'CLOSED'],
            order__created_at__gte=start_of_month
        ).count()
        
        return Response({
            'user': UserSerializer(user).data,
            'month': start_of_month.strftime('%B %Y'),
            'total_spend': float(total_spend),
            'collector_count': collector_count,
            'unpaid_count': unpaid_count
        })
    
    def _calculate_payments(self, order):
        """Calculate payments based on fee split rule"""
        total_items = order.get_total_items_cost()
        total_fees = order.delivery_fee + order.tip + order.service_fee
        participants = order.get_participants()
        
        # Delete existing payments
        Payment.objects.filter(order=order).delete()
        
        if order.fee_split_rule == 'collector_pays':
            # Collector pays all fees
            for user in participants:
                user_items_total = sum(
                    item.total_price for item in order.items.filter(user=user)
                )
                payment = Payment.objects.create(
                    order=order,
                    user=user,
                    amount=user_items_total
                )
                # Auto-mark collector's payment as paid
                if user == order.collector:
                    payment.is_paid = True
                    payment.paid_at = timezone.now()
                    payment.save()
        elif order.fee_split_rule == 'equal':
            # Split fees equally among participants
            fee_per_person = total_fees / len(participants) if participants else 0
            for user in participants:
                user_items_total = sum(
                    item.total_price for item in order.items.filter(user=user)
                )
                payment = Payment.objects.create(
                    order=order,
                    user=user,
                    amount=user_items_total + fee_per_person
                )
                # Auto-mark collector's payment as paid
                if user == order.collector:
                    payment.is_paid = True
                    payment.paid_at = timezone.now()
                    payment.save()
        elif order.fee_split_rule == 'proportional':
            # Split fees proportionally based on item cost
            for user in participants:
                user_items_total = sum(
                    item.total_price for item in order.items.filter(user=user)
                )
                if total_items > 0:
                    user_fee_share = (user_items_total / total_items) * total_fees
                else:
                    user_fee_share = 0
                payment = Payment.objects.create(
                    order=order,
                    user=user,
                    amount=user_items_total + user_fee_share
                )
                # Auto-mark collector's payment as paid
                if user == order.collector:
                    payment.is_paid = True
                    payment.paid_at = timezone.now()
                    payment.save()
        # Custom split handled separately via API


class OrderItemViewSet(viewsets.ModelViewSet):
    queryset = OrderItem.objects.all()
    serializer_class = OrderItemSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        order_id = self.request.query_params.get('order')
        user_id = self.request.query_params.get('user')
        queryset = OrderItem.objects.all()
        
        if order_id:
            queryset = queryset.filter(order_id=order_id)
        if user_id:
            queryset = queryset.filter(user_id=user_id)
        
        # Users can only see their own items unless they're the collector or manager
        if self.request.user.role != 'manager':
            order_ids = CollectionOrder.objects.filter(
                Q(collector=self.request.user) | Q(items__user=self.request.user)
            ).values_list('id', flat=True)
            queryset = queryset.filter(order_id__in=order_ids)
        
        return queryset
    
    def perform_create(self, serializer):
        order = serializer.validated_data['order']
        
        # Check if order is open
        if order.status != 'OPEN':
            raise ValidationError("Cannot add items to a locked/closed order")
        
        # Check if order has assigned users - if so, only they can add items
        if order.assigned_users.exists():
            if self.request.user not in order.assigned_users.all() and self.request.user.role != 'manager' and order.collector != self.request.user:
                raise ValidationError("You are not assigned to this order")
        
        # Set unit price
        if serializer.validated_data.get('menu_item'):
            serializer.validated_data['unit_price'] = serializer.validated_data['menu_item'].price
        elif serializer.validated_data.get('custom_price'):
            serializer.validated_data['unit_price'] = serializer.validated_data['custom_price']
        
        item = serializer.save(user=self.request.user)
        
        AuditLog.objects.create(
            order=order,
            user=self.request.user,
            action='item_added',
            details={
                'item_name': item.menu_item.name if item.menu_item else item.custom_name,
                'quantity': item.quantity,
                'price': float(item.total_price)
            }
        )
    
    def perform_destroy(self, instance):
        order = instance.order
        if order.status != 'OPEN':
            raise ValidationError("Cannot remove items from a locked/closed order")
        
        if instance.user != self.request.user and order.collector != self.request.user and self.request.user.role != 'manager':
            raise ValidationError("Permission denied")
        
        AuditLog.objects.create(
            order=order,
            user=self.request.user,
            action='item_removed',
            details={
                'item_name': instance.menu_item.name if instance.menu_item else instance.custom_name
            }
        )
        
        instance.delete()


class PaymentViewSet(viewsets.ModelViewSet):
    queryset = Payment.objects.all()
    serializer_class = PaymentSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        order_id = self.request.query_params.get('order')
        user_id = self.request.query_params.get('user')
        queryset = Payment.objects.all()
        
        if order_id:
            queryset = queryset.filter(order_id=order_id)
        if user_id:
            queryset = queryset.filter(user_id=user_id)
        
        # Users can only see their own payments or payments for orders they collected
        if self.request.user.role != 'manager':
            order_ids = CollectionOrder.objects.filter(
                Q(collector=self.request.user) | Q(payments__user=self.request.user)
            ).values_list('id', flat=True)
            queryset = queryset.filter(order_id__in=order_ids)
        
        return queryset
    
    @action(detail=True, methods=['post'])
    def mark_paid(self, request, pk=None):
        payment = self.get_object()
        
        # Allow user to mark their own payment as paid, or collector/manager to mark any payment
        if payment.user != request.user and payment.order.collector != request.user and request.user.role != 'manager':
            return Response(
                {'error': 'Only the payer, collector, or manager can mark as paid'}, 
                status=status.HTTP_403_FORBIDDEN
            )
        
        payment.is_paid = True
        payment.paid_at = timezone.now()
        payment.save()
        
        return Response(PaymentSerializer(payment).data)


class AuditLogViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = AuditLog.objects.all()
    serializer_class = AuditLogSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        order_id = self.request.query_params.get('order')
        queryset = AuditLog.objects.all()
        
        if order_id:
            queryset = queryset.filter(order_id=order_id)
        
        return queryset


class FeePresetViewSet(viewsets.ModelViewSet):
    queryset = FeePreset.objects.all()
    serializer_class = FeePresetSerializer
    permission_classes = [IsManagerOrReadOnly]


class RecommendationViewSet(viewsets.ModelViewSet):
    queryset = Recommendation.objects.all()
    serializer_class = RecommendationSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return Recommendation.objects.all().select_related('user')
    
    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
