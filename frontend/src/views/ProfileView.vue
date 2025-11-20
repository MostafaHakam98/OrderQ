<template>
  <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="mb-6">
      <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Profile Settings</h1>
      <p class="text-gray-600 dark:text-gray-400 mt-2">Manage your account and Instapay link</p>
    </div>

    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 mb-6 border border-gray-100 dark:border-gray-700">
      <h2 class="text-xl font-semibold mb-4 text-gray-800 dark:text-white">Personal Information</h2>
      <form @submit.prevent="saveProfile" class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Username</label>
          <input
            v-model="profile.username"
            type="text"
            disabled
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-gray-50 dark:bg-gray-700 dark:text-gray-400 focus:outline-none"
          />
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Username cannot be changed</p>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Email</label>
          <input
            v-model="profile.email"
            type="email"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
          />
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">First Name</label>
            <input
              v-model="profile.first_name"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Last Name</label>
            <input
              v-model="profile.last_name"
              type="text"
              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
            />
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Phone</label>
          <input
            v-model="profile.phone"
            type="tel"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
          />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Instapay Link</label>
          <input
            v-model="profile.instapay_link"
            type="url"
            placeholder="https://instapay.me/your-link"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
          />
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Your Instapay payment link. This will be shown in orders you collect.</p>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Instapay QR Code Image</label>
          <input
            type="file"
            accept="image/*"
            @change="handleFileUpload"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100 dark:file:bg-gray-600 dark:file:text-gray-200"
          />
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Upload a QR code image for Instapay. This will be shown in orders you collect.</p>
          <div v-if="profile.instapay_qr_code_url" class="mt-2">
            <p class="text-xs text-gray-600 dark:text-gray-400 mb-1">Current QR Code:</p>
            <img :src="profile.instapay_qr_code_url" alt="QR Code" class="max-w-xs border border-gray-300 dark:border-gray-600 rounded" />
          </div>
        </div>

        <div class="flex justify-end space-x-3 pt-4">
          <button
            type="button"
            @click="router.push('/')"
            class="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 transition-colors"
          >
            Cancel
          </button>
          <button
            type="button"
            @click="showChangePassword = !showChangePassword"
            class="px-4 py-2 border border-blue-600 dark:border-blue-500 text-blue-600 dark:text-blue-400 rounded-md hover:bg-blue-50 dark:hover:bg-blue-900/30 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-colors"
          >
            Change Password
          </button>
          <button
            type="submit"
            :disabled="saving"
            class="px-4 py-2 bg-blue-600 dark:bg-blue-500 text-white rounded-md hover:bg-blue-700 dark:hover:bg-blue-600 disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-colors"
          >
            {{ saving ? 'Saving...' : 'Save Changes' }}
          </button>
        </div>
      </form>
    </div>

    <!-- Change Password Section -->
    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-100 dark:border-gray-700">
      <h2 class="text-xl font-semibold mb-4 text-gray-800 dark:text-white">Change Password</h2>
      <form @submit.prevent="handleChangePassword" class="space-y-4" v-if="showChangePassword">
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Current Password</label>
          <input
            v-model="passwordForm.old_password"
            type="password"
            required
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">New Password</label>
          <input
            v-model="passwordForm.new_password"
            type="password"
            required
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Confirm New Password</label>
          <input
            v-model="passwordForm.new_password_confirm"
            type="password"
            required
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
          />
        </div>
        <div v-if="passwordError" class="text-red-600 dark:text-red-400 text-sm">{{ passwordError }}</div>
        <div class="flex justify-end space-x-3">
          <button
            type="button"
            @click="cancelChangePassword"
            class="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 transition-colors"
          >
            Cancel
          </button>
          <button
            type="submit"
            :disabled="changingPassword"
            class="px-4 py-2 bg-blue-600 dark:bg-blue-500 text-white rounded-md hover:bg-blue-700 dark:hover:bg-blue-600 disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-colors"
          >
            {{ changingPassword ? 'Changing...' : 'Change Password' }}
          </button>
        </div>
      </form>
      <div v-else class="text-gray-500 dark:text-gray-400 text-sm">
        Click "Change Password" above to change your password.
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useAuthStore } from '../stores/auth'
import { useRouter } from 'vue-router'
import api from '../api'

const authStore = useAuthStore()
const router = useRouter()

const profile = ref({
  username: '',
  email: '',
  first_name: '',
  last_name: '',
  phone: '',
  instapay_link: '',
  instapay_qr_code_url: null,
})

const passwordForm = ref({
  old_password: '',
  new_password: '',
  new_password_confirm: '',
})

const saving = ref(false)
const changingPassword = ref(false)
const showChangePassword = ref(false)
const passwordError = ref('')
const qrCodeFile = ref(null)

onMounted(() => {
  if (authStore.user) {
    profile.value = {
      username: authStore.user.username || '',
      email: authStore.user.email || '',
      first_name: authStore.user.first_name || '',
      last_name: authStore.user.last_name || '',
      phone: authStore.user.phone || '',
      instapay_link: authStore.user.instapay_link || '',
      instapay_qr_code_url: authStore.user.instapay_qr_code_url || null,
    }
  }
})

function handleFileUpload(event) {
  const file = event.target.files[0]
  if (file) {
    qrCodeFile.value = file
  }
}

async function saveProfile() {
  saving.value = true
  try {
    const formData = new FormData()
    formData.append('email', profile.value.email)
    formData.append('first_name', profile.value.first_name)
    formData.append('last_name', profile.value.last_name)
    formData.append('phone', profile.value.phone)
    formData.append('instapay_link', profile.value.instapay_link)
    
    if (qrCodeFile.value) {
      formData.append('instapay_qr_code', qrCodeFile.value)
    }
    
    const response = await api.patch(`/users/${authStore.user.id}/`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    })
    
    authStore.user = response.data
    profile.value.instapay_qr_code_url = response.data.instapay_qr_code_url
    
    alert('Profile updated successfully!')
    router.push('/')
  } catch (error) {
    alert('Failed to update profile: ' + (error.response?.data?.detail || JSON.stringify(error.response?.data)))
  } finally {
    saving.value = false
  }
}

function cancelChangePassword() {
  showChangePassword.value = false
  passwordForm.value = {
    old_password: '',
    new_password: '',
    new_password_confirm: '',
  }
  passwordError.value = ''
}

async function handleChangePassword() {
  changingPassword.value = true
  passwordError.value = ''
  
  if (passwordForm.value.new_password !== passwordForm.value.new_password_confirm) {
    passwordError.value = 'New passwords do not match'
    changingPassword.value = false
    return
  }
  
  const result = await authStore.changePassword(
    passwordForm.value.old_password,
    passwordForm.value.new_password,
    passwordForm.value.new_password_confirm
  )
  
  if (result.success) {
    alert('Password changed successfully!')
    cancelChangePassword()
  } else {
    passwordError.value = result.error?.detail || result.error?.old_password?.[0] || result.error?.new_password?.[0] || 'Failed to change password'
  }
  
  changingPassword.value = false
}
</script>
