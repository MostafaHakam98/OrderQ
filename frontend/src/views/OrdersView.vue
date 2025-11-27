<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="mb-8 flex justify-between items-center">
      <h1 class="text-3xl font-bold text-gray-900 dark:text-white">All Orders</h1>
      <div class="flex space-x-2">
        <button
          v-for="status in ['', 'OPEN', 'LOCKED', 'ORDERED', 'CLOSED']"
          :key="status"
          @click="filterStatus = status; fetchOrders()"
          :class="[
            'px-4 py-2 rounded-md',
            filterStatus === status
              ? 'bg-blue-600 dark:bg-blue-500 text-white'
              : 'bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-300 dark:hover:bg-gray-600'
          ]"
        >
          {{ status || 'All' }}
        </button>
      </div>
    </div>

    <div v-if="loading" class="text-center py-8 text-gray-600 dark:text-gray-400">Loading...</div>
    <div v-else-if="ordersStore.orders.length === 0" class="text-center py-8 text-gray-500 dark:text-gray-400">
      No orders found
    </div>
    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <div
        v-for="order in ordersStore.orders"
        :key="order.id"
        class="bg-white dark:bg-gray-800 rounded-lg shadow p-6 hover:shadow-lg transition"
      >
        <h3 class="text-lg font-semibold mb-2 dark:text-white">{{ order.restaurant_name }}</h3>
        <p class="text-sm text-gray-600 dark:text-gray-400 mb-1">Code: <span class="font-mono">{{ order.code }}</span></p>
        <p class="text-sm text-gray-600 dark:text-gray-400 mb-1">Collector: {{ order.collector_name }}</p>
        <p class="text-sm text-gray-600 dark:text-gray-400 mb-1">Status: 
          <span :class="{
            'text-green-600 dark:text-green-400': order.status === 'OPEN',
            'text-yellow-600 dark:text-yellow-400': order.status === 'LOCKED',
            'text-blue-600 dark:text-blue-400': order.status === 'ORDERED',
            'text-gray-600 dark:text-gray-400': order.status === 'CLOSED',
          }">
            {{ order.status }}
          </span>
        </p>
        <p class="text-sm text-gray-600 dark:text-gray-400 mb-1">Total: {{ order.total_cost.toFixed(2) }} EGP</p>
        <p v-if="getPendingPayment(order.id)" class="text-sm font-semibold text-yellow-600 dark:text-yellow-400 mb-2">
          Pending: {{ formatPrice(getPendingPayment(order.id).amount) }} EGP
        </p>
        <div class="flex flex-col gap-2">
          <router-link
            :to="`/orders/${order.code}`"
            class="block w-full text-center bg-blue-600 dark:bg-blue-500 text-white px-4 py-2 rounded-md hover:bg-blue-700 dark:hover:bg-blue-600"
          >
            View Details
          </router-link>
          <button
            v-if="getPendingPayment(order.id)"
            @click="markAsPaid(getPendingPayment(order.id).payment_id, order.id)"
            :disabled="markingPaid === getPendingPayment(order.id).payment_id"
            class="w-full bg-green-600 dark:bg-green-500 text-white px-4 py-2 rounded-md hover:bg-green-700 dark:hover:bg-green-600 disabled:opacity-50"
          >
            {{ markingPaid === getPendingPayment(order.id).payment_id ? 'Paying...' : 'Pay' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useOrdersStore } from '../stores/orders'
import api from '../api'

const ordersStore = useOrdersStore()
const filterStatus = ref('')
const loading = ref(false)
const pendingPayments = ref([])
const markingPaid = ref(null)

function formatPrice(value) {
  if (value === null || value === undefined) return '0.00'
  const num = typeof value === 'string' ? parseFloat(value) : value
  return isNaN(num) ? '0.00' : num.toFixed(2)
}

function getPendingPayment(orderId) {
  return pendingPayments.value.find(p => p.order_id === orderId)
}

async function fetchPendingPayments() {
  try {
    const response = await api.get('/orders/pending_payments/')
    pendingPayments.value = response.data
  } catch (error) {
    console.error('Failed to fetch pending payments:', error)
  }
}

async function markAsPaid(paymentId, orderId) {
  if (!confirm('Mark this payment as paid?')) return
  
  markingPaid.value = paymentId
  try {
    await api.post(`/payments/${paymentId}/mark_paid/`)
    // Remove from pending payments
    pendingPayments.value = pendingPayments.value.filter(p => p.payment_id !== paymentId)
    alert('Payment marked as paid!')
  } catch (error) {
    alert('Failed to mark payment as paid: ' + (error.response?.data?.error || error.message))
  } finally {
    markingPaid.value = null
  }
}

onMounted(async () => {
  await fetchPendingPayments()
  fetchOrders()
})

async function fetchOrders() {
  loading.value = true
  await ordersStore.fetchOrders(filterStatus.value || null)
  loading.value = false
}
</script>

