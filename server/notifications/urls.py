from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import NotificationRecordViewSet

router = DefaultRouter()
router.register(r'', NotificationRecordViewSet, basename='notification')

urlpatterns = [
    path('', include(router.urls)),
]
