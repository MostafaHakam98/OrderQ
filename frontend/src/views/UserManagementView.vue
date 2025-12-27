<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="mb-6">
      <h1 class="text-3xl font-bold text-gray-900 dark:text-white">User Management</h1>
      <p class="text-gray-600 dark:text-gray-400 mt-2">Manage user roles and permissions. Administrators can grant manager or admin permissions to users.</p>
    </div>

    <div v-if="loading" class="text-center py-8">
      <p class="text-lg text-gray-600 dark:text-gray-400">Loading users...</p>
    </div>
    <div v-else-if="error" class="bg-red-50 dark:bg-red-900/30 border border-red-200 dark:border-red-800 rounded-lg p-4 mb-6">
      <p class="text-red-800 dark:text-red-200">{{ error }}</p>
    </div>
    <div v-else class="bg-white dark:bg-gray-800 rounded-lg shadow overflow-hidden">
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
          <thead class="bg-gray-50 dark:bg-gray-700">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                Username
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                Email
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                Name
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                Role
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                Phone
              </th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-300 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
            <tr v-for="user in users" :key="user.id" class="hover:bg-gray-50 dark:hover:bg-gray-700">
              <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-white">
                {{ user.username }}
                <span v-if="user.id === authStore.user?.id" class="ml-2 text-xs text-blue-600 dark:text-blue-400">(You)</span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                {{ user.email || 'N/A' }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                {{ user.first_name || user.last_name ? `${user.first_name || ''} ${user.last_name || ''}`.trim() : 'N/A' }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <select
                  v-model="user.role"
                  @change="updateUserRole(user)"
                  :disabled="user.id === authStore.user?.id || updatingUsers.has(user.id)"
                  class="text-sm border border-gray-300 dark:border-gray-600 rounded-md px-2 py-1 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <option value="user">Normal User</option>
                  <option value="manager">Menu Manager</option>
                  <option value="admin">Administrator</option>
                </select>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
                {{ user.phone || 'N/A' }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm">
                <button
                  v-if="user.id !== authStore.user?.id"
                  @click="editUser(user)"
                  class="text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 font-medium"
                >
                  Edit
                </button>
                <span v-else class="text-gray-400 dark:text-gray-500 text-xs">Edit in Profile</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Edit User Modal -->
    <div v-if="editingUser" class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" @click.self="closeEditModal">
      <div class="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white dark:bg-gray-800">
        <div class="mt-3">
          <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-4">Edit User: {{ editingUser.username }}</h3>
          <form @submit.prevent="saveUser" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Email</label>
              <input
                v-model="editForm.email"
                type="email"
                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
              />
            </div>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">First Name</label>
                <input
                  v-model="editForm.first_name"
                  type="text"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Last Name</label>
                <input
                  v-model="editForm.last_name"
                  type="text"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
                />
              </div>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Phone</label>
              <input
                v-model="editForm.phone"
                type="tel"
                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Role</label>
              <select
                v-model="editForm.role"
                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
              >
                <option value="user">Normal User</option>
                <option value="manager">Menu Manager</option>
                <option value="admin">Administrator</option>
              </select>
            </div>
            <div v-if="editError" class="text-red-600 dark:text-red-400 text-sm">{{ editError }}</div>
            <div class="flex justify-end space-x-3 pt-4">
              <button
                type="button"
                @click="closeEditModal"
                class="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 transition-colors"
              >
                Cancel
              </button>
              <button
                type="submit"
                :disabled="saving"
                class="px-4 py-2 bg-blue-600 dark:bg-blue-500 text-white rounded-md hover:bg-blue-700 dark:hover:bg-blue-600 disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-colors"
              >
                {{ saving ? 'Saving...' : 'Save' }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useOrdersStore } from '../stores/orders'
import api from '../api'

const authStore = useAuthStore()
const ordersStore = useOrdersStore()

const users = ref([])
const loading = ref(true)
const error = ref('')
const editingUser = ref(null)
const editForm = ref({
  email: '',
  first_name: '',
  last_name: '',
  phone: '',
  role: 'user',
})
const saving = ref(false)
const editError = ref('')
const updatingUsers = ref(new Set())

onMounted(async () => {
  await fetchUsers()
})

async function fetchUsers() {
  loading.value = true
  error.value = ''
  try {
    const result = await ordersStore.fetchUsers()
    if (result.success) {
      users.value = result.data
    } else {
      error.value = 'Failed to load users'
    }
  } catch (err) {
    error.value = 'Failed to load users: ' + (err.response?.data?.error || err.message)
  } finally {
    loading.value = false
  }
}

async function updateUserRole(user) {
  if (user.id === authStore.user?.id) {
    alert('You cannot change your own role')
    user.role = authStore.user.role // Revert the change
    return
  }

  updatingUsers.value.add(user.id)
  try {
    await api.patch(`/users/${user.id}/`, { role: user.role })
    alert('User role updated successfully!')
    // Refresh users to get updated data
    await fetchUsers()
  } catch (err) {
    alert('Failed to update user role: ' + (err.response?.data?.error || err.message))
    // Revert the change on error
    await fetchUsers()
  } finally {
    updatingUsers.value.delete(user.id)
  }
}

function editUser(user) {
  editingUser.value = user
  editForm.value = {
    email: user.email || '',
    first_name: user.first_name || '',
    last_name: user.last_name || '',
    phone: user.phone || '',
    role: user.role || 'user',
  }
  editError.value = ''
}

function closeEditModal() {
  editingUser.value = null
  editForm.value = {
    email: '',
    first_name: '',
    last_name: '',
    phone: '',
    role: 'user',
  }
  editError.value = ''
}

async function saveUser() {
  if (!editingUser.value) return

  saving.value = true
  editError.value = ''
  
  try {
    await api.patch(`/users/${editingUser.value.id}/`, editForm.value)
    alert('User updated successfully!')
    await fetchUsers()
    closeEditModal()
  } catch (err) {
    editError.value = err.response?.data?.error || err.response?.data?.detail || 'Failed to update user'
  } finally {
    saving.value = false
  }
}
</script>

