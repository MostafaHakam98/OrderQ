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

