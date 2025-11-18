<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="mb-8">
      <h1 class="text-3xl font-bold text-gray-900">Welcome to BrightEat</h1>
      <p class="mt-2 text-gray-600">Your internal food ordering portal</p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
      <div class="bg-white rounded-lg shadow p-6">
        <h2 class="text-xl font-semibold mb-4">Create New Order</h2>
        <form @submit.prevent="createOrder" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Restaurant</label>
            <select
              v-model="newOrder.restaurant"
              @change="onRestaurantChange"
              required
              class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            >
              <option value="">Select restaurant</option>
              <option v-for="restaurant in ordersStore.restaurants" :key="restaurant.id" :value="restaurant.id">
                {{ restaurant.name }}
              </option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">
              Menu
              <span v-if="availableMenus.length > 0" class="text-red-500">*</span>
            </label>
            <div v-if="loadingMenus" class="mt-1 text-sm text-gray-500">Loading menus...</div>
            <select
              v-else
              v-model="newOrder.menu"
              :required="availableMenus.length > 0"
              :disabled="!newOrder.restaurant || availableMenus.length === 0"
              class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500 disabled:bg-gray-100 disabled:cursor-not-allowed"
            >
              <option :value="null">
                {{ availableMenus.length === 0 ? 'No menus available for this restaurant' : 'Select a menu' }}
              </option>
              <option v-for="menu in availableMenus" :key="menu.id" :value="menu.id">
                {{ menu.name }}
              </option>
            </select>
            <p v-if="availableMenus.length > 0" class="mt-1 text-xs text-gray-500">Select a menu for this order</p>
            <p v-else-if="newOrder.restaurant" class="mt-1 text-xs text-gray-500">No menus available. You can still create the order and add items manually.</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Cutoff Time</label>
            <input
              v-model="newOrder.cutoff_time"
              type="datetime-local"
              class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <div class="flex items-center">
            <input
              v-model="newOrder.is_private"
              type="checkbox"
              id="is_private"
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
            />
            <label for="is_private" class="ml-2 block text-sm text-gray-700">
              Make this order private (only participants can see it)
            </label>
          </div>
          <button
            type="submit"
            :disabled="loading"
            class="w-full bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 disabled:opacity-50"
          >
            {{ loading ? 'Creating...' : 'Create Order' }}
          </button>
        </form>
      </div>

      <div class="bg-white rounded-lg shadow p-6">
        <h2 class="text-xl font-semibold mb-4">Join Order</h2>
        <form @submit.prevent="joinOrder" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Order Code</label>
            <input
              v-model="joinCode"
              type="text"
              placeholder="Enter order code"
              required
              class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <button
            type="submit"
            :disabled="loading"
            class="w-full bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 disabled:opacity-50"
          >
            {{ loading ? 'Joining...' : 'Join Order' }}
          </button>
        </form>
      </div>
    </div>

    <div class="bg-white rounded-lg shadow">
      <div class="px-6 py-4 border-b border-gray-200">
        <h2 class="text-xl font-semibold">Active Orders</h2>
      </div>
      <div class="p-6">
        <div v-if="loadingOrders" class="text-center py-8">Loading...</div>
        <div v-else-if="activeOrders.length === 0" class="text-center py-8 text-gray-500">
          No active orders
        </div>
        <div v-else class="space-y-4">
          <div
            v-for="order in activeOrders"
            :key="order.id"
            class="border border-gray-200 rounded-lg p-4 hover:shadow-md transition"
          >
            <div class="flex justify-between items-start">
              <div>
                <h3 class="text-lg font-semibold">{{ order.restaurant_name }}</h3>
                <p class="text-sm text-gray-600">Code: {{ order.code }}</p>
                <p class="text-sm text-gray-600">Collector: {{ order.collector_name }}</p>
                <p class="text-sm text-gray-600">Status: 
                  <span :class="{
                    'text-green-600': order.status === 'OPEN',
                    'text-yellow-600': order.status === 'LOCKED',
                    'text-blue-600': order.status === 'ORDERED',
                    'text-gray-600': order.status === 'CLOSED',
                  }">
                    {{ order.status }}
                  </span>
                </p>
              </div>
              <router-link
                :to="`/orders/${order.code}`"
                class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
              >
                View
              </router-link>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { useOrdersStore } from '../stores/orders'
import { useAuthStore } from '../stores/auth'

const router = useRouter()
const ordersStore = useOrdersStore()
const authStore = useAuthStore()

const newOrder = ref({
  restaurant: '',
  menu: null,
  cutoff_time: '',
  is_private: false,
})
const joinCode = ref('')
const loading = ref(false)
const loadingOrders = ref(false)
const availableMenus = ref([])
const loadingMenus = ref(false)

const activeOrders = computed(() => {
  return ordersStore.orders.filter(o => o.status !== 'CLOSED')
})

async function onRestaurantChange() {
  if (!newOrder.value.restaurant) {
    availableMenus.value = []
    newOrder.value.menu = null
    return
  }
  
  loadingMenus.value = true
  try {
    const result = await ordersStore.fetchMenus(parseInt(newOrder.value.restaurant))
    if (result.success) {
      availableMenus.value = result.data.filter(menu => menu.is_active)
    } else {
      availableMenus.value = []
    }
    newOrder.value.menu = null
  } catch (error) {
    console.error('Error fetching menus:', error)
    availableMenus.value = []
  } finally {
    loadingMenus.value = false
  }
}

onMounted(async () => {
  loadingOrders.value = true
  await ordersStore.fetchRestaurants()
  await ordersStore.fetchOrders()
  loadingOrders.value = false
})

async function createOrder() {
  if (!newOrder.value.restaurant) {
    alert('Please select a restaurant')
    return
  }
  
  // Require menu if menus are available
  if (availableMenus.value.length > 0 && !newOrder.value.menu) {
    alert('Please select a menu for this restaurant')
    return
  }
  
  loading.value = true
  const orderData = {
    restaurant: parseInt(newOrder.value.restaurant),
    is_private: newOrder.value.is_private,
  }
  
  // Include menu if selected
  if (newOrder.value.menu) {
    orderData.menu = parseInt(newOrder.value.menu)
  }
  
  // Only include cutoff_time if it's provided
  if (newOrder.value.cutoff_time) {
    orderData.cutoff_time = newOrder.value.cutoff_time
  }
  
  const result = await ordersStore.createOrder(orderData)
  
  if (result.success) {
    router.push(`/orders/${result.data.code}`)
    // Reset form
    newOrder.value = { restaurant: '', menu: null, cutoff_time: '', is_private: false }
    availableMenus.value = []
  } else {
    alert('Failed to create order: ' + (result.error?.detail || JSON.stringify(result.error)))
  }
  loading.value = false
}

async function joinOrder() {
  loading.value = true
  const result = await ordersStore.fetchOrderByCode(joinCode.value.toUpperCase())
  
  if (result.success) {
    router.push(`/orders/${joinCode.value.toUpperCase()}`)
  } else {
    alert('Order not found')
  }
  loading.value = false
}
</script>

