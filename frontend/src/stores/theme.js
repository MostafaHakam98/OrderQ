import { defineStore } from 'pinia'
import { ref, watch } from 'vue'

export const useThemeStore = defineStore('theme', () => {
  const isDark = ref(localStorage.getItem('theme') === 'dark' || false)

  // Apply theme to document
  function applyTheme() {
    if (isDark.value) {
      document.documentElement.classList.add('dark')
      localStorage.setItem('theme', 'dark')
    } else {
      document.documentElement.classList.remove('dark')
      localStorage.setItem('theme', 'light')
    }
  }

  // Toggle theme
  function toggleTheme() {
    isDark.value = !isDark.value
    applyTheme()
  }

  // Initialize theme on store creation
  applyTheme()

  // Watch for changes and apply
  watch(isDark, () => {
    applyTheme()
  })

  return {
    isDark,
    toggleTheme,
    applyTheme
  }
})

