from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from .views import CustomConfigView, LoginView, MeView, RegisterView

urlpatterns = [
    path('auth/register', RegisterView.as_view(), name='register'),
    path('auth/register/', RegisterView.as_view(), name='register_slash'),
    path('auth/login', LoginView.as_view(), name='login'),
    path('auth/login/', LoginView.as_view(), name='login_slash'),
    path('auth/me', MeView.as_view(), name='me'),
    path('auth/me/', MeView.as_view(), name='me_slash'),
    path('auth/custom-config', CustomConfigView.as_view(), name='custom_config'),
    path('auth/custom-config/', CustomConfigView.as_view(), name='custom_config_slash'),
    path('auth/token/refresh', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh_slash'),
    path('auth/refresh', TokenRefreshView.as_view(), name='refresh'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='refresh_slash'),
]
