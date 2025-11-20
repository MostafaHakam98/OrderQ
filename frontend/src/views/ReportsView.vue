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
      <h2 class="text-xl font-semibold mb-4 dark:text-white">
        Report for {{ report.user.username }} - {{ report.month }}
      </h2>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
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

