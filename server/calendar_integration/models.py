from django.conf import settings
from django.db import models


class GoogleCalendarConnection(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='google_calendar')
    access_token = models.TextField(blank=True, default='')
    refresh_token = models.TextField(blank=True, default='')
    token_uri = models.URLField(default='https://oauth2.googleapis.com/token')
    scopes = models.JSONField(default=list)
    expiry = models.DateTimeField(null=True, blank=True)
    calendar_id = models.CharField(max_length=255, default='primary')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    @property
    def connected(self):
        return bool(self.refresh_token or self.access_token)
