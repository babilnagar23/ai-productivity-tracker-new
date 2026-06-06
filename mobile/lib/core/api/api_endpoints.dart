class ApiEndpoints {
  // ── Auth ───────────────────────────────────────────────────────────────────
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
}
