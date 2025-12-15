import { defineStore } from 'pinia'
import { ref } from 'vue'
import api from '../api'

export const useOrdersStore = defineStore('orders', () => {
  const orders = ref([])
  const currentOrder = ref(null)
  const restaurants = ref([])
  const menus = ref([])
  const menuItems = ref([])
  const feePresets = ref([])

  async function fetchOrders(status = null) {
    try {
      const params = status ? { status } : {}
      const response = await api.get('/orders/', { params })
      orders.value = response.data.results || response.data
      return { success: true }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function fetchOrderByCode(code) {
    try {
      console.log('Fetching order by code:', code)
      const response = await api.get('/orders/by_code/', { params: { code } })
      console.log('Order response:', response.data)
      currentOrder.value = response.data
      return { success: true, data: response.data }
    } catch (error) {
      console.error('Error fetching order:', error)
      console.error('Error response:', error.response)
      currentOrder.value = null
      return { 
        success: false, 
        error: error.response?.data || { detail: error.message || 'Failed to fetch order' }
      }
    }
  }

  async function createOrder(orderData) {
    try {
      const response = await api.post('/orders/', orderData)
      orders.value.unshift(response.data)
      return { success: true, data: response.data }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function fetchUsers() {
    try {
      // Fetch all users with pagination support
      let allUsers = []
      let url = '/users/'
      
      while (url) {
        const response = await api.get(url)
        const data = response.data
        if (data.results) {
          // Paginated response
          allUsers = allUsers.concat(data.results)
          url = data.next || null
        } else {
          // Non-paginated response
          allUsers = Array.isArray(data) ? data : [data]
          url = null
        }
      }
      
      return { success: true, data: allUsers }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function lockOrder(orderId) {
    try {
      const response = await api.post(`/orders/${orderId}/lock/`)
      updateOrderInList(response.data)
      return { success: true, data: response.data }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function markOrdered(orderId) {
    try {
      const response = await api.post(`/orders/${orderId}/mark_ordered/`)
      updateOrderInList(response.data)
      return { success: true, data: response.data }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function closeOrder(orderId) {
    try {
      const response = await api.post(`/orders/${orderId}/close/`)
      updateOrderInList(response.data)
      return { success: true, data: response.data }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function unlockOrder(orderId) {
    try {
      const response = await api.post(`/orders/${orderId}/unlock/`)
      updateOrderInList(response.data)
      if (currentOrder.value?.id === response.data.id) {
        currentOrder.value = response.data
      }
      return { success: true, data: response.data }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function deleteOrder(orderId) {
    try {
      await api.delete(`/orders/${orderId}/`)
      orders.value = orders.value.filter(o => o.id !== orderId)
      if (currentOrder.value?.id === orderId) {
        currentOrder.value = null
      }
      return { success: true }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function fetchRestaurants() {
    try {
      const response = await api.get('/restaurants/')
      restaurants.value = response.data.results || response.data
      return { success: true }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function fetchMenus(restaurantId) {
    try {
      const response = await api.get('/menus/', { params: { restaurant: restaurantId } })
      const menus = response.data.results || response.data
      menus.value = menus
      return { success: true, data: menus }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function createRestaurant(restaurantData) {
    try {
      const response = await api.post('/restaurants/', restaurantData)
      restaurants.value.push(response.data)
      return { success: true, data: response.data }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function updateRestaurant(restaurantId, restaurantData) {
    try {
      const response = await api.patch(`/restaurants/${restaurantId}/`, restaurantData)
      const index = restaurants.value.findIndex(r => r.id === restaurantId)
      if (index !== -1) {
        restaurants.value[index] = response.data
      }
      return { success: true, data: response.data }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function deleteRestaurant(restaurantId) {
    try {
      await api.delete(`/restaurants/${restaurantId}/`)
      restaurants.value = restaurants.value.filter(r => r.id !== restaurantId)
      return { success: true }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function fetchMenuItems(menuId) {
    try {
      const response = await api.get('/menu-items/', { params: { menu: menuId } })
      menuItems.value = response.data.results || response.data
      return { success: true }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function addOrderItem(itemData) {
    try {
      const response = await api.post('/order-items/', itemData)
      if (currentOrder.value) {
        await fetchOrderByCode(currentOrder.value.code)
      }
      return { success: true, data: response.data }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function addItemToMenu(itemId, menuId = null) {
    try {
      const data = menuId ? { menu_id: menuId } : {}
      const response = await api.post(`/order-items/${itemId}/add_to_menu/`, data)
      if (currentOrder.value) {
        await fetchOrderByCode(currentOrder.value.code)
      }
      return { success: true, data: response.data }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function updateMenuItemPrice(itemId, price) {
    try {
      const response = await api.post(`/order-items/${itemId}/update_menu_item_price/`, { price })
      if (currentOrder.value) {
        await fetchOrderByCode(currentOrder.value.code)
      }
      return { success: true, data: response.data }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function removeOrderItem(itemId) {
    try {
      await api.delete(`/order-items/${itemId}/`)
      if (currentOrder.value) {
        await fetchOrderByCode(currentOrder.value.code)
      }
      return { success: true }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function fetchFeePresets() {
    try {
      const response = await api.get('/fee-presets/')
      feePresets.value = response.data.results || response.data
      return { success: true }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function getMonthlyReport(userId) {
    try {
      const response = await api.get('/orders/monthly_report/', { 
        params: { user_id: userId } 
      })
      return { success: true, data: response.data }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  async function fetchPayments(orderId) {
    try {
      const response = await api.get('/payments/', { params: { order: orderId } })
      return { success: true, data: response.data.results || response.data }
    } catch (error) {
      return { success: false, error: error.response?.data }
    }
  }

  function updateOrderInList(updatedOrder) {
    const index = orders.value.findIndex(o => o.id === updatedOrder.id)
    if (index !== -1) {
      orders.value[index] = updatedOrder
    }
    if (currentOrder.value?.id === updatedOrder.id) {
      currentOrder.value = updatedOrder
    }
  }

  return {
    orders,
    currentOrder,
    restaurants,
    menus,
    menuItems,
    feePresets,
    fetchOrders,
    fetchOrderByCode,
    createOrder,
    fetchUsers,
    lockOrder,
    unlockOrder,
    markOrdered,
    closeOrder,
    deleteOrder,
    fetchRestaurants,
    createRestaurant,
    updateRestaurant,
    deleteRestaurant,
    fetchMenus,
    fetchMenuItems,
    addOrderItem,
    removeOrderItem,
    addItemToMenu,
    updateMenuItemPrice,
    fetchFeePresets,
    getMonthlyReport,
  }
})

