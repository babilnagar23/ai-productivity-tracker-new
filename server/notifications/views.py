from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from .models import NotificationRecord
from .serializers import NotificationRecordSerializer

class NotificationRecordViewSet(viewsets.ModelViewSet):
    serializer_class = NotificationRecordSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return NotificationRecord.objects.filter(user=self.request.user)
