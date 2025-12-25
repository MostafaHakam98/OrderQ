# Testing Backend with curl

This guide shows how to test the BrightEat backend API using curl commands.

## Backend URL
```
http://51.20.151.57:19992/api
```

## 1. Basic Connectivity Test

Test if the server is reachable:

```bash
curl -v http://51.20.151.57:19992/api/
```

Or test a specific endpoint (should return 401 or 403 if server is working):

```bash
curl -v http://51.20.151.57:19992/api/orders/
```

## 2. Authentication Tests

### Login (Get JWT Tokens)

**Using username:**
```bash
curl -X POST http://51.20.151.57:19992/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{
    "username": "manager",
    "password": "manager123"
  }'
```

**Using email:**
```bash
curl -X POST http://51.20.151.57:19992/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{
    "email": "manager@example.com",
    "password": "manager123"
  }'
```

**Expected Response:**
```json
{
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

**Save the token for later use:**
```bash
# Save response to variable (bash)
RESPONSE=$(curl -s -X POST http://51.20.151.57:19992/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "manager", "password": "manager123"}')

# Extract access token
ACCESS_TOKEN=$(echo $RESPONSE | grep -o '"access":"[^"]*' | cut -d'"' -f4)
echo "Access Token: $ACCESS_TOKEN"
```

### Refresh Token

```bash
curl -X POST http://51.20.151.57:19992/api/auth/refresh/ \
  -H "Content-Type: application/json" \
  -d '{
    "refresh": "YOUR_REFRESH_TOKEN_HERE"
  }'
```

## 3. Authenticated Endpoint Tests

Replace `YOUR_ACCESS_TOKEN` with the actual token from login.

### Get Current User Info

```bash
curl -X GET http://51.20.151.57:19992/api/users/me/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### List All Users

```bash
curl -X GET http://51.20.151.57:19992/api/users/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### List Restaurants

```bash
curl -X GET http://51.20.151.57:19992/api/restaurants/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### List Orders

```bash
# All orders
curl -X GET http://51.20.151.57:19992/api/orders/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# Filter by status
curl -X GET "http://51.20.151.57:19992/api/orders/?status=OPEN" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### List Menus

```bash
# All menus
curl -X GET http://51.20.151.57:19992/api/menus/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# Filter by restaurant
curl -X GET "http://51.20.151.57:19992/api/menus/?restaurant=1" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### List Menu Items

```bash
# All menu items
curl -X GET http://51.20.151.57:19992/api/menu-items/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# Filter by menu
curl -X GET "http://51.20.151.57:19992/api/menu-items/?menu=1" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Get Pending Payments

```bash
curl -X GET http://51.20.151.57:19992/api/orders/pending_payments/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Get Monthly Report

```bash
# For current user
curl -X GET http://51.20.151.57:19992/api/orders/monthly_report/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"

# For specific user
curl -X GET "http://51.20.151.57:19992/api/orders/monthly_report/?user_id=1" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

### Get Recommendations

```bash
curl -X GET http://51.20.151.57:19992/api/recommendations/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

## 4. Complete Test Script

Save this as `test_backend.sh` and make it executable:

```bash
#!/bin/bash

BASE_URL="http://51.20.151.57:19992/api"
USERNAME="manager"
PASSWORD="manager123"

echo "=== Testing Backend Connectivity ==="
echo ""

# Test 1: Basic connectivity
echo "1. Testing basic connectivity..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/orders/")
if [ "$RESPONSE" = "401" ] || [ "$RESPONSE" = "403" ] || [ "$RESPONSE" = "200" ]; then
  echo "✅ Server is reachable (HTTP $RESPONSE)"
else
  echo "❌ Server not reachable (HTTP $RESPONSE)"
  exit 1
fi
echo ""

# Test 2: Login
echo "2. Testing login..."
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login/" \
  -H "Content-Type: application/json" \
  -d "{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}")

if echo "$LOGIN_RESPONSE" | grep -q "access"; then
  echo "✅ Login successful"
  ACCESS_TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"access":"[^"]*' | cut -d'"' -f4)
  REFRESH_TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"refresh":"[^"]*' | cut -d'"' -f4)
  echo "   Access Token: ${ACCESS_TOKEN:0:50}..."
else
  echo "❌ Login failed"
  echo "   Response: $LOGIN_RESPONSE"
  exit 1
fi
echo ""

# Test 3: Get current user
echo "3. Testing authenticated endpoint (get current user)..."
USER_RESPONSE=$(curl -s -X GET "$BASE_URL/users/me/" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

if echo "$USER_RESPONSE" | grep -q "username"; then
  echo "✅ Authenticated request successful"
  echo "   User: $(echo $USER_RESPONSE | grep -o '"username":"[^"]*' | cut -d'"' -f4)"
else
  echo "❌ Authenticated request failed"
  echo "   Response: $USER_RESPONSE"
fi
echo ""

# Test 4: List restaurants
echo "4. Testing list restaurants..."
RESTAURANTS_RESPONSE=$(curl -s -X GET "$BASE_URL/restaurants/" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

if echo "$RESTAURANTS_RESPONSE" | grep -q "results\|id"; then
  echo "✅ Restaurants endpoint working"
  RESTAURANT_COUNT=$(echo $RESTAURANTS_RESPONSE | grep -o '"id"' | wc -l)
  echo "   Found $RESTAURANT_COUNT restaurant(s)"
else
  echo "⚠️  Restaurants endpoint returned unexpected response"
  echo "   Response: $RESTAURANTS_RESPONSE"
fi
echo ""

# Test 5: List orders
echo "5. Testing list orders..."
ORDERS_RESPONSE=$(curl -s -X GET "$BASE_URL/orders/" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

if echo "$ORDERS_RESPONSE" | grep -q "results\|id"; then
  echo "✅ Orders endpoint working"
  ORDER_COUNT=$(echo $ORDERS_RESPONSE | grep -o '"id"' | wc -l)
  echo "   Found $ORDER_COUNT order(s)"
else
  echo "⚠️  Orders endpoint returned unexpected response"
  echo "   Response: $ORDERS_RESPONSE"
fi
echo ""

echo "=== All Tests Complete ==="
```

Make it executable and run:
```bash
chmod +x test_backend.sh
./test_backend.sh
```

## 5. Quick One-Liner Tests

**Test if server is up:**
```bash
curl -s -o /dev/null -w "%{http_code}" http://51.20.151.57:19992/api/orders/
```

**Quick login and get token:**
```bash
curl -s -X POST http://51.20.151.57:19992/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"manager","password":"manager123"}' | jq -r '.access'
```

**Test authenticated endpoint:**
```bash
TOKEN=$(curl -s -X POST http://51.20.151.57:19992/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"username":"manager","password":"manager123"}' | jq -r '.access')

curl -X GET http://51.20.151.57:19992/api/users/me/ \
  -H "Authorization: Bearer $TOKEN"
```

## 6. Common Issues

### Connection Refused
- Backend server is not running
- Firewall blocking port 19992
- Wrong IP address

### 401 Unauthorized
- Token expired or invalid
- Missing Authorization header
- Wrong token format

### 403 Forbidden
- User doesn't have permission for the endpoint
- Manager-only endpoint accessed by regular user

### CORS Errors (in browser)
- CORS is configured on the backend
- curl doesn't have CORS restrictions

## 7. Pretty Print JSON Responses

Install `jq` for better JSON formatting:
```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq
```

Then pipe curl output through jq:
```bash
curl -X GET http://51.20.151.57:19992/api/restaurants/ \
  -H "Authorization: Bearer $TOKEN" | jq
```

