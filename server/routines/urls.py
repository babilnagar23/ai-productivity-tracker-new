from django.urls import path
from rest_framework.routers import SimpleRouter

from .views import RoutineViewSet

router = SimpleRouter(trailing_slash=False)
router.register('routines', RoutineViewSet, basename='routines')

routine_list = RoutineViewSet.as_view({'get': 'list', 'post': 'create'})
routine_detail = RoutineViewSet.as_view({'get': 'retrieve', 'put': 'update', 'patch': 'partial_update', 'delete': 'destroy'})

urlpatterns = router.urls + [
    path('routines/', routine_list, name='routines-list-slash'),
    path('routines/<int:pk>/', routine_detail, name='routines-detail-slash'),
]
