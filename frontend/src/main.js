import { createApp } from 'vue'
import { createPinia } from 'pinia'
import './style.css'
import App from './App.vue'
import router from './router'
import { useThemeStore } from './stores/theme'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)
app.use(router)

// Initialize theme store - this will automatically apply the theme
// The store calls applyTheme() when created, but we also ensure it's applied after mount
const themeStore = useThemeStore()

app.mount('#app')

// Ensure theme is applied after DOM is ready (redundant but safe)
themeStore.applyTheme()
