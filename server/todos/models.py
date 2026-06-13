from django.conf import settings
from django.db import models


class Todo(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='todos',
    )
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True, default='')
    due_date = models.DateField()
    completed = models.BooleanField(default=False)
    completed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # Sync fields
    client_uuid = models.UUIDField(null=True, blank=True, unique=True)
    sync_version = models.PositiveIntegerField(default=1)
    deleted_at = models.DateTimeField(null=True, blank=True)
    last_synced_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['due_date', '-created_at']
        indexes = [
            models.Index(fields=['user', 'completed'], name='todo_user_completed_idx'),
            models.Index(fields=['due_date'], name='todo_due_date_idx'),
        ]

    def save(self, *args, **kwargs):
        if not self.client_uuid:
            import uuid
            self.client_uuid = uuid.uuid4()
        super().save(*args, **kwargs)

    def __str__(self):
        return self.title