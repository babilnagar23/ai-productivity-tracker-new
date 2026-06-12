import axios from 'axios';

const getApiUrl = () => {
  if (import.meta.env.VITE_API_URL) return import.meta.env.VITE_API_URL;
  return window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
    ? 'http://127.0.0.1:8000/api'
    : '/api';
};

export const API_URL = getApiUrl();

export const api = axios.create({
  baseURL: API_URL,
  headers: { 'Content-Type': 'application/json' },
});

// ─── Request interceptor: attach JWT ──────────────────────────────
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// ─── Response interceptor: auto-refresh JWT ───────────────────────
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config;
    const refreshToken = localStorage.getItem('refreshToken');

    if (error.response?.status === 401 && refreshToken && !originalRequest._retry) {
      originalRequest._retry = true;
      try {
        const { data } = await axios.post(`${API_URL}/auth/token/refresh`, { refresh: refreshToken });
        localStorage.setItem('token', data.access);
        originalRequest.headers.Authorization = `Bearer ${data.access}`;
        return api(originalRequest);
      } catch {
        localStorage.removeItem('token');
        localStorage.removeItem('refreshToken');
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

// ─── Generic apiFetch helper ──────────────────────────────────────
export const apiFetch = async (endpoint, options = {}) => {
  try {
    const response = await api.request({
      url: endpoint,
      method: options.method || 'GET',
      data: options.body ? JSON.parse(options.body) : options.data,
      headers: options.headers,
      params: options.params,
    });
    return response.data;
  } catch (err) {
    const data = err.response?.data || {};
    const apiError = new Error(data.error || data.detail || data.message || 'Something went wrong');
    Object.assign(apiError, data);
    throw apiError;
  }
};

// ─── Auth endpoints ───────────────────────────────────────────────
export const forgotPassword = (email) => api.post('/auth/forgot-password', { email }).then(r => r.data);
export const resetPassword = (uid, token, password) => api.post('/auth/reset-password', { uid, token, password }).then(r => r.data);
export const sendOTP = (email) => api.post('/auth/send-otp', { email }).then(r => r.data);
export const verifyOTP = (email, otp) => api.post('/auth/verify-otp', { email, otp }).then(r => r.data);
export const completeRegistration = (email, password, confirm_password) =>
  api.post('/auth/complete-registration', { email, password, confirm_password }).then(r => r.data);

// ─── Todos ────────────────────────────────────────────────────────
export const todosApi = {
  list: (params) => api.get('/todos/', { params }).then(r => r.data),
  create: (data) => api.post('/todos/', data).then(r => r.data),
  update: (id, data) => api.patch(`/todos/${id}/`, data).then(r => r.data),
  delete: (id) => api.delete(`/todos/${id}/`).then(r => r.data),
};

// ─── Routines ─────────────────────────────────────────────────────
export const routinesApi = {
  list: () => api.get('/routines').then(r => r.data),
  create: (data) => api.post('/routines', data).then(r => r.data),
  update: (id, data) => api.patch(`/routines/${id}/`, data).then(r => r.data),
};

// ─── Focus Sessions ───────────────────────────────────────────────
export const focusApi = {
  list: () => api.get('/focus-sessions/').then(r => r.data),
  create: (data) => api.post('/focus-sessions/', data).then(r => r.data),
};

// ─── Calendar ─────────────────────────────────────────────────────
export const calendarApi = {
  list: (params) => api.get('/calendar/events/', { params }).then(r => r.data),
  create: (data) => api.post('/calendar/events/', data).then(r => r.data),
  update: (id, data) => api.patch(`/calendar/events/${id}/`, data).then(r => r.data),
  delete: (id) => api.delete(`/calendar/events/${id}/`).then(r => r.data),
  status: () => api.get('/calendar/status/').then(r => r.data),
  sync: () => api.post('/calendar/sync-from-google/').then(r => r.data),
  
  // Google OAuth integration
  googleConnect: () => api.get('/calendar/google/connect/').then(r => r.data),
  googleCallback: (code) => api.post('/calendar/google/callback/', { code }).then(r => r.data),
  googleStatus: () => api.get('/calendar/google/status/').then(r => r.data),
  googleDisconnect: () => api.post('/calendar/google/disconnect/').then(r => r.data),
};

// ─── Analytics ────────────────────────────────────────────────────
export const analyticsApi = {
  full: () => api.get('/analytics/full').then(r => r.data),
  weekly: () => api.get('/analytics/weekly').then(r => r.data),
  insights: () => api.get('/analytics/insights').then(r => r.data),
};

// ─── Notifications ────────────────────────────────────────────────
export const notificationsApi = {
  list: () => api.get('/notifications/').then(r => r.data),
  markRead: (id) => api.patch(`/notifications/${id}/`, { read: true }).then(r => r.data),
  markAllRead: () => api.post('/notifications/mark-all-read/').then(r => r.data),
  delete: (id) => api.delete(`/notifications/${id}/`).then(r => r.data),
};

// ─── Achievements ─────────────────────────────────────────────────
export const achievementsApi = {
  list: () => api.get('/achievements/').then(r => r.data),
};

// ─── AI ───────────────────────────────────────────────────────────
export const aiApi = {
  analyze: () => api.post('/ai/analyze').then(r => r.data),
  chat: (message, history = []) => api.post('/ai/chat', { message, history }).then(r => r.data),
  generatePlan: () => api.post('/ai/generate-plan').then(r => r.data),
};

export default api;
