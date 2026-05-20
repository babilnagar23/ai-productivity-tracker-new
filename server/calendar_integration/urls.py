from django.urls import path

from .views import CalendarAuthUrlView, CalendarCallbackView, CalendarStatusView, CalendarSyncView, ReminderView

urlpatterns = [
    path('calendar/status', CalendarStatusView.as_view(), name='calendar_status'),
    path('calendar/status/', CalendarStatusView.as_view(), name='calendar_status_slash'),
    path('calendar/auth-url', CalendarAuthUrlView.as_view(), name='calendar_auth_url'),
    path('calendar/auth-url/', CalendarAuthUrlView.as_view(), name='calendar_auth_url_slash'),
    path('calendar/callback', CalendarCallbackView.as_view(), name='calendar_callback'),
    path('calendar/callback/', CalendarCallbackView.as_view(), name='calendar_callback_slash'),
    path('calendar/sync', CalendarSyncView.as_view(), name='calendar_sync'),
    path('calendar/sync/', CalendarSyncView.as_view(), name='calendar_sync_slash'),
    path('calendar/reminders', ReminderView.as_view(), name='calendar_reminders'),
    path('calendar/reminders/', ReminderView.as_view(), name='calendar_reminders_slash'),
]
