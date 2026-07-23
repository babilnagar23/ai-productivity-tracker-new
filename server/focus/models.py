from django.conf import settings
from django.db import models

class FocusSession(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='focus_sessions')
    client_uuid = models.UUIDField(null=True, blank=True, unique=True)
    session_type = models.CharField(max_length=50) # timer, stopwatch
    label = models.CharField(max_length=255)
    start_time = models.DateTimeField()
    end_time = models.DateTimeField(null=True, blank=True)
    duration_minutes = models.IntegerField()
    completed = models.BooleanField(default=False)
    laps_json = models.JSONField(default=list, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    deleted_at = models.DateTimeField(null=True, blank=True)
    sync_version = models.PositiveIntegerField(default=1)
    last_synced_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-start_time']
        indexes = [
            models.Index(fields=['user', '-start_time'], name='focus_user_start_idx'),
            models.Index(fields=['user', 'completed'], name='focus_user_completed_idx'),
        ]

    def __str__(self):
        return f"{self.user.email} - {self.label} ({self.duration_minutes}m)"
