from django.conf import settings
from django.db import models

class NotificationRecord(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications')
    client_uuid = models.UUIDField(null=True, blank=True, unique=True)
    type = models.CharField(max_length=50) # todo, calendar, daily_log, achievement, streak, focus
    title = models.CharField(max_length=255)
    body = models.TextField()
    payload_json = models.JSONField(default=dict, blank=True)
    scheduled_for = models.DateTimeField(null=True, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    read_at = models.DateTimeField(null=True, blank=True)
    dismissed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    deleted_at = models.DateTimeField(null=True, blank=True)
    sync_version = models.PositiveIntegerField(default=1)
    last_synced_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', '-created_at'], name='notif_user_created_idx'),
            models.Index(fields=['user', 'read_at'], name='notif_user_read_idx'),
            models.Index(fields=['user', 'deleted_at'], name='notif_user_deleted_idx'),
        ]

    def __str__(self):
        return f"{self.type} - {self.title}"
