from django.conf import settings
from django.db import models

from .defaults import DEFAULT_CONFIG


def default_config():
    return {
        'coreChecklists': [item.copy() for item in DEFAULT_CONFIG['coreChecklists']],
        'coreMetrics': [item.copy() for item in DEFAULT_CONFIG['coreMetrics']],
        'deletedHistory': [],
    }


class UserProfile(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='profile')
    streak = models.PositiveIntegerField(default=0)
    xp = models.PositiveIntegerField(default=0)
    custom_config = models.JSONField(default=default_config)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'{self.user.email} profile'
