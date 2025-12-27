import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/login',
      name: 'Login',
      component: () => import('../views/LoginView.vue'),
      meta: { requiresAuth: false },
    },
    {
      path: '/register',
      name: 'Register',
      component: () => import('../views/RegisterView.vue'),
      meta: { requiresAuth: true, requiresAdmin: true },
    },
    {
      path: '/',
      name: 'Home',
      component: () => import('../views/HomeView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/orders',
      name: 'Orders',
      component: () => import('../views/OrdersView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/orders/:code',
      name: 'OrderDetail',
      component: () => import('../views/OrderDetailView.vue'),
      meta: { requiresAuth: true },
      beforeEnter: (to, from, next) => {
        // Ensure code is uppercase
        if (to.params.code !== to.params.code.toUpperCase()) {
          next({ ...to, params: { ...to.params, code: to.params.code.toUpperCase() } })
        } else {
          next()
        }
      },
    },
    {
      path: '/join/:code',
      name: 'JoinOrder',
      component: () => import('../views/JoinOrderView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/restaurants',
      name: 'Restaurants',
      component: () => import('../views/RestaurantsView.vue'),
      meta: { requiresAuth: true, requiresManager: true },
    },
    {
      path: '/restaurants/:restaurantId/menus',
      name: 'MenuManagement',
      component: () => import('../views/MenuManagementView.vue'),
      meta: { requiresAuth: true, requiresManager: true },
    },
    {
      path: '/reports',
      name: 'Reports',
      component: () => import('../views/ReportsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/profile',
      name: 'Profile',
      component: () => import('../views/ProfileView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/pending-payments',
      name: 'PendingPayments',
      component: () => import('../views/PendingPaymentsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/recommendations',
      name: 'Recommendations',
      component: () => import('../views/RecommendationsView.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/users',
      name: 'UserManagement',
      component: () => import('../views/UserManagementView.vue'),
      meta: { requiresAuth: true, requiresAdmin: true },
    },
  ],
})

router.beforeEach((to, from, next) => {
  const authStore = useAuthStore()
  
  if (to.meta.requiresAuth && !authStore.isAuthenticated) {
    next('/login')
  } else if (to.meta.requiresManager && !authStore.isManager && !authStore.isAdmin) {
    next('/')
  } else if (to.meta.requiresAdmin && !authStore.isAdmin) {
    next('/')
  } else if (to.path === '/login' && authStore.isAuthenticated) {
    next('/')
  } else {
    next()
  }
})

export default router

