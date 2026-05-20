from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('users.urls')),
    path('api/', include('routines.urls')),
    path('api/', include('analytics_app.urls')),
    path('api/', include('ai_assistant.urls')),
    path('api/', include('calendar_integration.urls')),
]
