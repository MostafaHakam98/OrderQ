<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="mb-8 flex justify-between items-center">
      <h1 class="text-3xl font-bold text-gray-900">Restaurants</h1>
      <div class="flex space-x-2">
        <button
          @click="showTalabatModal = true"
          class="bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700"
        >
          Add from Talabat
        </button>
      <button
        @click="showCreateModal = true"
        class="bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700"
      >
        Add Restaurant
      </button>
      </div>
    </div>

    <div v-if="loading" class="text-center py-8">Loading...</div>
    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <div
        v-for="restaurant in ordersStore.restaurants"
        :key="restaurant.id"
        class="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition border border-gray-100"
      >
        <h3 class="text-xl font-semibold mb-2 text-gray-800">{{ restaurant.name }}</h3>
        <p class="text-gray-600 mb-4">{{ restaurant.description || 'No description' }}</p>
        <div v-if="hasTalabatMenu(restaurant)" class="mb-3">
          <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
            🍽️ Talabat Sync Enabled
          </span>
        </div>
        <div class="flex flex-col space-y-2">
        <div class="flex space-x-2">
          <router-link
            :to="`/restaurants/${restaurant.id}/menus`"
            class="flex-1 text-center bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-colors"
          >
            Manage Menus
          </router-link>
          <button
            @click="editRestaurant(restaurant)"
            class="bg-yellow-600 text-white px-4 py-2 rounded-md hover:bg-yellow-700 focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:ring-offset-2 transition-colors"
          >
            Edit
          </button>
          <button
            @click="deleteRestaurant(restaurant.id)"
            class="bg-red-600 text-white px-4 py-2 rounded-md hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 transition-colors"
          >
            Delete
          </button>
        </div>
          <button
            v-if="hasTalabatMenu(restaurant)"
            @click="syncMenu(restaurant.id)"
            :disabled="syncingMenu === restaurant.id"
            class="w-full bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2 transition-colors"
          >
            {{ syncingMenu === restaurant.id ? 'Syncing...' : '🔄 Sync Menu from Talabat' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Add from Talabat Modal -->
    <div
      v-if="showTalabatModal"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      @click="closeTalabatModal"
    >
      <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4 shadow-xl" @click.stop>
        <h2 class="text-xl font-semibold mb-4 text-gray-800">Add Restaurant from Talabat</h2>
        <form @submit.prevent="saveTalabatRestaurant" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Talabat URL</label>
            <input
              v-model="talabatUrl"
              type="url"
              placeholder="https://www.talabat.com/egypt/restaurant/..."
              required
              class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-green-500 focus:border-green-500"
            />
            <p class="mt-1 text-xs text-gray-500">
              Paste the full Talabat restaurant page URL
            </p>
          </div>
          <div class="flex items-center">
            <input
              v-model="syncNow"
              type="checkbox"
              id="syncNow"
              class="h-4 w-4 text-green-600 focus:ring-green-500 border-gray-300 rounded"
            />
            <label for="syncNow" class="ml-2 block text-sm text-gray-700">
              Sync menu immediately
            </label>
          </div>
          <div v-if="talabatError" class="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded">
            {{ talabatError }}
          </div>
          <div class="flex space-x-2">
            <button
              type="button"
              @click="closeTalabatModal"
              class="flex-1 bg-gray-200 text-gray-700 px-4 py-2 rounded-md hover:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              :disabled="addingTalabat"
              class="flex-1 bg-green-600 text-white px-4 py-2 rounded-md hover:bg-green-700 disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-green-500 focus:ring-offset-2 transition-colors"
            >
              {{ addingTalabat ? 'Adding...' : 'Add Restaurant' }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Create/Edit Restaurant Modal -->
    <div
      v-if="showCreateModal || editingRestaurant"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      @click="closeModal"
    >
      <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4 shadow-xl" @click.stop>
        <h2 class="text-xl font-semibold mb-4 text-gray-800">
          {{ editingRestaurant ? 'Edit Restaurant' : 'Add Restaurant' }}
        </h2>
        <form @submit.prevent="saveRestaurant" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700">Name</label>
            <input
              v-model="newRestaurant.name"
              type="text"
              required
              class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700">Description</label>
            <textarea
              v-model="newRestaurant.description"
              rows="3"
              class="mt-1 block w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            ></textarea>
          </div>
          <div class="flex space-x-2">
            <button
              type="button"
              @click="closeModal"
              class="flex-1 bg-gray-200 text-gray-700 px-4 py-2 rounded-md hover:bg-gray-300 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              :disabled="creating"
              class="flex-1 bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-colors"
            >
              {{ creating ? (editingRestaurant ? 'Updating...' : 'Creating...') : (editingRestaurant ? 'Update' : 'Create') }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useOrdersStore } from '../stores/orders'

const ordersStore = useOrdersStore()
const loading = ref(false)
const showCreateModal = ref(false)
const showTalabatModal = ref(false)
const creating = ref(false)
const addingTalabat = ref(false)
const syncingMenu = ref(null)
const editingRestaurant = ref(null)
const talabatUrl = ref('')
const syncNow = ref(true)
const talabatError = ref('')
const newRestaurant = ref({
  name: '',
  description: '',
})

onMounted(async () => {
  loading.value = true
  await ordersStore.fetchRestaurants()
  loading.value = false
})

function editRestaurant(restaurant) {
  editingRestaurant.value = restaurant
  newRestaurant.value = {
    name: restaurant.name,
    description: restaurant.description || '',
  }
}

function closeModal() {
  showCreateModal.value = false
  editingRestaurant.value = null
  newRestaurant.value = { name: '', description: '' }
}

function closeTalabatModal() {
  showTalabatModal.value = false
  talabatUrl.value = ''
  syncNow.value = true
  talabatError.value = ''
}

function hasTalabatMenu(restaurant) {
  // Check if restaurant has a menu with talabat_url
  // We'll need to fetch menus or check in the restaurant data
  // For now, we'll check if menus exist and have talabat_url
  return restaurant.menus?.some(menu => menu.talabat_url) || false
}

async function saveTalabatRestaurant() {
  if (!talabatUrl.value.trim()) {
    talabatError.value = 'Please enter a Talabat URL'
    return
  }
  
  if (!talabatUrl.value.startsWith('https://www.talabat.com/')) {
    talabatError.value = 'Invalid Talabat URL. Must start with https://www.talabat.com/'
    return
  }
  
  addingTalabat.value = true
  talabatError.value = ''
  
  const result = await ordersStore.addRestaurantFromTalabat(talabatUrl.value, syncNow.value)
  
  if (result.success) {
    closeTalabatModal()
    if (result.data.warning) {
      alert('Restaurant added but menu sync had issues: ' + result.data.warning)
    } else {
      alert(result.data.message || 'Restaurant added successfully!')
    }
  } else {
    talabatError.value = result.error?.error || result.error?.detail || 'Failed to add restaurant from Talabat'
  }
  
  addingTalabat.value = false
}

async function syncMenu(restaurantId) {
  syncingMenu.value = restaurantId
  const result = await ordersStore.syncRestaurantMenu(restaurantId)
  
  if (result.success) {
    alert(`Menu synced successfully! ${result.data.items_count || 0} items found.`)
  } else {
    alert('Failed to sync menu: ' + (result.error?.error || result.error?.detail || 'Unknown error'))
  }
  
  syncingMenu.value = null
}

async function saveRestaurant() {
  creating.value = true
  
  if (editingRestaurant.value) {
    const result = await ordersStore.updateRestaurant(editingRestaurant.value.id, newRestaurant.value)
    if (result.success) {
      closeModal()
    } else {
      alert('Failed to update restaurant: ' + (result.error?.detail || JSON.stringify(result.error)))
    }
  } else {
    const result = await ordersStore.createRestaurant(newRestaurant.value)
    if (result.success) {
      closeModal()
    } else {
      alert('Failed to create restaurant: ' + (result.error?.detail || JSON.stringify(result.error)))
    }
  }
  
  creating.value = false
}

async function deleteRestaurant(restaurantId) {
  if (!confirm('Are you sure you want to delete this restaurant? This will also delete all associated menus and menu items. This action cannot be undone.')) {
    return
  }
  
  const result = await ordersStore.deleteRestaurant(restaurantId)
  if (!result.success) {
    alert('Failed to delete restaurant: ' + (result.error?.detail || JSON.stringify(result.error)))
  }
}
</script>

