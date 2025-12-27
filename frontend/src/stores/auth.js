import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import api from '../api'
import router from '../router'

export const useAuthStore = defineStore('auth', () => {
  const user = ref(null)
  const token = ref(localStorage.getItem('access_token') || null)
  const refreshToken = ref(localStorage.getItem('refresh_token') || null)

  const isAuthenticated = computed(() => !!token.value)
  const isManager = computed(() => user.value?.role === 'manager')
  const isAdmin = computed(() => user.value?.role === 'admin')

  async function login(usernameOrEmail, password) {
    try {
      // Determine if input is email or username
      const isEmail = usernameOrEmail.includes('@')
      const loginData = isEmail 
        ? { email: usernameOrEmail, password }
        : { username: usernameOrEmail, password }
      
      const response = await api.post('/auth/login/', loginData)
      const { access, refresh } = response.data
      
      token.value = access
      refreshToken.value = refresh
      localStorage.setItem('access_token', access)
      localStorage.setItem('refresh_token', refresh)
      
      await fetchUser()
      return { success: true }
    } catch (error) {
      return { 
        success: false, 
        error: error.response?.data?.detail || error.response?.data?.non_field_errors?.[0] || 'Login failed' 
      }
    }
  }

  async function register(userData) {
    try {
      await api.post('/auth/register/', userData)
      return { success: true }
    } catch (error) {
      return { 
        success: false, 
        error: error.response?.data || 'Registration failed' 
      }
    }
  }

  async function fetchUser() {
    try {
      const response = await api.get('/users/me/')
      user.value = response.data
    } catch (error) {
      console.error('Failed to fetch user:', error)
    }
  }

  async function updateProfile(profileData) {
    try {
      const response = await api.patch(`/users/${user.value.id}/`, profileData, {
        headers: profileData instanceof FormData ? {
          'Content-Type': 'multipart/form-data',
        } : {}
      })
      user.value = response.data
      return { success: true, data: response.data }
    } catch (error) {
      return {
        success: false,
        error: error.response?.data || 'Failed to update profile'
      }
    }
  }

  async function changePassword(oldPassword, newPassword, newPasswordConfirm) {
    try {
      const response = await api.post('/users/change_password/', {
        old_password: oldPassword,
        new_password: newPassword,
        new_password_confirm: newPasswordConfirm
      })
      return { success: true, data: response.data }
    } catch (error) {
      return {
        success: false,
        error: error.response?.data || 'Failed to change password'
      }
    }
  }

  async function logout() {
    user.value = null
    token.value = null
    refreshToken.value = null
    localStorage.removeItem('access_token')
    localStorage.removeItem('refresh_token')
    router.push('/login')
  }

  // Initialize user if token exists
  if (token.value) {
    fetchUser()
  }

  return {
    user,
    token,
    isAuthenticated,
    isManager,
    isAdmin,
    login,
    register,
    logout,
    fetchUser,
    updateProfile,
    changePassword,
  }
})

