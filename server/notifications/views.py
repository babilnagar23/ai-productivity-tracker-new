from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .models import NotificationRecord
from .serializers import NotificationRecordSerializer

class NotificationRecordViewSet(viewsets.ModelViewSet):
    serializer_class = NotificationRecordSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return NotificationRecord.objects.filter(user=self.request.user)

    @action(detail=False, methods=['post'], url_path='mark-all-read')
    def mark_all_read(self, request):
        updated = self.get_queryset().filter(is_read=False).update(is_read=True)
        return Response({'success': True, 'updated': updated}, status=status.HTTP_200_OK)
