from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import FocusSessionViewSet

router = DefaultRouter()
router.register(r'', FocusSessionViewSet, basename='focus-session')

urlpatterns = [
    path('', include(router.urls)),
]
