from django.conf import settings
from django.db import models


class Routine(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='routines')
    date = models.DateField()
    study_completed = models.BooleanField(default=False)
    exercise_completed = models.BooleanField(default=False)
    ml_completed = models.BooleanField(default=False)
    study_hours = models.FloatField(default=0)
    sleep_time = models.CharField(max_length=8, default='23:00')
    wake_time = models.CharField(max_length=8, default='07:00')
    mobile_usage = models.FloatField(default=0)
    notes = models.TextField(blank=True, default='')
    productivity_score = models.PositiveSmallIntegerField(default=0)
    core_checklists = models.JSONField(default=dict, blank=True)
    core_metrics = models.JSONField(default=dict, blank=True)
    custom_logs = models.JSONField(default=list, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    
    # Sync fields
    client_uuid = models.UUIDField(null=True, blank=True, unique=True)
    sync_version = models.PositiveIntegerField(default=1)
    deleted_at = models.DateTimeField(null=True, blank=True)
    last_synced_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-date', '-created_at']
        constraints = [
            models.UniqueConstraint(fields=['user', 'date'], name='unique_routine_per_user_day'),
        ]
        indexes = [
            models.Index(fields=['date'], name='routine_date_idx'),
            models.Index(fields=['user', '-date'], name='routine_user_date_idx'),
        ]

    def __str__(self):
        return f'{self.user.email} routine {self.date}'
