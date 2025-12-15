<template>
  <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <div v-if="loading" class="text-center py-8">
      <p class="text-lg text-gray-900 dark:text-white">Loading order...</p>
      <p class="text-sm text-gray-500 dark:text-gray-400 mt-2">Code: {{ route.params.code }}</p>
    </div>
    <div v-else-if="error" class="text-center py-8">
      <p class="text-red-600 dark:text-red-400 text-lg mb-4">{{ error }}</p>
      <button
        @click="loadOrder()"
        class="bg-blue-600 dark:bg-blue-500 text-white px-4 py-2 rounded-md hover:bg-blue-700 dark:hover:bg-blue-600 mr-2"
      >
        Retry
      </button>
      <button
        @click="router.push('/orders')"
        class="bg-gray-600 dark:bg-gray-500 text-white px-4 py-2 rounded-md hover:bg-gray-700 dark:hover:bg-gray-600"
      >
        Back to Orders
      </button>
    </div>
    <div v-else-if="!currentOrder" class="text-center py-8 text-gray-500 dark:text-gray-400">
      <p class="text-lg mb-4">Order not found</p>
      <button
        @click="loadOrder()"
        class="bg-blue-600 dark:bg-blue-500 text-white px-4 py-2 rounded-md hover:bg-blue-700 dark:hover:bg-blue-600 mr-2"
      >
        Retry
      </button>
      <button
        @click="router.push('/orders')"
        class="bg-gray-600 dark:bg-gray-500 text-white px-4 py-2 rounded-md hover:bg-gray-700 dark:hover:bg-gray-600"
      >
        Back to Orders
      </button>
    </div>
    <div v-else>
      <div class="mb-6" v-if="currentOrder">
        <button
          @click="router.push('/orders')"
          class="text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 mb-4 flex items-center"
        >
          ← Back to Orders
        </button>
        <div class="flex justify-between items-start">
          <div>
            <h1 class="text-3xl font-bold text-gray-900 dark:text-white">{{ currentOrder?.restaurant_name || 'Unknown Restaurant' }}</h1>
            <p class="text-gray-600 dark:text-gray-400 mt-2">Code: <span class="font-mono font-semibold text-blue-600 dark:text-blue-400">{{ currentOrder?.code || 'N/A' }}</span></p>
            <p class="text-gray-600 dark:text-gray-400">Collector: <span class="font-semibold">{{ currentOrder?.collector_name || 'N/A' }}</span></p>
            <p v-if="currentOrder?.cutoff_time" class="text-gray-600 dark:text-gray-400">Cutoff: <span class="font-semibold">{{ formatCutoffTime(currentOrder.cutoff_time) }}</span></p>
            <p v-if="currentOrder?.assigned_users_details && currentOrder.assigned_users_details.length > 0" class="text-gray-600 dark:text-gray-400 mt-2">
              <span class="font-semibold">Assigned to:</span> 
              <span class="text-blue-600 dark:text-blue-400">{{ currentOrder.assigned_users_details.map(u => u.username).join(', ') }}</span>
            </p>
            <p v-if="currentOrder?.is_private" class="text-xs text-gray-500 dark:text-gray-400 mt-1">🔒 Private Order</p>
          </div>
          <div class="text-right">
            <div class="inline-block px-4 py-2 rounded-lg font-semibold" :class="{
              'bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300': currentOrder?.status === 'OPEN',
              'bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300': currentOrder?.status === 'LOCKED',
              'bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300': currentOrder?.status === 'ORDERED',
              'bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-300': currentOrder?.status === 'CLOSED',
            }">
              Status: {{ currentOrder?.status || 'UNKNOWN' }}
            </div>
            <p v-if="currentOrder?.status && currentOrder.status !== 'OPEN'" class="text-sm text-gray-500 dark:text-gray-400 mt-2">
              {{ currentOrder.status === 'LOCKED' ? 'Order is locked. No items can be added or removed.' : '' }}
              {{ currentOrder.status === 'ORDERED' ? 'Order has been placed.' : '' }}
              {{ currentOrder.status === 'CLOSED' ? 'Order is closed.' : '' }}
            </p>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6" v-if="currentOrder">
        <div class="lg:col-span-2 space-y-6">
          <!-- Assigned Users Notice -->
          <div v-if="currentOrder?.assigned_users_details && currentOrder.assigned_users_details.length > 0" class="bg-blue-50 dark:bg-blue-900/30 border border-blue-200 dark:border-blue-700 rounded-lg p-4">
            <p class="text-sm font-medium text-blue-900 dark:text-blue-300 mb-1">👥 Assigned Order</p>
            <p class="text-xs text-blue-700 dark:text-blue-400">This order is assigned to specific users. Only assigned users can join.</p>
            <p class="text-xs text-blue-600 dark:text-blue-400 mt-1">
              Assigned to: {{ currentOrder.assigned_users_details.map(u => u.username).join(', ') }}
            </p>
          </div>
          
          <!-- Status Message for Locked/Ordered/Closed -->
          <div v-if="currentOrder?.status !== 'OPEN'" class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <div class="text-center py-4">
              <p class="text-lg font-semibold mb-2 dark:text-white">
                Order is {{ currentOrder.status }}
              </p>
              <p class="text-gray-600 dark:text-gray-400 text-sm">
                {{ currentOrder.status === 'LOCKED' ? 'The collector has locked this order. Items cannot be added or removed.' : '' }}
                {{ currentOrder.status === 'ORDERED' ? 'This order has been placed with the restaurant.' : '' }}
                {{ currentOrder.status === 'CLOSED' ? 'This order is closed.' : '' }}
              </p>
            </div>
          </div>

          <!-- Add Items Section (only if OPEN) -->
          <div v-if="currentOrder?.status === 'OPEN'" class="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-100 dark:border-gray-700">
            <h2 class="text-xl font-semibold mb-4 text-gray-800 dark:text-white">Add Items to Order</h2>
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Menu Item
                  <span v-if="currentOrder?.menu_name" class="text-xs text-gray-500 dark:text-gray-400 font-normal">
                    ({{ currentOrder.menu_name }})
                  </span>
                </label>
                <select
                  v-model="selectedMenuItem"
                  :disabled="availableMenuItems.length === 0"
                  class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md disabled:bg-gray-100 dark:disabled:bg-gray-700 disabled:cursor-not-allowed dark:bg-gray-700 dark:text-white"
                >
                  <option value="">
                    {{ availableMenuItems.length === 0 ? 'No menu items available' : 'Select menu item' }}
                  </option>
                  <option v-for="item in availableMenuItems" :key="item.id" :value="item.id">
                    {{ item.name }} - {{ item.price }} EGP
                  </option>
                </select>
                <p v-if="availableMenuItems.length === 0" class="mt-1 text-xs text-gray-500 dark:text-gray-400">
                  No menu items found for this order's menu. You can still add custom items below.
                </p>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">
                  Assign to User
                  <span class="text-xs text-gray-500 font-normal">
                    ({{ selectedItemUser ? 'Assigned to ' + (allUsers.find(u => u.id === selectedItemUser)?.username || 'selected user') : 'You (default)' }})
                  </span>
                </label>
                <select
                  v-model="selectedItemUser"
                  :disabled="currentOrder?.collector !== authStore.user?.id && !authStore.isManager"
                  class="w-full px-3 py-2 border border-gray-300 rounded-md disabled:bg-gray-100 disabled:cursor-not-allowed"
                  @focus="ensureUsersLoaded"
                >
                  <option :value="null">Me ({{ authStore.user?.username }})</option>
                  <option v-for="user in allUsers" :key="user.id" :value="user.id">
                    {{ user.username }}
                  </option>
                </select>
                <p class="mt-1 text-xs text-gray-500">
                  <span v-if="currentOrder?.collector === authStore.user?.id || authStore.isManager">
                    You can assign items to other users
                  </span>
                  <span v-else>
                    Only collectors and managers can assign items to other users
                  </span>
                </p>
              </div>
              <div class="flex space-x-2">
                <input
                  v-model.number="itemQuantity"
                  type="number"
                  min="1"
                  placeholder="Quantity"
                  class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                />
                <button
                  @click="addMenuItem"
                  :disabled="!selectedMenuItem || !itemQuantity"
                  class="bg-blue-600 dark:bg-blue-500 text-white px-4 py-2 rounded-md hover:bg-blue-700 dark:hover:bg-blue-600 disabled:opacity-50"
                >
                  Add
                </button>
              </div>
              <div class="border-t dark:border-gray-700 pt-4">
                <p class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Or add custom item:</p>
                <div class="space-y-2">
                  <div class="flex space-x-2">
                    <input
                      v-model="customItemName"
                      type="text"
                      placeholder="Item name"
                      class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                    />
                    <input
                      v-model.number="customItemPrice"
                      type="number"
                      step="0.01"
                      placeholder="Price"
                      class="w-24 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                    />
                    <button
                      @click="addCustomItem"
                      :disabled="!customItemName || !customItemPrice"
                      class="bg-green-600 dark:bg-green-500 text-white px-4 py-2 rounded-md hover:bg-green-700 dark:hover:bg-green-600 disabled:opacity-50"
                    >
                      Add Custom
                    </button>
                  </div>
                  <p class="text-xs text-gray-500">
                    Custom item will be assigned to: {{ selectedItemUser ? (allUsers.find(u => u.id === selectedItemUser)?.username || 'selected user') : authStore.user?.username }}
                  </p>
                </div>
              </div>
            </div>
          </div>

          <!-- Order Items -->
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-100 dark:border-gray-700">
            <h2 class="text-xl font-semibold mb-4 text-gray-800 dark:text-white">Order Items</h2>
            <div v-if="!currentOrder?.items || currentOrder.items.length === 0" class="text-gray-500 dark:text-gray-400 text-center py-4">
              No items yet. {{ currentOrder?.status === 'OPEN' ? 'Add items above!' : '' }}
            </div>
            <div v-else class="space-y-2">
              <div
                v-for="item in currentOrder.items"
                :key="item.id"
                :class="[
                  'flex justify-between items-center p-3 border rounded',
                  item.user === authStore.user?.id ? 'border-blue-300 dark:border-blue-600 bg-blue-50 dark:bg-blue-900/30' : 'border-gray-200 dark:border-gray-700'
                ]"
              >
                <div class="flex-1">
                  <div class="flex items-center space-x-2">
                    <p class="font-medium dark:text-white">{{ item.item_name }}</p>
                    <span v-if="item.user === authStore.user?.id" class="text-xs bg-blue-600 dark:bg-blue-500 text-white px-2 py-0.5 rounded">
                      Your Item
                    </span>
                  </div>
                  <p class="text-sm text-gray-600 dark:text-gray-400">{{ item.user_name }} - Qty: {{ item.quantity }} × {{ formatPrice(item.unit_price) }} EGP</p>
                </div>
                <div class="flex items-center space-x-4">
                  <span class="font-semibold dark:text-white">{{ formatPrice(item.total_price) }} EGP</span>
                  <button
                    v-if="currentOrder?.status === 'OPEN' && item.user === authStore.user?.id"
                    @click="removeItem(item.id)"
                    class="bg-red-600 dark:bg-red-500 text-white px-3 py-1 rounded text-sm hover:bg-red-700 dark:hover:bg-red-600"
                    title="Remove your item"
                  >
                    Remove
                  </button>
                  <button
                    v-if="currentOrder?.status === 'OPEN' && currentOrder.collector === authStore.user?.id && item.user !== authStore.user?.id"
                    @click="removeItem(item.id)"
                    class="bg-red-600 dark:bg-red-500 text-white px-3 py-1 rounded text-sm hover:bg-red-700 dark:hover:bg-red-600"
                    title="Remove item (collector)"
                  >
                    Remove
                  </button>
                  <span v-if="currentOrder?.status !== 'OPEN'" class="text-xs text-gray-400 dark:text-gray-500">Locked</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Sidebar -->
        <div class="space-y-6">
          <!-- Order Summary -->
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold mb-4 dark:text-white">Summary</h2>
            <div class="space-y-2 text-sm">
              <div class="flex justify-between dark:text-gray-300">
                <span>Items Total:</span>
                <span>{{ formatPrice(currentOrder?.total_items_cost) }} EGP</span>
              </div>
              <div class="flex justify-between dark:text-gray-300">
                <span>Delivery:</span>
                <span>{{ formatPrice(currentOrder?.delivery_fee) }} EGP</span>
              </div>
              <div class="flex justify-between dark:text-gray-300">
                <span>Tip:</span>
                <span>{{ formatPrice(currentOrder?.tip) }} EGP</span>
              </div>
              <div class="flex justify-between dark:text-gray-300">
                <span>Service:</span>
                <span>{{ formatPrice(currentOrder?.service_fee) }} EGP</span>
              </div>
              <div class="border-t dark:border-gray-700 pt-2 flex justify-between font-semibold dark:text-white">
                <span>Total:</span>
                <span>{{ formatPrice(currentOrder?.total_cost) }} EGP</span>
              </div>
            </div>
          </div>

          <!-- Actions (Collector and Manager) -->
          <div v-if="currentOrder?.collector === authStore.user?.id || authStore.isManager" class="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-100 dark:border-gray-700">
            <h2 class="text-xl font-semibold mb-4 text-gray-800 dark:text-white">Actions & Fees</h2>
            <p v-if="currentOrder?.collector === authStore.user?.id" class="text-sm text-gray-600 dark:text-gray-400 mb-4">
              <strong>How it works:</strong> You (the collector) pay the restaurant for everyone's items plus fees. 
              Then each person pays you back their share. Use the fee split rules below to calculate how much each person owes.
            </p>
            <div class="space-y-2">
              <div v-if="currentOrder?.status === 'OPEN' && currentOrder?.collector === authStore.user?.id">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Fees</label>
                <input
                  v-model.number="fees.delivery_fee"
                  type="number"
                  step="0.01"
                  placeholder="Delivery Fee"
                  class="w-full mb-2 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                />
                <input
                  v-model.number="fees.tip"
                  type="number"
                  step="0.01"
                  placeholder="Tip"
                  class="w-full mb-2 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                />
                <input
                  v-model.number="fees.service_fee"
                  type="number"
                  step="0.01"
                  placeholder="Service Fee"
                  class="w-full mb-2 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                />
                <select
                  v-model="fees.fee_split_rule"
                  class="w-full mb-2 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 dark:bg-gray-700 dark:text-white"
                >
                  <option value="equal">Equal Split - Fees divided equally</option>
                  <option value="proportional">Proportional - Based on item cost</option>
                  <option value="collector_pays">Collector Pays - You pay all fees</option>
                </select>
                <p class="text-xs text-gray-500 dark:text-gray-400 mt-1 mb-2">
                  <strong>Fee Split Rules:</strong><br>
                  • <strong>Equal:</strong> Fees split equally among everyone<br>
                  • <strong>Proportional:</strong> Fees split based on each person's item cost<br>
                  • <strong>Collector Pays:</strong> You pay all fees, others only pay for their items
                </p>
                <input
                  v-model="fees.instapay_link"
                  type="url"
                  placeholder="Instapay Link"
                  class="w-full mb-2 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                />
                <button
                  @click="updateFees"
                  class="w-full bg-yellow-600 dark:bg-yellow-500 text-white px-4 py-2 rounded-md hover:bg-yellow-700 dark:hover:bg-yellow-600 focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:ring-offset-2 transition-colors"
                >
                  Update Fees
                </button>
              <button
                v-if="currentOrder?.status === 'OPEN' && (currentOrder?.collector === authStore.user?.id || authStore.isManager)"
                @click="lockOrder"
                class="w-full mt-2 bg-red-600 dark:bg-red-500 text-white px-4 py-2 rounded-md hover:bg-red-700 dark:hover:bg-red-600 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 transition-colors"
              >
                🔒 Lock Order
              </button>
              <!-- Collector Delete Button (only for OPEN orders, and not manager) -->
              <button
                v-if="!authStore.isManager && currentOrder?.status === 'OPEN' && currentOrder?.collector === authStore.user?.id"
                @click="deleteOrder"
                class="w-full mt-2 bg-red-800 dark:bg-red-700 text-white px-4 py-2 rounded-md hover:bg-red-900 dark:hover:bg-red-800 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 transition-colors"
              >
                🗑️ Delete Order
              </button>
              <!-- Manager Delete Button in main section (when manager is also collector) -->
              <button
                v-if="authStore.isManager && currentOrder?.collector === authStore.user?.id"
                @click="deleteOrder"
                class="w-full mt-2 bg-red-800 dark:bg-red-700 text-white px-4 py-2 rounded-md hover:bg-red-900 dark:hover:bg-red-800 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 transition-colors"
              >
                🗑️ Delete Order (Manager)
              </button>
              <!-- Assign Users Section (Compact) -->
              <div v-if="currentOrder?.status === 'OPEN'" class="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
                <button
                  @click="toggleAssignUsers"
                  class="w-full flex items-center justify-between text-sm text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-white py-2"
                >
                  <span class="flex items-center">
                    <span class="mr-2">👥</span>
                    <span>Assign to Specific Users</span>
                    <span v-if="currentOrder?.assigned_users_details?.length > 0" class="ml-2 text-xs bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300 px-2 py-0.5 rounded-full">
                      {{ currentOrder.assigned_users_details.length }}
                    </span>
                  </span>
                  <span class="text-gray-400 dark:text-gray-500">{{ showAssignUsers ? '▼' : '▶' }}</span>
                </button>
                <div v-if="showAssignUsers" class="mt-3 space-y-2 bg-gray-50 dark:bg-gray-700/50 p-3 rounded-md">
                  <p class="text-xs text-gray-600 dark:text-gray-400 mb-2">Select users for special orders (e.g., birthday cake). Order will be private.</p>
                  <div class="flex space-x-1 mb-2">
                    <button
                      type="button"
                      @click="selectAllUsers"
                      class="text-xs bg-white dark:bg-gray-600 hover:bg-gray-100 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-300 px-2 py-1 rounded border border-gray-300 dark:border-gray-500"
                    >
                      All
                    </button>
                    <button
                      type="button"
                      @click="deselectAllUsers"
                      class="text-xs bg-white dark:bg-gray-600 hover:bg-gray-100 dark:hover:bg-gray-500 text-gray-700 dark:text-gray-300 px-2 py-1 rounded border border-gray-300 dark:border-gray-500"
                    >
                      None
                    </button>
                  </div>
                  <select
                    v-model="selectedUsers"
                    multiple
                    class="w-full text-sm px-2 py-1.5 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white"
                    size="4"
                  >
                    <option v-for="user in allUsers" :key="user.id" :value="user.id">
                      {{ user.username }}
                    </option>
                  </select>
                  <p v-if="selectedUsers.length > 0" class="text-xs text-blue-600 dark:text-blue-400 mt-1">
                    {{ selectedUsers.length }} selected
                  </p>
                  
                  <!-- Even Split Option -->
                  <div class="mt-3 pt-3 border-t border-gray-300 dark:border-gray-600">
                    <p class="text-xs font-medium text-gray-700 dark:text-gray-300 mb-2">Optional: Split evenly among assigned users</p>
                    <div class="space-y-2">
                      <div>
                        <label class="block text-xs text-gray-600 dark:text-gray-400 mb-1">Number of items per user</label>
                        <input
                          v-model.number="assignmentItems"
                          type="number"
                          min="1"
                          placeholder="e.g., 2"
                          class="w-full text-sm px-2 py-1.5 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                        />
                      </div>
                      <div>
                        <label class="block text-xs text-gray-600 dark:text-gray-400 mb-1">Total cost (including delivery/fees)</label>
                        <input
                          v-model.number="assignmentTotalCost"
                          type="number"
                          step="0.01"
                          min="0"
                          placeholder="e.g., 500"
                          class="w-full text-sm px-2 py-1.5 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500 dark:bg-gray-700 dark:text-white dark:placeholder-gray-400"
                        />
                      </div>
                      <p v-if="assignmentItems && assignmentTotalCost && selectedUsers.length > 0" class="text-xs text-green-600 dark:text-green-400 mt-1">
                        Each user will get {{ assignmentItems }} item(s) × {{ formatPrice(assignmentTotalCost / selectedUsers.length / assignmentItems) }} EGP = {{ formatPrice(assignmentTotalCost / selectedUsers.length) }} EGP per user
                      </p>
                    </div>
                  </div>
                  
                  <button
                    @click="updateAssignedUsers"
                    :disabled="loading || (assignmentItems && !assignmentTotalCost) || (assignmentTotalCost && !assignmentItems)"
                    class="w-full text-xs bg-blue-600 dark:bg-blue-500 text-white px-3 py-1.5 rounded-md hover:bg-blue-700 dark:hover:bg-blue-600 disabled:opacity-50 mt-3"
                  >
                    {{ loading ? 'Saving...' : 'Save Assignment' }}
                  </button>
                </div>
              </div>
              
              <div v-if="currentOrder?.status === 'OPEN' && currentOrder?.collector === authStore.user?.id && currentOrder?.participants?.length > 1" class="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Transfer Collector Role</label>
                <select
                  v-model="transferCollectorId"
                  class="w-full mb-2 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-purple-500 dark:bg-gray-700 dark:text-white"
                >
                  <option value="">Select new collector</option>
                  <option
                    v-for="participant in currentOrder.participants"
                    :key="participant.id"
                    :value="participant.id"
                    :disabled="participant.id === currentOrder.collector"
                  >
                    {{ participant.username }} {{ participant.id === currentOrder.collector ? '(Current)' : '' }}
                  </option>
                </select>
                <button
                  @click="transferCollector"
                  :disabled="!transferCollectorId"
                  class="w-full bg-purple-600 dark:bg-purple-500 text-white px-4 py-2 rounded-md hover:bg-purple-700 dark:hover:bg-purple-600 disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-purple-500 focus:ring-offset-2"
                >
                  Transfer Collector Role
                </button>
              </div>
              </div>
              <!-- Unlock button for LOCKED orders (visible to collector and manager) -->
              <button
                v-if="currentOrder?.status === 'LOCKED' && (currentOrder?.collector === authStore.user?.id || authStore.isManager)"
                @click="unlockOrder"
                class="w-full mt-2 bg-orange-600 dark:bg-orange-500 text-white px-4 py-2 rounded-md hover:bg-orange-700 dark:hover:bg-orange-600 focus:outline-none focus:ring-2 focus:ring-orange-500 focus:ring-offset-2 transition-colors"
              >
                🔓 Unlock Order
              </button>
              <!-- Mark as Ordered button (collector only) -->
              <button
                v-if="currentOrder?.status === 'LOCKED' && currentOrder?.collector === authStore.user?.id"
                @click="markOrdered"
                class="w-full bg-blue-600 dark:bg-blue-500 text-white px-4 py-2 rounded-md hover:bg-blue-700 dark:hover:bg-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 transition-colors"
              >
                ✅ Mark as Ordered
              </button>
              <!-- Close Order button (collector and manager) -->
              <button
                v-if="currentOrder?.status === 'ORDERED' && (currentOrder?.collector === authStore.user?.id || authStore.isManager)"
                @click="closeOrder"
                class="w-full bg-gray-600 dark:bg-gray-500 text-white px-4 py-2 rounded-md hover:bg-gray-700 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 transition-colors"
              >
                🔚 Close Order
              </button>
            </div>
          </div>

          <!-- Manager-only actions section (always visible for managers) -->
          <div v-if="authStore.isManager" class="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-100 dark:border-gray-700">
            <h2 class="text-xl font-semibold mb-4 text-gray-800 dark:text-white">Manager Actions</h2>
            <div class="space-y-2">
              <button
                v-if="currentOrder?.status === 'OPEN'"
                @click="lockOrder"
                class="w-full bg-red-600 dark:bg-red-500 text-white px-4 py-2 rounded-md hover:bg-red-700 dark:hover:bg-red-600 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 transition-colors"
              >
                🔒 Lock Order
              </button>
              <button
                v-if="currentOrder?.status === 'LOCKED'"
                @click="unlockOrder"
                class="w-full bg-orange-600 dark:bg-orange-500 text-white px-4 py-2 rounded-md hover:bg-orange-700 dark:hover:bg-orange-600 focus:outline-none focus:ring-2 focus:ring-orange-500 focus:ring-offset-2 transition-colors"
              >
                🔓 Unlock Order
              </button>
              <button
                v-if="currentOrder?.status === 'ORDERED'"
                @click="closeOrder"
                class="w-full bg-gray-600 dark:bg-gray-500 text-white px-4 py-2 rounded-md hover:bg-gray-700 dark:hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 transition-colors"
              >
                🔚 Close Order
              </button>
              <button
                @click="deleteOrder"
                class="w-full bg-red-800 dark:bg-red-700 text-white px-4 py-2 rounded-md hover:bg-red-900 dark:hover:bg-red-800 focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2 transition-colors"
              >
                🗑️ Delete Order
              </button>
            </div>
          </div>

          <!-- Share Message -->
          <div class="bg-white dark:bg-gray-800 rounded-lg shadow-md p-6 border border-gray-100 dark:border-gray-700">
            <h2 class="text-xl font-semibold mb-4 text-gray-800 dark:text-white">Share Message</h2>
            <textarea
              :value="currentOrder?.share_message || ''"
              readonly
              class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-sm dark:bg-gray-700 dark:text-white"
              rows="4"
            ></textarea>
            <button
              @click="copyShareMessage"
              class="mt-2 w-full bg-green-600 dark:bg-green-500 text-white px-4 py-2 rounded-md hover:bg-green-700 dark:hover:bg-green-600"
            >
              Copy Message
            </button>
          </div>

          <!-- Payment Breakdown (if locked) -->
          <div v-if="currentOrder?.status !== 'OPEN' && currentOrder?.payments && currentOrder.payments.length > 0" class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold mb-4 dark:text-white">Payment Breakdown</h2>
            <!-- Show message if only collector's payment exists and it's paid -->
            <div v-if="currentOrder.payments.length === 1 && currentOrder.payments[0].user === currentOrder?.collector && currentOrder.payments[0].is_paid" class="p-4 bg-green-50 dark:bg-green-900/30 border border-green-200 dark:border-green-700 rounded">
              <p class="text-sm text-gray-700 dark:text-gray-300">
                ✅ Your payment ({{ formatPrice(currentOrder.payments[0].amount) }} EGP) has been automatically marked as paid since you are the collector.
              </p>
            </div>
            <div v-else class="space-y-3">
              <div
                v-for="payment in currentOrder.payments.filter(p => {
                  // Show all payments, but hide collector's payment only if it's paid and there are other payments
                  // If collector is ordering only for themselves, show their payment
                  if (p.user === currentOrder?.collector && p.is_paid && currentOrder.payments.length > 1) {
                    return false
                  }
                  return true
                })"
                :key="payment.id"
                :class="[
                  'flex items-center p-3 border rounded',
                  payment.is_paid ? 'bg-green-50 dark:bg-green-900/30 border-green-200 dark:border-green-700' : 'bg-yellow-50 dark:bg-yellow-900/30 border-yellow-200 dark:border-yellow-700'
                ]"
              >
                <div class="flex-1 min-w-0">
                  <p class="font-medium dark:text-white">{{ payment.user_name }}</p>
                  <p class="text-sm text-gray-600 dark:text-gray-400">
                    {{ payment.is_paid ? '✅ Paid' : '⏳ Pending' }}
                    <span v-if="payment.paid_at" class="ml-2 text-xs">
                      ({{ new Date(payment.paid_at).toLocaleString() }})
                    </span>
                  </p>
                </div>
                <div class="text-right mx-4 flex-shrink-0">
                  <p class="font-semibold text-lg dark:text-white whitespace-nowrap">{{ formatPrice(payment.amount) }} EGP</p>
                  <button
                    v-if="!payment.is_paid && currentOrder?.instapay_link && payment.user === authStore.user?.id"
                    @click="openInstapay"
                    class="mt-1 text-xs text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 underline"
                  >
                    Pay via Instapay
                  </button>
                </div>
                <button
                  v-if="!payment.is_paid && payment.user !== currentOrder?.collector && (currentOrder?.collector === authStore.user?.id || payment.user === authStore.user?.id)"
                  @click="markPaymentPaid(payment.id)"
                  class="bg-green-600 dark:bg-green-500 text-white px-3 py-1 rounded text-sm hover:bg-green-700 dark:hover:bg-green-600 flex-shrink-0"
                >
                  {{ payment.user === authStore.user?.id ? 'Mark as Paid' : 'Mark Paid' }}
                </button>
              </div>
            </div>
            <div v-if="currentOrder?.instapay_link && currentOrder.collector === authStore.user?.id" class="mt-4 p-3 bg-blue-50 dark:bg-blue-900/30 rounded">
              <p class="text-sm font-medium mb-2 dark:text-white">Instapay Link:</p>
              <div class="flex items-center space-x-2">
                <input
                  :value="currentOrder.instapay_link"
                  readonly
                  class="flex-1 px-2 py-1 border border-gray-300 dark:border-gray-600 rounded text-sm dark:bg-gray-700 dark:text-white"
                />
                <button
                  @click="copyInstapayLink"
                  class="bg-blue-600 dark:bg-blue-500 text-white px-3 py-1 rounded text-sm hover:bg-blue-700 dark:hover:bg-blue-600"
                >
                  Copy
                </button>
              </div>
            </div>
          </div>

          <!-- Instapay QR Code (if locked/ordered/closed and collector has Instapay link or QR code) -->
          <div v-if="currentOrder?.status !== 'OPEN' && (currentOrder?.collector_instapay_link || currentOrder?.collector_instapay_qr_code_url)" class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold mb-4 dark:text-white">Pay via Instapay</h2>
            <p class="text-sm text-gray-600 dark:text-gray-400 mb-4">Scan the QR code below to pay {{ currentOrder?.collector_name }} via Instapay</p>
            <div class="flex flex-col items-center">
              <!-- Show uploaded QR code image if available, otherwise generate from link -->
              <img
                v-if="currentOrder?.collector_instapay_qr_code_url"
                :src="currentOrder.collector_instapay_qr_code_url"
                alt="Instapay QR Code"
                class="border border-gray-300 dark:border-gray-600 rounded mb-4 max-w-xs"
              />
              <canvas
                v-else-if="currentOrder?.collector_instapay_link"
                ref="instapayQrCanvas"
                class="border border-gray-300 dark:border-gray-600 rounded mb-4"
              ></canvas>
              <a
                v-if="currentOrder?.collector_instapay_link"
                :href="currentOrder.collector_instapay_link"
                target="_blank"
                class="text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 underline text-sm"
              >
                {{ currentOrder.collector_instapay_link }}
              </a>
              <button
                v-if="currentOrder?.collector_instapay_link"
                @click="copyCollectorInstapayLink"
                class="mt-2 px-4 py-2 bg-blue-600 dark:bg-blue-500 text-white rounded-md hover:bg-blue-700 dark:hover:bg-blue-600 text-sm"
              >
                Copy Link
              </button>
            </div>
          </div>
          
          <!-- Receipt View (if ordered) -->
          <div v-if="currentOrder?.status === 'ORDERED' || currentOrder?.status === 'CLOSED'" class="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <h2 class="text-xl font-semibold mb-4 dark:text-white">Order Receipt</h2>
            <div class="space-y-2 text-sm">
              <div class="flex justify-between border-b dark:border-gray-700 pb-2 dark:text-gray-300">
                <span class="font-medium">Restaurant:</span>
                <span>{{ currentOrder?.restaurant_name }}</span>
              </div>
              <div class="flex justify-between border-b dark:border-gray-700 pb-2 dark:text-gray-300">
                <span class="font-medium">Order Code:</span>
                <span class="font-mono">{{ currentOrder?.code }}</span>
              </div>
              <div class="flex justify-between border-b dark:border-gray-700 pb-2 dark:text-gray-300">
                <span class="font-medium">Items Total:</span>
                <span>{{ formatPrice(currentOrder?.total_items_cost) }} EGP</span>
              </div>
              <div class="flex justify-between border-b dark:border-gray-700 pb-2 dark:text-gray-300">
                <span class="font-medium">Delivery:</span>
                <span>{{ formatPrice(currentOrder?.delivery_fee) }} EGP</span>
              </div>
              <div class="flex justify-between border-b dark:border-gray-700 pb-2 dark:text-gray-300">
                <span class="font-medium">Tip:</span>
                <span>{{ formatPrice(currentOrder?.tip) }} EGP</span>
              </div>
              <div class="flex justify-between border-b dark:border-gray-700 pb-2 dark:text-gray-300">
                <span class="font-medium">Service Fee:</span>
                <span>{{ formatPrice(currentOrder?.service_fee) }} EGP</span>
              </div>
              <div class="flex justify-between pt-2 font-bold text-lg dark:text-white">
                <span>Total:</span>
                <span>{{ formatPrice(currentOrder?.total_cost) }} EGP</span>
              </div>
            </div>
            <button
              @click="copyReceipt"
              class="mt-4 w-full bg-gray-600 dark:bg-gray-500 text-white px-4 py-2 rounded-md hover:bg-gray-700 dark:hover:bg-gray-600"
            >
              Copy Receipt to Share
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Add to Menu Prompt Modal -->
    <div
      v-if="showAddToMenuPrompt"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      @click="dismissAddToMenuPrompt"
    >
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-md w-full mx-4" @click.stop>
        <h2 class="text-xl font-semibold mb-4 dark:text-white">Add Item to Menu?</h2>
        <p class="text-gray-600 dark:text-gray-400 mb-4">
          Would you like to add "<strong class="dark:text-white">{{ promptItemName }}</strong>" to the menu permanently?
        </p>
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Select Menu</label>
          <select
            v-model="selectedMenuForPrompt"
            class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md dark:bg-gray-700 dark:text-white"
          >
            <option v-for="menu in availableMenus" :key="menu.id" :value="menu.id">
              {{ menu.name }}
            </option>
          </select>
        </div>
        <div class="flex space-x-2">
          <button
            @click="handleAddToMenu"
            class="flex-1 bg-blue-600 dark:bg-blue-500 text-white px-4 py-2 rounded-md hover:bg-blue-700 dark:hover:bg-blue-600"
          >
            Yes, Add to Menu
          </button>
          <button
            @click="dismissAddToMenuPrompt"
            class="flex-1 bg-gray-300 dark:bg-gray-600 text-gray-800 dark:text-white px-4 py-2 rounded-md hover:bg-gray-400 dark:hover:bg-gray-500"
          >
            No, Keep as Custom
          </button>
        </div>
      </div>
    </div>

    <!-- Update Price Prompt Modal -->
    <div
      v-if="showUpdatePricePrompt"
      class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
      @click="dismissUpdatePricePrompt"
    >
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-md w-full mx-4" @click.stop>
        <h2 class="text-xl font-semibold mb-4 dark:text-white">Update Menu Item Price?</h2>
        <p class="text-gray-600 dark:text-gray-400 mb-4">
          The price for "<strong class="dark:text-white">{{ promptItemName }}</strong>" is different from the menu price.
          Would you like to update the menu item price to <strong class="dark:text-white">{{ formatPrice(promptItemPrice) }} EGP</strong>?
        </p>
        <div class="flex space-x-2">
          <button
            @click="handleUpdatePrice"
            class="flex-1 bg-blue-600 dark:bg-blue-500 text-white px-4 py-2 rounded-md hover:bg-blue-700 dark:hover:bg-blue-600"
          >
            Yes, Update Price
          </button>
          <button
            @click="dismissUpdatePricePrompt"
            class="flex-1 bg-gray-300 dark:bg-gray-600 text-gray-800 dark:text-white px-4 py-2 rounded-md hover:bg-gray-400 dark:hover:bg-gray-500"
          >
            No, Keep Current Price
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed, watch, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useOrdersStore } from '../stores/orders'
import { useAuthStore } from '../stores/auth'
import api from '../api'
import QRCode from 'qrcode'

const route = useRoute()
const router = useRouter()
const ordersStore = useOrdersStore()
const authStore = useAuthStore()

const loading = ref(true)
const error = ref(null)
const selectedMenuItem = ref('')
const itemQuantity = ref(1)
const customItemName = ref('')
const customItemPrice = ref(0)
const selectedItemUser = ref(null) // User to assign the item to (null = current user)
const instapayQrCanvas = ref(null)
const transferCollectorId = ref('')
const showAssignUsers = ref(false)
const selectedUsers = ref([])
const allUsers = ref([])
const loadingUsers = ref(false)
const assignmentItems = ref(null)
const assignmentTotalCost = ref(null)
const fees = ref({
  delivery_fee: 0,
  tip: 0,
  service_fee: 0,
  fee_split_rule: 'equal',
  instapay_link: '',
})
// Prompt states
const showAddToMenuPrompt = ref(false)
const showUpdatePricePrompt = ref(false)
const promptItemId = ref(null)
const promptItemName = ref('')
const promptItemPrice = ref(0)
const promptExistingMenuItemId = ref(null)
const availableMenus = ref([])
const selectedMenuForPrompt = ref(null)

// Helper to get order from either computed or store directly
const order = computed(() => {
  const current = ordersStore.currentOrder
  if (current) {
    console.log('Computed order exists:', !!current, 'Keys:', Object.keys(current))
  } else {
    console.log('Computed order is null')
  }
  return current
})

// Always use this to get the order - it falls back to store if computed is null
const currentOrder = computed(() => {
  return order.value || ordersStore.currentOrder
})

const availableMenuItems = computed(() => {
  return ordersStore.menuItems.filter(item => item.is_available)
})

// Helper function to format prices safely
function formatPrice(value) {
  if (value === null || value === undefined) return '0.00'
  const num = typeof value === 'string' ? parseFloat(value) : value
  return isNaN(num) ? '0.00' : num.toFixed(2)
}

// Helper function to format cutoff time in GMT+2
function formatCutoffTime(dateString) {
  if (!dateString) return 'N/A'
  const date = new Date(dateString)
  // Convert UTC to GMT+2 (Egypt timezone)
  const gmt2Date = new Date(date.getTime() + (2 * 60 * 60 * 1000))
  return gmt2Date.toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true,
    timeZone: 'Africa/Cairo'
  })
}

async function loadOrder() {
  loading.value = true
  error.value = null
  const code = route.params.code.toUpperCase()
  
  try {
    console.log('Loading order with code:', code)
    const result = await ordersStore.fetchOrderByCode(code)
    console.log('Fetch result:', result)
    
    if (!result.success) {
      error.value = result.error?.detail || result.error?.error || 'Order not found'
      console.error('Failed to fetch order:', result.error)
      loading.value = false
      return
    }
    
    if (!ordersStore.currentOrder) {
      error.value = 'Order not found'
      loading.value = false
      return
    }
    
    console.log('Order loaded:', ordersStore.currentOrder)
    console.log('Order keys:', ordersStore.currentOrder ? Object.keys(ordersStore.currentOrder) : 'null')
    console.log('Order restaurant_name:', ordersStore.currentOrder?.restaurant_name)
    
    // Verify order is set
    if (!ordersStore.currentOrder) {
      console.error('Order data not set in store after successful fetch')
      error.value = 'Order data not set in store'
      loading.value = false
      return
    }
    
    // Force reactivity update
    await new Promise(resolve => setTimeout(resolve, 0))
    console.log('After microtask - Order still exists:', !!ordersStore.currentOrder)
    
    // Fetch menu items for the order's menu
    try {
      // If order has a menu assigned, fetch items from that menu
      if (ordersStore.currentOrder.menu) {
        console.log('Order has menu:', ordersStore.currentOrder.menu)
        await ordersStore.fetchMenuItems(ordersStore.currentOrder.menu)
        console.log('Menu items loaded:', ordersStore.menuItems)
      } else {
        // Fallback: fetch menus for the restaurant and use the first one
        await ordersStore.fetchMenus(ordersStore.currentOrder.restaurant)
        console.log('Menus loaded:', ordersStore.menus)
        
        if (ordersStore.menus.length > 0) {
          await ordersStore.fetchMenuItems(ordersStore.menus[0].id)
          console.log('Menu items loaded from first menu:', ordersStore.menuItems)
        } else {
          console.warn('No menus found for restaurant')
          ordersStore.menuItems = []
        }
      }
    } catch (menuError) {
      console.warn('Failed to load menus:', menuError)
      // Don't fail the whole page if menus fail to load
      ordersStore.menuItems = []
    }
    
    // Payments are already included in order.payments from the API
    
    // Set fees - ensure they're numbers
    if (ordersStore.currentOrder) {
      fees.value = {
        delivery_fee: parseFloat(ordersStore.currentOrder.delivery_fee) || 0,
        tip: parseFloat(ordersStore.currentOrder.tip) || 0,
        service_fee: parseFloat(ordersStore.currentOrder.service_fee) || 0,
        fee_split_rule: ordersStore.currentOrder.fee_split_rule || 'equal',
        instapay_link: ordersStore.currentOrder.instapay_link || '',
      }
      console.log('Fees set:', fees.value)
    }
    
    // Generate QR code for collector's Instapay link
    await nextTick()
    generateInstapayQR()
    
    // Load users for assignment (any user can assign) and for item assignment
    if (ordersStore.currentOrder) {
      await loadUsers()
      // Set current assigned users
      if (ordersStore.currentOrder.assigned_users_details) {
        selectedUsers.value = ordersStore.currentOrder.assigned_users_details.map(u => u.id)
      }
    }
  } catch (err) {
    console.error('Failed to load order:', err)
    error.value = 'Failed to load order: ' + (err.message || 'Unknown error')
  } finally {
    loading.value = false
  }
}

async function generateInstapayQR() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (order?.collector_instapay_link && instapayQrCanvas.value) {
    try {
      await QRCode.toCanvas(instapayQrCanvas.value, order.collector_instapay_link, {
        width: 250,
        margin: 2,
      })
    } catch (error) {
      console.error('Failed to generate QR code:', error)
    }
  }
}

function copyCollectorInstapayLink() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (order?.collector_instapay_link) {
    navigator.clipboard.writeText(order.collector_instapay_link)
    alert('Instapay link copied to clipboard!')
  }
}

let isLoading = false

onMounted(() => {
  if (!isLoading) {
    isLoading = true
    loadOrder().finally(() => {
      isLoading = false
    })
  }
})

// Watch for route changes (e.g., when code changes) - but only if not already loading
watch(() => route.params.code, (newCode, oldCode) => {
  if (newCode !== oldCode && !isLoading) {
    isLoading = true
    loadOrder().finally(() => {
      isLoading = false
    })
  }
})

// Watch for collector_instapay_link changes to regenerate QR code
watch(() => currentOrder.value?.collector_instapay_link, () => {
  nextTick(() => {
    generateInstapayQR()
  })
})

async function addMenuItem() {
  if (!selectedMenuItem.value || !itemQuantity.value) {
    alert('Please select an item and quantity')
    return
  }
  
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    alert('Order not loaded')
    return
  }
  
  if (order.status !== 'OPEN') {
    alert('This order is locked and cannot be modified')
    return
  }

  // Check if user is trying to assign to someone else but doesn't have permission
  if (selectedItemUser.value && order.collector !== authStore.user?.id && !authStore.isManager) {
    alert('Only collectors and managers can assign items to other users')
    return
  }

  const wasLoading = loading.value
  loading.value = true
  try {
    const itemData = {
      order: order.id,
      menu_item: selectedMenuItem.value,
      quantity: itemQuantity.value,
    }

    // Add user if specified and user has permission
    if (selectedItemUser.value && (order.collector === authStore.user?.id || authStore.isManager)) {
      itemData.user = selectedItemUser.value
    }

    const result = await ordersStore.addOrderItem(itemData)
    
    if (result.success) {
      selectedMenuItem.value = ''
      itemQuantity.value = 1
      selectedItemUser.value = null // Reset to default (current user)
      await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
      // Regenerate QR code if needed
      await nextTick()
      generateInstapayQR()
    } else {
      const errorMsg = result.error?.detail || result.error?.error || JSON.stringify(result.error)
      alert('Failed to add item: ' + errorMsg)
    }
  } finally {
    loading.value = wasLoading
  }
}

async function addCustomItem() {
  if (!customItemName.value || !customItemPrice.value) {
    alert('Please enter item name and price')
    return
  }
  
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    alert('Order not loaded')
    return
  }
  
  if (order.status !== 'OPEN') {
    alert('This order is locked and cannot be modified')
    return
  }

  // Check if user is trying to assign to someone else but doesn't have permission
  if (selectedItemUser.value && order.collector !== authStore.user?.id && !authStore.isManager) {
    alert('Only collectors and managers can assign items to other users')
    return
  }

  const wasLoading = loading.value
  loading.value = true
  try {
    const itemData = {
      order: order.id,
      custom_name: customItemName.value,
      custom_price: customItemPrice.value,
      quantity: 1,
    }

    // Add user if specified and user has permission
    if (selectedItemUser.value && (order.collector === authStore.user?.id || authStore.isManager)) {
      itemData.user = selectedItemUser.value
    }

    const result = await ordersStore.addOrderItem(itemData)
    
    if (result.success) {
      const itemData = result.data
      
      // Check for prompts
      if (itemData.suggest_add_to_menu) {
        // Load menus for the restaurant
        await loadMenusForRestaurant(order.restaurant)
        promptItemId.value = itemData.id
        promptItemName.value = itemData.custom_name || itemData.item_name
        promptItemPrice.value = itemData.custom_price || itemData.unit_price
        showAddToMenuPrompt.value = true
      } else if (itemData.suggest_update_price) {
        promptItemId.value = itemData.id
        promptItemName.value = itemData.item_name
        promptItemPrice.value = itemData.custom_price || itemData.unit_price
        promptExistingMenuItemId.value = itemData.existing_menu_item_id
        showUpdatePricePrompt.value = true
      } else {
        // No prompts, just reset and refresh
        customItemName.value = ''
        customItemPrice.value = 0
        selectedItemUser.value = null
        await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
        await nextTick()
        generateInstapayQR()
      }
    } else {
      const errorMsg = result.error?.detail || result.error?.error || JSON.stringify(result.error)
      alert('Failed to add custom item: ' + errorMsg)
    }
  } finally {
    loading.value = wasLoading
  }
}

async function loadMenusForRestaurant(restaurantId) {
  try {
    const result = await ordersStore.fetchMenus(restaurantId)
    if (result.success) {
      availableMenus.value = result.data || []
      // Pre-select order's menu if available
      const order = currentOrder.value || ordersStore.currentOrder
      if (order?.menu) {
        selectedMenuForPrompt.value = order.menu
      } else if (availableMenus.value.length > 0) {
        selectedMenuForPrompt.value = availableMenus.value[0].id
      }
    }
  } catch (error) {
    console.error('Failed to load menus:', error)
  }
}

async function handleAddToMenu() {
  if (!promptItemId.value) return
  
  const wasLoading = loading.value
  loading.value = true
  try {
    const result = await ordersStore.addItemToMenu(promptItemId.value, selectedMenuForPrompt.value)
    
    if (result.success) {
      showAddToMenuPrompt.value = false
      customItemName.value = ''
      customItemPrice.value = 0
      selectedItemUser.value = null
      await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
      await nextTick()
      generateInstapayQR()
      alert('Item added to menu successfully!')
    } else {
      const errorMsg = result.error?.detail || result.error?.error || JSON.stringify(result.error)
      alert('Failed to add item to menu: ' + errorMsg)
    }
  } finally {
    loading.value = wasLoading
  }
}

async function handleUpdatePrice() {
  if (!promptItemId.value || !promptItemPrice.value) return
  
  const wasLoading = loading.value
  loading.value = true
  try {
    const result = await ordersStore.updateMenuItemPrice(promptItemId.value, promptItemPrice.value)
    
    if (result.success) {
      showUpdatePricePrompt.value = false
      await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
      await nextTick()
      generateInstapayQR()
      alert('Menu item price updated successfully!')
    } else {
      const errorMsg = result.error?.detail || result.error?.error || JSON.stringify(result.error)
      alert('Failed to update price: ' + errorMsg)
    }
  } finally {
    loading.value = wasLoading
  }
}

function dismissAddToMenuPrompt() {
  showAddToMenuPrompt.value = false
  customItemName.value = ''
  customItemPrice.value = 0
  selectedItemUser.value = null
  ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
  nextTick().then(() => generateInstapayQR())
}

function dismissUpdatePricePrompt() {
  showUpdatePricePrompt.value = false
  ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
  nextTick().then(() => generateInstapayQR())
}

async function removeItem(itemId) {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    alert('Order not loaded')
    return
  }
  
  if (order.status !== 'OPEN') {
    alert('This order is locked and cannot be modified')
    return
  }
  
  if (!confirm('Remove this item?')) return
  
  loading.value = true
  const result = await ordersStore.removeOrderItem(itemId)
  
  if (result.success) {
    await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
  } else {
    alert('Failed to remove item')
  }
  loading.value = false
}

async function updateFees() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    alert('Order not loaded')
    return
  }
  
  if (order.status !== 'OPEN') {
    alert('Fees can only be updated when order is open')
    return
  }
  
  loading.value = true
  try {
    await api.patch(`/orders/${order.id}/`, fees.value)
    await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
    alert('Fees updated successfully')
  } catch (error) {
    alert('Failed to update fees: ' + (error.response?.data?.detail || error.message))
  }
  loading.value = false
}

async function lockOrder() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    alert('Order not loaded')
    return
  }
  
  if (!confirm('Lock this order? Users won\'t be able to add or remove items.')) return
  
  loading.value = true
  const result = await ordersStore.lockOrder(order.id)
  if (result.success) {
    await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
    alert('Order locked successfully')
  } else {
    alert('Failed to lock order: ' + (result.error?.detail || JSON.stringify(result.error)))
  }
  loading.value = false
}

async function markOrdered() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    alert('Order not loaded')
    return
  }
  
  if (!confirm('Mark this order as ordered with the restaurant?')) return
  
  loading.value = true
  const result = await ordersStore.markOrdered(order.id)
  if (result.success) {
    await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
    alert('Order marked as ordered')
  } else {
    alert('Failed to mark as ordered: ' + (result.error?.detail || JSON.stringify(result.error)))
  }
  loading.value = false
}

async function closeOrder() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    alert('Order not loaded')
    return
  }
  
  if (!confirm('Close this order? This action cannot be undone.')) return
  
  loading.value = true
  const result = await ordersStore.closeOrder(order.id)
  if (result.success) {
    alert('Order closed successfully')
    router.push('/orders')
  } else {
    alert('Failed to close order: ' + (result.error?.detail || JSON.stringify(result.error)))
    loading.value = false
  }
}

async function unlockOrder() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    alert('Order not loaded')
    return
  }

  if (!confirm('Unlock this order? Users will be able to add or remove items again. Payments will be cleared and recalculated on next lock.')) return

  loading.value = true
  const result = await ordersStore.unlockOrder(order.id)
  if (result.success) {
    await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
    alert('Order unlocked successfully')
  } else {
    alert('Failed to unlock order: ' + (result.error?.detail || JSON.stringify(result.error)))
  }
  loading.value = false
}

async function deleteOrder() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    alert('Order not loaded')
    return
  }
  
  // Managers can delete any order, collectors can only delete OPEN orders
  if (order.status !== 'OPEN' && !authStore.isManager) {
    alert('Can only delete open orders')
    return
  }
  
  const statusText = order.status !== 'OPEN' ? ` (Status: ${order.status})` : ''
  if (!confirm(`Are you sure you want to delete this order${statusText}? This action cannot be undone.`)) return
  
  loading.value = true
  const result = await ordersStore.deleteOrder(order.id)
  if (result.success) {
    alert('Order deleted successfully')
    router.push('/orders')
  } else {
    alert('Failed to delete order: ' + (result.error?.error || result.error?.detail || JSON.stringify(result.error)))
    loading.value = false
  }
}

async function copyShareMessage() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order || !order.share_message) {
    alert('Share message not available')
    return
  }
  try {
    await navigator.clipboard.writeText(order.share_message)
    alert('Share message copied to clipboard!')
  } catch (error) {
    // Fallback for older browsers
    const textArea = document.createElement('textarea')
    textArea.value = order.share_message
    textArea.style.position = 'fixed'
    textArea.style.opacity = '0'
    document.body.appendChild(textArea)
    textArea.select()
    try {
      document.execCommand('copy')
      alert('Share message copied to clipboard!')
    } catch (err) {
      alert('Failed to copy message. Please select and copy manually.')
    }
    document.body.removeChild(textArea)
  }
}

async function markPaymentPaid(paymentId) {
  if (!confirm('Mark this payment as paid?')) return
  
  loading.value = true
  try {
    const response = await api.post(`/payments/${paymentId}/mark_paid/`)
    await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
    alert('Payment marked as paid!')
  } catch (error) {
    alert('Failed to mark payment as paid')
  }
  loading.value = false
}

async function loadUsers() {
  loadingUsers.value = true
  const usersResult = await ordersStore.fetchUsers()
  if (usersResult.success) {
    allUsers.value = usersResult.data
  }
  loadingUsers.value = false
}

async function ensureUsersLoaded() {
  if (allUsers.value.length === 0) {
    await loadUsers()
  }
}

function toggleAssignUsers() {
  showAssignUsers.value = !showAssignUsers.value
  if (showAssignUsers.value && allUsers.value.length === 0) {
    loadUsers()
  }
  // Set current assigned users when opening
  if (showAssignUsers.value && currentOrder.value?.assigned_users_details) {
    selectedUsers.value = currentOrder.value.assigned_users_details.map(u => u.id)
  }
  // Reset assignment fields
  if (!showAssignUsers.value) {
    assignmentItems.value = null
    assignmentTotalCost.value = null
  }
}

function selectAllUsers() {
  selectedUsers.value = allUsers.value.map(user => user.id)
}

function deselectAllUsers() {
  selectedUsers.value = []
}

async function updateAssignedUsers() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    alert('Order not loaded')
    return
  }
  
  if (order.status !== 'OPEN') {
    alert('Can only update assigned users for open orders')
    return
  }
  
  if (selectedUsers.value.length === 0) {
    alert('Please select at least one user')
    return
  }
  
  // Validate: if items or cost is provided, both must be provided
  if ((assignmentItems.value && !assignmentTotalCost.value) || (assignmentTotalCost.value && !assignmentItems.value)) {
    alert('Please provide both number of items and total cost, or leave both empty')
    return
  }
  
  loading.value = true
  try {
    const updateData = {
      assigned_users: selectedUsers.value
    }
    
    // If items and total cost are provided, include them for backend to create items
    if (assignmentItems.value && assignmentTotalCost.value) {
      updateData.assignment_items = assignmentItems.value
      updateData.assignment_total_cost = assignmentTotalCost.value
    }
    
    await api.patch(`/orders/${order.id}/`, updateData)
    
    // Reset assignment fields before reloading
    const hadItems = assignmentItems.value && assignmentTotalCost.value
    assignmentItems.value = null
    assignmentTotalCost.value = null
    
    await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
    
    alert('Assigned users updated successfully' + (hadItems ? '. Items have been created and split evenly.' : ''))
    showAssignUsers.value = false
  } catch (error) {
    alert('Failed to update assigned users: ' + (error.response?.data?.error || error.response?.data?.detail || error.message))
  }
  loading.value = false
}

async function transferCollector() {
  if (!transferCollectorId.value) {
    alert('Please select a new collector')
    return
  }
  
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    alert('Order not loaded')
    return
  }
  
  if (!confirm(`Transfer collector role to the selected participant?`)) return
  
  loading.value = true
  try {
    await api.post(`/orders/${order.id}/transfer_collector/`, {
      new_collector_id: transferCollectorId.value
    })
    await ordersStore.fetchOrderByCode(route.params.code.toUpperCase())
    transferCollectorId.value = ''
    alert('Collector role transferred successfully')
  } catch (error) {
    alert('Failed to transfer collector: ' + (error.response?.data?.error || error.message))
  }
  loading.value = false
}

function openInstapay() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    alert('Order not loaded')
    return
  }
  
  if (order.instapay_link) {
    window.open(order.instapay_link, '_blank')
  } else {
    alert('Instapay link not set by collector')
  }
}

function copyInstapayLink() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    alert('Order not loaded')
    return
  }
  
  if (order.instapay_link) {
    navigator.clipboard.writeText(order.instapay_link)
    alert('Instapay link copied to clipboard!')
  }
}

async function copyReceipt() {
  const order = currentOrder.value || ordersStore.currentOrder
  if (!order) {
    alert('Order not loaded')
    return
  }
  
  const receipt = `📋 Order Receipt - ${order.restaurant_name}
Order Code: ${order.code}
Collector: ${order.collector_name}

Items Total: ${formatPrice(order.total_items_cost)} EGP
Delivery: ${formatPrice(order.delivery_fee)} EGP
Tip: ${formatPrice(order.tip)} EGP
Service Fee: ${formatPrice(order.service_fee)} EGP
━━━━━━━━━━━━━━━━━━━━
Total: ${formatPrice(order.total_cost)} EGP

Payment Breakdown:
${(order.payments || []).map(p => `  ${p.user_name}: ${formatPrice(p.amount)} EGP ${p.is_paid ? '✅' : '⏳'}`).join('\n')}

${order.instapay_link ? `Pay via Instapay: ${order.instapay_link}` : ''}`
  
  try {
    await navigator.clipboard.writeText(receipt)
    alert('Receipt copied to clipboard! Share it in the group.')
  } catch (error) {
    // Fallback for older browsers
    const textArea = document.createElement('textarea')
    textArea.value = receipt
    textArea.style.position = 'fixed'
    textArea.style.opacity = '0'
    document.body.appendChild(textArea)
    textArea.select()
    try {
      document.execCommand('copy')
      alert('Receipt copied to clipboard! Share it in the group.')
    } catch (err) {
      alert('Failed to copy receipt. Please select and copy manually.')
    }
    document.body.removeChild(textArea)
  }
}
</script>

