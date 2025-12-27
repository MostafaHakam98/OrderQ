<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <h1 class="text-3xl font-bold text-gray-900 dark:text-white mb-8">Monthly Reports</h1>

    <div v-if="authStore.isManager" class="mb-6">
      <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Select User</label>
      <select
        v-model="selectedUserId"
        @change="fetchReport"
        class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
      >
        <option :value="authStore.user?.id">Me</option>
        <option v-for="user in users" :key="user.id" :value="user.id">
          {{ user.username }}
        </option>
      </select>
    </div>

    <div v-if="loading" class="text-center py-8 text-gray-600 dark:text-gray-400">Loading...</div>
    <div v-else-if="report" class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
      <h2 class="text-xl font-semibold mb-6 dark:text-white">
        Report for {{ report.user.username }} - {{ report.month }}
      </h2>
      
      <!-- Main Metrics Row -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
        <div class="bg-blue-50 dark:bg-blue-900/30 rounded-lg p-4">
          <p class="text-sm text-gray-600 dark:text-gray-400">Total Spend</p>
          <p class="text-2xl font-bold text-blue-600 dark:text-blue-400">{{ report.total_spend.toFixed(2) }} EGP</p>
        </div>
        <div class="bg-green-50 dark:bg-green-900/30 rounded-lg p-4">
          <p class="text-sm text-gray-600 dark:text-gray-400">Times as Collector</p>
          <p class="text-2xl font-bold text-green-600 dark:text-green-400">{{ report.collector_count }}</p>
        </div>
        <div class="bg-red-50 dark:bg-red-900/30 rounded-lg p-4">
          <p class="text-sm text-gray-600 dark:text-gray-400">Unpaid Incidents</p>
          <p class="text-2xl font-bold text-red-600 dark:text-red-400">{{ report.unpaid_count }}</p>
        </div>
      </div>

      <!-- Secondary Metrics Row -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
        <div class="bg-purple-50 dark:bg-purple-900/30 rounded-lg p-4">
          <p class="text-sm text-gray-600 dark:text-gray-400">Total Collected</p>
          <p class="text-2xl font-bold text-purple-600 dark:text-purple-400">{{ report.total_collected.toFixed(2) }} EGP</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">When you were collector</p>
        </div>
        <div class="bg-indigo-50 dark:bg-indigo-900/30 rounded-lg p-4">
          <p class="text-sm text-gray-600 dark:text-gray-400">Orders Participated</p>
          <p class="text-2xl font-bold text-indigo-600 dark:text-indigo-400">{{ report.total_orders_participated }}</p>
        </div>
        <div class="bg-teal-50 dark:bg-teal-900/30 rounded-lg p-4">
          <p class="text-sm text-gray-600 dark:text-gray-400">Avg Order Value</p>
          <p class="text-2xl font-bold text-teal-600 dark:text-teal-400">{{ report.avg_order_value.toFixed(2) }} EGP</p>
        </div>
      </div>

      <!-- Third Metrics Row -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
        <div class="bg-orange-50 dark:bg-orange-900/30 rounded-lg p-4">
          <p class="text-sm text-gray-600 dark:text-gray-400">Total Fees Paid</p>
          <p class="text-2xl font-bold text-orange-600 dark:text-orange-400">{{ report.total_fees_paid.toFixed(2) }} EGP</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Delivery, tip, service fees</p>
        </div>
        <div class="bg-cyan-50 dark:bg-cyan-900/30 rounded-lg p-4">
          <p class="text-sm text-gray-600 dark:text-gray-400">Payment Completion</p>
          <p class="text-2xl font-bold text-cyan-600 dark:text-cyan-400">{{ report.payment_completion_rate.toFixed(1) }}%</p>
        </div>
        <div class="bg-pink-50 dark:bg-pink-900/30 rounded-lg p-4">
          <p class="text-sm text-gray-600 dark:text-gray-400">Total Pending</p>
          <p class="text-2xl font-bold text-pink-600 dark:text-pink-400">{{ report.total_pending.toFixed(2) }} EGP</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Amount you owe</p>
        </div>
      </div>

      <!-- Fourth Metrics Row -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="bg-yellow-50 dark:bg-yellow-900/30 rounded-lg p-4">
          <p class="text-sm text-gray-600 dark:text-gray-400">Total Owed to You</p>
          <p class="text-2xl font-bold text-yellow-600 dark:text-yellow-400">{{ report.total_owed_to_user.toFixed(2) }} EGP</p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">When you were collector</p>
        </div>
        <div class="bg-emerald-50 dark:bg-emerald-900/30 rounded-lg p-4">
          <p class="text-sm text-gray-600 dark:text-gray-400">Most Ordered Restaurant</p>
          <p class="text-xl font-bold text-emerald-600 dark:text-emerald-400">
            {{ report.most_ordered_restaurant || 'N/A' }}
          </p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
            {{ report.most_ordered_restaurant_count }} order{{ report.most_ordered_restaurant_count !== 1 ? 's' : '' }}
          </p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { useOrdersStore } from '../stores/orders'
import { useAuthStore } from '../stores/auth'
import api from '../api'

const ordersStore = useOrdersStore()
const authStore = useAuthStore()
const loading = ref(false)
const report = ref(null)
const selectedUserId = ref(authStore.user?.id)
const users = ref([])

onMounted(async () => {
  if (authStore.isManager) {
    // Fetch all users for manager
    try {
      const response = await api.get('/users/')
      users.value = response.data.results || response.data
    } catch (error) {
      console.error('Failed to fetch users:', error)
    }
  }
  await fetchReport()
})

async function fetchReport() {
  if (!selectedUserId.value) return
  
  loading.value = true
  const result = await ordersStore.getMonthlyReport(selectedUserId.value)
  
  if (result.success) {
    report.value = result.data
  }
  loading.value = false
}
</script>

