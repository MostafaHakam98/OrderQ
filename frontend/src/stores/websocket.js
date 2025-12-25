import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useWebSocketStore = defineStore('websocket', () => {
  const socket = ref(null)
  const connected = ref(false)
  const reconnectAttempts = ref(0)
  const maxReconnectAttempts = 5
  const reconnectDelay = 3000

  function getWebSocketUrl(orderId) {
    // Get the base URL from the API base URL
    const apiBaseUrl = import.meta.env.VITE_API_BASE_URL || '/api'
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
    
    // If API base URL is relative, use current host
    if (apiBaseUrl.startsWith('/')) {
      return `${protocol}//${window.location.host}${apiBaseUrl.replace('/api', '')}/ws/orders/${orderId}/`
    }
    
    // If API base URL is absolute, convert to WebSocket URL
    const url = new URL(apiBaseUrl.replace('/api', ''))
    return `${protocol}//${url.host}/ws/orders/${orderId}/`
  }

  function connect(orderId, onMessage) {
    if (socket.value && socket.value.readyState === WebSocket.OPEN) {
      // Already connected to this order
      if (socket.value.url.includes(`/orders/${orderId}/`)) {
        return
      }
      // Different order, close and reconnect
      disconnect()
    }

    const wsUrl = getWebSocketUrl(orderId)
    console.log('Connecting to WebSocket:', wsUrl)
    
    try {
      const ws = new WebSocket(wsUrl)
      
      ws.onopen = () => {
        console.log('WebSocket connected')
        connected.value = true
        reconnectAttempts.value = 0
        
        // Send authentication token if available
        const token = localStorage.getItem('access_token')
        if (token) {
          // Note: WebSocket authentication is handled by Django Channels middleware
          // The token should be sent via query parameter or header if needed
        }
      }
      
      ws.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data)
          if (data.type === 'order_update' && data.order) {
            onMessage(data.order)
          } else if (data.type === 'pong') {
            // Heartbeat response
          }
        } catch (error) {
          console.error('Error parsing WebSocket message:', error)
        }
      }
      
      ws.onerror = (error) => {
        console.error('WebSocket error:', error)
        connected.value = false
      }
      
      ws.onclose = (event) => {
        console.log('WebSocket closed:', event.code, event.reason)
        connected.value = false
        
        // Attempt to reconnect if not a normal closure
        if (event.code !== 1000 && reconnectAttempts.value < maxReconnectAttempts) {
          reconnectAttempts.value++
          console.log(`Reconnecting in ${reconnectDelay}ms (attempt ${reconnectAttempts.value}/${maxReconnectAttempts})`)
          setTimeout(() => {
            connect(orderId, onMessage)
          }, reconnectDelay)
        }
      }
      
      // Send ping every 30 seconds to keep connection alive
      const pingInterval = setInterval(() => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: 'ping' }))
        } else {
          clearInterval(pingInterval)
        }
      }, 30000)
      
      socket.value = ws
    } catch (error) {
      console.error('Error creating WebSocket:', error)
      connected.value = false
    }
  }

  function disconnect() {
    if (socket.value) {
      socket.value.close(1000, 'Client disconnecting')
      socket.value = null
      connected.value = false
    }
  }

  return {
    socket,
    connected,
    connect,
    disconnect
  }
})

