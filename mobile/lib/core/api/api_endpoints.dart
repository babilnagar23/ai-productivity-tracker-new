class ApiEndpoints {
  // ── Auth ───────────────────────────────────────────────────────────────────
  static const checkEmail = '/auth/check-email';
  static const register = '/auth/register';
  static const sendOtp = '/auth/send-otp';
  static const verifyOtp = '/auth/verify-otp';
  static const completeRegistration = '/auth/complete-registration';
  static const login = '/auth/login';
  static const me = '/auth/me';
  static const updateProfile = '/auth/me';
  static const tokenRefresh = '/auth/token/refresh';
  static const forgotPassword = '/auth/forgot-password';
  static const resetPassword = '/auth/reset-password';
  static const customConfig = '/auth/custom-config';

  // ── Routines ───────────────────────────────────────────────────────────────
  static const routines = '/routines';
  static String routineDetail(int id) => '/routines/$id';

  // ── Analytics ─────────────────────────────────────────────────────────────
  static const analyticsWeekly = '/analytics/weekly';
  static const analyticsFull = '/analytics/full';
  static const analyticsExport = '/analytics/export';

  // ── AI ─────────────────────────────────────────────────────────────────────
  static const aiChat = '/ai/chat';
  static const aiGeneratePlan = '/ai/generate-plan';
  static const aiAnalyze = '/ai/analyze';
  static String aiJobDetail(int jobId) => '/ai/jobs/$jobId/';

  // ── Calendar ───────────────────────────────────────────────────────────────
  static const calendarStatus = '/calendar/status';
  static const calendarEvents = '/calendar/events';
  static String calendarEventDetail(int id) => '/calendar/events/$id';
  static const calendarAuthUrl = '/calendar/auth-url';
  static const calendarCallback = '/calendar/callback';
  static const calendarSync = '/calendar/sync';
  static const calendarInsights = '/calendar/insights';
  static const calendarHeatmap = '/calendar/heatmap';
  static const calendarNotificationSettings = '/calendar/notification-settings';

  static const todos = '/todos/';
  static String todoDetail(int id) =>
    '/todos/$id/';

  // ── Focus & Notifications ──────────────────────────────────────────────────
  static const focusSessions = '/focus-sessions/';
  static String focusSessionDetail(int id) => '/focus-sessions/$id/';
  
  static const notifications = '/notifications/';
  static String notificationDetail(int id) => '/notifications/$id/';
}
