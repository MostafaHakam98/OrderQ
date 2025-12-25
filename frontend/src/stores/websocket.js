import { defineStore } from 'pinia'
import { ref } from 'vue'

export const useWebSocketStore = defineStore('websocket', () => {
  const socket = ref(null)
  const connected = ref(false)
  const reconnectAttempts = ref(0)
  const maxReconnectAttempts = 5
  const reconnectDelay = 3000

  function getWebSocketUrl(orderId) {
    // Use the same host and protocol as the current page
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
    const host = window.location.host
    
    // Get JWT token for authentication
    const token = localStorage.getItem('access_token')
    
    // Build WebSocket URL - use same host as current page
    let wsUrl = `${protocol}//${host}/ws/orders/${orderId}/`
    
    // Add token as query parameter for JWT authentication
    if (token) {
      wsUrl += `?token=${encodeURIComponent(token)}`
    } else {
      console.warn('No access token found for WebSocket authentication')
    }
    
    return wsUrl
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
        console.log('WebSocket connected for order:', orderId)
        connected.value = true
        reconnectAttempts.value = 0
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
        console.error('WebSocket error for order', orderId, ':', error)
        connected.value = false
      }
      
      ws.onclose = (event) => {
        console.log('WebSocket closed for order', orderId, ':', event.code, event.reason)
        connected.value = false
        
        // Attempt to reconnect if not a normal closure and we have a callback
        if (event.code !== 1000 && reconnectAttempts.value < maxReconnectAttempts && onMessage) {
          reconnectAttempts.value++
          console.log(`Reconnecting WebSocket for order ${orderId} in ${reconnectDelay}ms (attempt ${reconnectAttempts.value}/${maxReconnectAttempts})`)
          setTimeout(() => {
            connect(orderId, onMessage)
          }, reconnectDelay)
        } else if (event.code === 1000) {
          console.log('WebSocket closed normally for order', orderId)
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

