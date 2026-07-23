from django.urls import path
from .views import HealthCheckView

urlpatterns = [
    path('api/health/', include('health.urls')),
]
