from django.db import IntegrityError
from rest_framework import status, viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Routine
from .serializers import RoutineSerializer


class RoutineViewSet(viewsets.ModelViewSet):
    serializer_class = RoutineSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Routine.objects.filter(user=self.request.user).order_by('-date', '-created_at')

    def list(self, request, *args, **kwargs):
        data = self.get_serializer(self.get_queryset(), many=True).data
        return Response({'success': True, 'count': len(data), 'data': data})

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            routine = serializer.save(user=request.user)
        except IntegrityError:
            existing = Routine.objects.filter(user=request.user, date=serializer.validated_data['date']).first()
            return Response(
                {
                    'success': False,
                    'error': 'A log entry already exists for this date. Edit the existing entry instead.',
                    'existingId': str(existing.id) if existing else None,
                },
                status=status.HTTP_409_CONFLICT,
            )
        self._sync_profile_rewards(request.user)
        return Response({'success': True, 'data': self.get_serializer(routine).data}, status=status.HTTP_201_CREATED)

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        try:
            routine = serializer.save()
        except IntegrityError:
            existing = (
                Routine.objects.filter(user=request.user, date=serializer.validated_data['date'])
                .exclude(id=instance.id)
                .first()
            )
            return Response(
                {
                    'success': False,
                    'error': 'A log entry already exists for this date. Edit the existing entry instead.',
                    'existingId': str(existing.id) if existing else None,
                },
                status=status.HTTP_409_CONFLICT,
            )
        return Response({'success': True, 'data': self.get_serializer(routine).data})

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        instance.delete()
        self._sync_profile_rewards(request.user)
        return Response({'success': True, 'data': {}})

    def _sync_profile_rewards(self, user):
        from datetime import timedelta
        from django.utils import timezone

        profile = user.profile
        # Calculate consecutive-day streak (not total count)
        dates = set(
            Routine.objects.filter(user=user).values_list('date', flat=True)
        )
        day = timezone.localdate()
        streak = 0
        while day in dates:
            streak += 1
            day -= timedelta(days=1)

        profile.streak = streak
        profile.xp = streak * 10
        profile.save(update_fields=['streak', 'xp'])
