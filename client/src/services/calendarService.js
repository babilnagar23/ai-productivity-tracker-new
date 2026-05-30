import { api } from './api';

// ─── OAuth ─────────────────────────────────────────────────────────────────
export const getCalendarStatus = () => api.get('/calendar/status').then(r => r.data);
export const getCalendarAuthUrl = () => api.get('/calendar/auth-url').then(r => r.data);
export const submitCalendarCallback = (code) => api.post('/calendar/callback', { code }).then(r => r.data);
export const disconnectCalendar = () => api.post('/calendar/disconnect').then(r => r.data);

// ─── Sync ──────────────────────────────────────────────────────────────────
export const syncRoutinesToGoogle = () => api.post('/calendar/sync').then(r => r.data);
export const fetchFromGoogle = () => api.post('/calendar/fetch-google').then(r => r.data);
export const getSyncLogs = () => api.get('/calendar/sync-logs').then(r => r.data);

// ─── Events CRUD ───────────────────────────────────────────────────────────
export const getEvents = (start, end) =>
  api.get('/calendar/events', { params: { start, end } }).then(r => r.data);

export const createEvent = (eventData) =>
  api.post('/calendar/events', eventData).then(r => r.data);

export const updateEvent = (id, eventData) =>
  api.put(`/calendar/events/${id}`, eventData).then(r => r.data);

export const deleteEvent = (id) =>
  api.delete(`/calendar/events/${id}`).then(r => r.data);

// ─── AI Scheduler ─────────────────────────────────────────────────────────
export const generateAISchedule = (prompt) =>
  api.post('/calendar/ai-schedule', { prompt }).then(r => r.data);

export const applyAISchedule = (scheduleId, syncToGoogle = false) =>
  api.post(`/calendar/ai-schedule/${scheduleId}/apply`, { syncToGoogle }).then(r => r.data);

// ─── AI Insights ──────────────────────────────────────────────────────────
export const getInsights = () => api.get('/calendar/insights').then(r => r.data);
export const generateInsights = () => api.post('/calendar/insights').then(r => r.data);

// ─── Heatmap Analytics ────────────────────────────────────────────────────
export const getHeatmap = (days = 30) =>
  api.get('/calendar/heatmap', { params: { days } }).then(r => r.data);

// ─── Reminders ────────────────────────────────────────────────────────────
export const createReminder = (reminderData) =>
  api.post('/calendar/reminders', reminderData).then(r => r.data);

// ─── Notification Settings ────────────────────────────────────────────────
export const getNotificationSettings = () =>
  api.get('/calendar/notification-settings').then(r => r.data);

export const saveNotificationSettings = (settings) =>
  api.post('/calendar/notification-settings', settings).then(r => r.data);

// ─── Helpers ──────────────────────────────────────────────────────────────
export const COLOR_PALETTE = {
  blue:   { hex: '#3B82F6', glow: 'rgba(59,130,246,0.4)',   label: 'Ocean Blue' },
  purple: { hex: '#8B5CF6', glow: 'rgba(139,92,246,0.4)',   label: 'Neural Purple' },
  green:  { hex: '#10B981', glow: 'rgba(16,185,129,0.4)',   label: 'Matrix Green' },
  pink:   { hex: '#EC4899', glow: 'rgba(236,72,153,0.4)',   label: 'Neon Pink' },
  orange: { hex: '#F59E0B', glow: 'rgba(245,158,11,0.4)',   label: 'Solar Orange' },
  cyan:   { hex: '#06B6D4', glow: 'rgba(6,182,212,0.4)',    label: 'Cyber Cyan' },
  red:    { hex: '#EF4444', glow: 'rgba(239,68,68,0.4)',    label: 'Alert Red' },
};

export const CATEGORY_ICONS = {
  study:        '📚',
  work:         '💼',
  exercise:     '🏃',
  personal:     '✨',
  meeting:      '🤝',
  break:        '☕',
  ai_generated: '🤖',
};

export const formatDuration = (start, end) => {
  const diff = (new Date(end) - new Date(start)) / 60000;
  const h = Math.floor(diff / 60);
  const m = diff % 60;
  return h > 0 ? `${h}h ${m > 0 ? m + 'm' : ''}`.trim() : `${m}m`;
};
