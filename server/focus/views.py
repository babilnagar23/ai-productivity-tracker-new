from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from .models import FocusSession
from .serializers import FocusSessionSerializer

class FocusSessionViewSet(viewsets.ModelViewSet):
    serializer_class = FocusSessionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return FocusSession.objects.filter(user=self.request.user)
