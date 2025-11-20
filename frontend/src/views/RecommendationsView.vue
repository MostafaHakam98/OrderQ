<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div class="mb-6">
      <h1 class="text-3xl font-bold text-gray-900 dark:text-white">Website Recommendations</h1>
      <p class="text-gray-600 dark:text-gray-400 mt-2">Share your ideas for improvements, new features, or report issues</p>
    </div>

    <!-- Add Recommendation Form -->
    <div class="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 mb-6 border border-gray-100 dark:border-gray-700">
      <h2 class="text-xl font-semibold mb-4 text-gray-800 dark:text-white">Submit a Recommendation</h2>
      <form @submit.prevent="addRecommendation" class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Category</label>
          <select
            v-model="newRecommendation.category"
            required
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
          >
            <option value="feature">New Feature</option>
            <option value="improvement">Improvement</option>
            <option value="bug">Bug Report</option>
            <option value="ui">UI/UX</option>
            <option value="other">Other</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Title</label>
          <input
            v-model="newRecommendation.title"
            type="text"
            required
            placeholder="Brief title for your recommendation..."
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
          />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Details</label>
          <textarea
            v-model="newRecommendation.text"
            required
            rows="6"
            placeholder="Describe your recommendation, suggestion, or feedback in detail..."
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
          ></textarea>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">Be as specific as possible. Include examples or use cases if applicable.</p>
        </div>
        <button
          type="submit"
          :disabled="submitting"
          class="bg-blue-600 dark:bg-blue-500 text-white px-4 py-2 rounded-md hover:bg-blue-700 dark:hover:bg-blue-600 disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-colors"
        >
          {{ submitting ? 'Submitting...' : 'Submit Recommendation' }}
        </button>
      </form>
    </div>

    <!-- Recommendations List -->
    <div v-if="loading" class="text-center py-8">
      <p class="text-lg text-gray-600 dark:text-gray-400">Loading recommendations...</p>
    </div>
    <div v-else-if="recommendations.length === 0" class="text-center py-8 text-gray-500 dark:text-gray-400">
      <p class="text-lg">No recommendations yet</p>
      <p class="text-sm mt-2">Be the first to share your ideas!</p>
    </div>
    <div v-else class="space-y-4">
      <div
        v-for="rec in recommendations"
        :key="rec.id"
        class="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-100 dark:border-gray-700 hover:shadow-lg transition-shadow"
      >
        <div class="flex justify-between items-start mb-3">
          <div class="flex-1">
            <div class="flex items-center gap-3 mb-2">
              <h3 class="font-semibold text-lg text-gray-900 dark:text-white">{{ rec.title }}</h3>
              <span 
                class="px-2 py-1 text-xs font-medium rounded-full"
                :class="{
                  'bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300': rec.category === 'feature',
                  'bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300': rec.category === 'improvement',
                  'bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300': rec.category === 'bug',
                  'bg-purple-100 dark:bg-purple-900/30 text-purple-800 dark:text-purple-300': rec.category === 'ui',
                  'bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-300': rec.category === 'other',
                }"
              >
                {{ rec.category_display }}
              </span>
            </div>
            <p class="text-sm text-gray-600 dark:text-gray-400">by {{ rec.user_name }}</p>
          </div>
          <p class="text-sm text-gray-500 dark:text-gray-400 whitespace-nowrap ml-4">{{ formatDate(rec.created_at) }}</p>
        </div>
        <p class="text-gray-700 dark:text-gray-300 whitespace-pre-wrap leading-relaxed">{{ rec.text }}</p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import api from '../api'

const loading = ref(true)
const submitting = ref(false)
const recommendations = ref([])

const newRecommendation = ref({
  category: 'other',
  title: '',
  text: '',
})

function formatDate(dateString) {
  const date = new Date(dateString)
  return date.toLocaleDateString('en-US', { 
    year: 'numeric', 
    month: 'short', 
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  })
}

async function fetchRecommendations() {
  loading.value = true
  try {
    const response = await api.get('/recommendations/')
    recommendations.value = response.data.results || response.data
  } catch (error) {
    console.error('Failed to fetch recommendations:', error)
    alert('Failed to load recommendations: ' + (error.response?.data?.error || error.message))
  } finally {
    loading.value = false
  }
}

async function addRecommendation() {
  if (!newRecommendation.value.title.trim() || !newRecommendation.value.text.trim()) {
    alert('Please fill in both title and details')
    return
  }
  
  submitting.value = true
  try {
    await api.post('/recommendations/', {
      category: newRecommendation.value.category,
      title: newRecommendation.value.title,
      text: newRecommendation.value.text,
    })
    newRecommendation.value = { category: 'other', title: '', text: '' }
    await fetchRecommendations()
    alert('Recommendation submitted successfully! Thank you for your feedback.')
  } catch (error) {
    alert('Failed to submit recommendation: ' + (error.response?.data?.error || error.message))
  } finally {
    submitting.value = false
  }
}

onMounted(() => {
  fetchRecommendations()
})
</script>
