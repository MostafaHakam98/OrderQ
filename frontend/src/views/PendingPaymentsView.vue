<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="mb-6">
      <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Pending Payments</h1>
      <p class="text-gray-600 dark:text-gray-400 mt-2">Manage payments you owe and payments owed to you</p>
    </div>

    <div v-if="loading" class="text-center py-8">
      <p class="text-lg text-gray-600 dark:text-gray-400">Loading pending payments...</p>
    </div>
    <div v-else>
      <!-- Payments I Owe Section -->
      <div class="mb-8">
        <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">
          Payments I Owe
          <span class="text-sm font-normal text-gray-500 dark:text-gray-400 ml-2">
            ({{ paymentsIOwe.length }})
          </span>
        </h2>
        <div v-if="paymentsIOwe.length === 0" class="text-center py-8 text-gray-500 dark:text-gray-400 bg-white dark:bg-gray-800 rounded-lg">
          <p class="text-lg">No pending payments</p>
          <p class="text-sm mt-2">You're all caught up! 🎉</p>
        </div>
        <div v-else class="space-y-4">
          <div
            v-for="payment in paymentsIOwe"
            :key="`owe-${payment.payment_id}`"
            class="bg-white dark:bg-gray-800 rounded-lg shadow p-6 border-l-4 border-yellow-500 dark:border-yellow-400"
          >
            <div class="flex justify-between items-start">
              <div class="flex-1">
                <h3 class="text-lg font-semibold dark:text-white">{{ payment.restaurant_name }}</h3>
                <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">Order Code: <span class="font-mono">{{ payment.order_code }}</span></p>
                <p class="text-sm text-gray-600 dark:text-gray-400">Collector: {{ payment.collector_name }}</p>
                <p class="text-sm text-gray-600 dark:text-gray-400">Status: 
                  <span :class="{
                    'text-yellow-600 dark:text-yellow-400': payment.order_status === 'LOCKED',
                    'text-blue-600 dark:text-blue-400': payment.order_status === 'ORDERED',
                    'text-gray-600 dark:text-gray-400': payment.order_status === 'CLOSED',
                  }">
                    {{ payment.order_status }}
                  </span>
                </p>
                <p class="text-xl font-bold text-gray-900 dark:text-white mt-2">{{ formatPrice(payment.amount) }} EGP</p>
              </div>
              <div class="flex flex-col space-y-2 ml-4">
                <router-link
                  :to="`/orders/${payment.order_code}`"
                  class="bg-blue-600 dark:bg-blue-500 text-white px-4 py-2 rounded-md hover:bg-blue-700 dark:hover:bg-blue-600 text-sm text-center"
                >
                  View Order
                </router-link>
                <button
                  @click="markAsPaid(payment.payment_id)"
                  :disabled="markingPaid === payment.payment_id"
                  class="bg-green-600 dark:bg-green-500 text-white px-4 py-2 rounded-md hover:bg-green-700 dark:hover:bg-green-600 disabled:opacity-50 text-sm"
                >
                  {{ markingPaid === payment.payment_id ? 'Marking...' : 'Mark as Paid' }}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Payments Owed to Me Section -->
      <div>
        <h2 class="text-xl font-semibold text-gray-900 dark:text-white mb-4">
          Payments Owed to Me
          <span class="text-sm font-normal text-gray-500 dark:text-gray-400 ml-2">
            ({{ paymentsOwedToMe.length }})
          </span>
        </h2>
        <div v-if="paymentsOwedToMe.length === 0" class="text-center py-8 text-gray-500 dark:text-gray-400 bg-white dark:bg-gray-800 rounded-lg">
          <p class="text-lg">No payments owed to you</p>
          <p class="text-sm mt-2">All payments are up to date</p>
        </div>
        <div v-else class="space-y-4">
          <div
            v-for="payment in paymentsOwedToMe"
            :key="`to-me-${payment.payment_id}`"
            class="bg-white dark:bg-gray-800 rounded-lg shadow p-6 border-l-4 border-green-500 dark:border-green-400"
          >
            <div class="flex justify-between items-start">
              <div class="flex-1">
                <h3 class="text-lg font-semibold dark:text-white">{{ payment.restaurant_name }}</h3>
                <p class="text-sm text-gray-600 dark:text-gray-400 mt-1">Order Code: <span class="font-mono">{{ payment.order_code }}</span></p>
                <p class="text-sm text-gray-600 dark:text-gray-400">Payer: {{ payment.payer_name }}</p>
                <p class="text-sm text-gray-600 dark:text-gray-400">Status: 
                  <span :class="{
                    'text-yellow-600 dark:text-yellow-400': payment.order_status === 'LOCKED',
                    'text-blue-600 dark:text-blue-400': payment.order_status === 'ORDERED',
                    'text-gray-600 dark:text-gray-400': payment.order_status === 'CLOSED',
                  }">
                    {{ payment.order_status }}
                  </span>
                </p>
                <p class="text-xl font-bold text-green-600 dark:text-green-400 mt-2">{{ formatPrice(payment.amount) }} EGP</p>
              </div>
              <div class="flex flex-col space-y-2 ml-4">
                <router-link
                  :to="`/orders/${payment.order_code}`"
                  class="bg-blue-600 dark:bg-blue-500 text-white px-4 py-2 rounded-md hover:bg-blue-700 dark:hover:bg-blue-600 text-sm text-center"
                >
                  View Order
                </router-link>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import api from '../api'

const loading = ref(true)
const pendingPayments = ref([])
const paymentsOwedToMe = ref([])
const markingPaid = ref(null)

const paymentsIOwe = computed(() => {
  return pendingPayments.value.filter(p => p.payment_type === 'owed_by_me' || !p.payment_type)
})

function formatPrice(value) {
  if (value === null || value === undefined) return '0.00'
  const num = typeof value === 'string' ? parseFloat(value) : value
  return isNaN(num) ? '0.00' : num.toFixed(2)
}

async function fetchPendingPayments() {
  loading.value = true
  try {
    // Fetch payments I owe
    const response1 = await api.get('/orders/pending_payments/')
    pendingPayments.value = response1.data
    
    // Fetch payments owed to me
    const response2 = await api.get('/orders/pending_payments_to_me/')
    paymentsOwedToMe.value = response2.data
  } catch (error) {
    console.error('Failed to fetch pending payments:', error)
    alert('Failed to load pending payments: ' + (error.response?.data?.error || error.message))
  } finally {
    loading.value = false
  }
}

async function markAsPaid(paymentId) {
  if (!confirm('Mark this payment as paid?')) return
  
  markingPaid.value = paymentId
  try {
    await api.post(`/payments/${paymentId}/mark_paid/`)
    await fetchPendingPayments()
    alert('Payment marked as paid!')
  } catch (error) {
    alert('Failed to mark payment as paid: ' + (error.response?.data?.error || error.message))
  } finally {
    markingPaid.value = null
  }
}

onMounted(() => {
  fetchPendingPayments()
})
</script>

