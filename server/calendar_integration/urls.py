from django.urls import path

from .views import (
    AIInsightsView,
    AIScheduleApplyView,
    AISchedulerView,
    CalendarAuthUrlView,
    CalendarCallbackView,
    CalendarDisconnectView,
    CalendarEventDetailView,
    CalendarEventsView,
    CalendarFetchGoogleView,
    CalendarStatusView,
    CalendarSyncView,
    NotificationSettingsView,
    ProductivityHeatmapView,
    ReminderView,
    SyncLogsView,
    WebhookView,
)

urlpatterns = [
    # ── OAuth ─────────────────────────────────────────────────────────────────
    path('calendar/google/status/', CalendarStatusView.as_view(), name='calendar_status'),
    path('calendar/google/connect/', CalendarAuthUrlView.as_view(), name='calendar_auth_url'),
    path('calendar/google/callback/', CalendarCallbackView.as_view(), name='calendar_callback'),
    path('calendar/google/disconnect/', CalendarDisconnectView.as_view(), name='calendar_disconnect'),
    
    # Keep old paths for backward compatibility just in case
    path('calendar/status', CalendarStatusView.as_view()),
    path('calendar/auth-url', CalendarAuthUrlView.as_view()),
    path('calendar/callback', CalendarCallbackView.as_view()),
    path('calendar/disconnect', CalendarDisconnectView.as_view()),

    # ── Sync ──────────────────────────────────────────────────────────────────
    path('calendar/sync', CalendarSyncView.as_view(), name='calendar_sync'),
    path('calendar/sync/', CalendarSyncView.as_view()),
    path('calendar/fetch-google', CalendarFetchGoogleView.as_view(), name='calendar_fetch_google'),
    path('calendar/fetch-google/', CalendarFetchGoogleView.as_view()),
    path('calendar/sync-logs', SyncLogsView.as_view(), name='calendar_sync_logs'),
    path('calendar/sync-logs/', SyncLogsView.as_view()),

    # ── Events CRUD ───────────────────────────────────────────────────────────
    path('calendar/events', CalendarEventsView.as_view(), name='calendar_events'),
    path('calendar/events/', CalendarEventsView.as_view()),
    path('calendar/events/<int:pk>', CalendarEventDetailView.as_view(), name='calendar_event_detail'),
    path('calendar/events/<int:pk>/', CalendarEventDetailView.as_view()),

    # ── Reminders ─────────────────────────────────────────────────────────────
    path('calendar/reminders', ReminderView.as_view(), name='calendar_reminders'),
    path('calendar/reminders/', ReminderView.as_view()),

    # ── AI Scheduler ──────────────────────────────────────────────────────────
    path('calendar/ai-schedule', AISchedulerView.as_view(), name='calendar_ai_schedule'),
    path('calendar/ai-schedule/', AISchedulerView.as_view()),
    path('calendar/ai-schedule/<int:schedule_id>/apply', AIScheduleApplyView.as_view(), name='calendar_ai_schedule_apply'),
    path('calendar/ai-schedule/<int:schedule_id>/apply/', AIScheduleApplyView.as_view()),

    # ── AI Insights ───────────────────────────────────────────────────────────
    path('calendar/insights', AIInsightsView.as_view(), name='calendar_insights'),
    path('calendar/insights/', AIInsightsView.as_view()),

    # ── Analytics ─────────────────────────────────────────────────────────────
    path('calendar/heatmap', ProductivityHeatmapView.as_view(), name='calendar_heatmap'),
    path('calendar/heatmap/', ProductivityHeatmapView.as_view()),

    # ── Notifications ─────────────────────────────────────────────────────────
    path('calendar/notification-settings', NotificationSettingsView.as_view(), name='calendar_notification_settings'),
    path('calendar/notification-settings/', NotificationSettingsView.as_view()),

    # ── Webhooks ──────────────────────────────────────────────────────────────
    path('calendar/webhook', WebhookView.as_view(), name='calendar_webhook'),
    path('calendar/webhook/', WebhookView.as_view()),
]
