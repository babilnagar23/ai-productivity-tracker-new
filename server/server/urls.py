from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('users.urls')),
    path('api/', include('routines.urls')),
    path('api/', include('analytics_app.urls')),
    path('api/', include('ai_assistant.urls')),
    path('api/', include('calendar_integration.urls')),
    path('api/todos/', include('todos.urls')),
    path('api/focus-sessions/', include('focus.urls')),
    path('api/notifications/', include('notifications.urls')),
    # Health endpoint for deployment platform monitoring (public)
    path('health/', include('health.urls')),
    path('health', include('health.urls')),  # also match without trailing slash
]
