"""
Custom middleware for WebSocket JWT authentication
"""
from urllib.parse import parse_qs
from channels.middleware import BaseMiddleware
from channels.db import database_sync_to_async
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.tokens import AccessToken
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError

User = get_user_model()


class JWTAuthMiddleware(BaseMiddleware):
    """
    Custom middleware to authenticate WebSocket connections using JWT tokens.
    Token can be provided via:
    1. Query parameter: ?token=...
    2. Authorization header (if supported by browser)
    """
    
    async def __call__(self, scope, receive, send):
        # Extract token from query string
        query_string = scope.get('query_string', b'').decode()
        query_params = parse_qs(query_string)
        token = None
        
        # Try to get token from query parameters
        if 'token' in query_params:
            token = query_params['token'][0]
        
        # If no token in query, try to get from headers (for future use)
        if not token:
            headers = dict(scope.get('headers', []))
            auth_header = headers.get(b'authorization', b'').decode()
            if auth_header.startswith('Bearer '):
                token = auth_header[7:]
        
        # Authenticate user
        if token:
            try:
                user = await self.get_user_from_token(token)
                scope['user'] = user
            except (InvalidToken, TokenError):
                scope['user'] = AnonymousUser()
        else:
            scope['user'] = AnonymousUser()
        
        return await super().__call__(scope, receive, send)
    
    @database_sync_to_async
    def get_user_from_token(self, token):
        """Validate JWT token and return user"""
        try:
            access_token = AccessToken(token)
            user_id = access_token['user_id']
            user = User.objects.get(id=user_id)
            return user
        except (InvalidToken, TokenError, User.DoesNotExist):
            raise InvalidToken("Invalid token")


def JWTAuthMiddlewareStack(inner):
    """Stack JWT auth middleware with other middleware"""
    return JWTAuthMiddleware(inner)

