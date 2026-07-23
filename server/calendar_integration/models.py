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
    google_email = models.EmailField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    @property
    def connected(self):
        return bool(self.refresh_token or self.access_token)

    def __str__(self):
        return f'{self.user.email} → Google Calendar'


class CalendarEvent(models.Model):
    COLOR_CHOICES = [
        ('blue', 'Blue'),
        ('purple', 'Purple'),
        ('green', 'Green'),
        ('pink', 'Pink'),
        ('orange', 'Orange'),
        ('cyan', 'Cyan'),
        ('red', 'Red'),
    ]
    CATEGORY_CHOICES = [
        ('study', 'Study'),
        ('work', 'Work'),
        ('exercise', 'Exercise'),
        ('personal', 'Personal'),
        ('meeting', 'Meeting'),
        ('break', 'Break'),
        ('ai_generated', 'AI Generated'),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='calendar_events')
    google_event_id = models.CharField(max_length=512, blank=True, default='')
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True, default='')
    start_time = models.DateTimeField()
    end_time = models.DateTimeField()
    all_day = models.BooleanField(default=False)
    color = models.CharField(max_length=20, choices=COLOR_CHOICES, default='blue')
    category = models.CharField(max_length=30, choices=CATEGORY_CHOICES, default='personal')
    location = models.CharField(max_length=500, blank=True, default='')
    attendees = models.JSONField(default=list, blank=True)
    recurrence = models.JSONField(default=list, blank=True)
    reminders = models.JSONField(default=list, blank=True)
    synced_to_google = models.BooleanField(default=False)
    is_ai_generated = models.BooleanField(default=False)
    ai_metadata = models.JSONField(default=dict, blank=True)
    completed = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # Sync fields
    client_uuid = models.UUIDField(null=True, blank=True, unique=True)
    sync_version = models.PositiveIntegerField(default=1)
    deleted_at = models.DateTimeField(null=True, blank=True)
    last_synced_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['start_time']
        indexes = [
            models.Index(fields=['user', 'start_time'], name='calevent_user_start_idx'),
            models.Index(fields=['user', '-created_at'], name='calevent_user_created_idx'),
            models.Index(fields=['google_event_id'], name='calevent_google_id_idx'),
        ]

    def save(self, *args, **kwargs):
        if not self.client_uuid:
            import uuid
            self.client_uuid = uuid.uuid4()
        super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.user.email} — {self.title} ({self.start_time.date()})'


class AISchedule(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('applied', 'Applied'),
        ('rejected', 'Rejected'),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='ai_schedules')
    prompt = models.TextField()
    plan_title = models.CharField(max_length=255, blank=True, default='')
    plan_summary = models.TextField(blank=True, default='')
    generated_events = models.JSONField(default=list)  # Raw AI-generated event list
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f'{self.user.email} — AI Schedule: {self.plan_title}'


class ProductivityInsight(models.Model):
    INSIGHT_TYPES = [
        ('peak_hours', 'Peak Hours'),
        ('burnout_risk', 'Burnout Risk'),
        ('consistency', 'Consistency'),
        ('sleep_impact', 'Sleep Impact'),
        ('exercise_impact', 'Exercise Impact'),
        ('screen_time', 'Screen Time'),
        ('focus_pattern', 'Focus Pattern'),
        ('general', 'General'),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='productivity_insights')
    insight_type = models.CharField(max_length=30, choices=INSIGHT_TYPES, default='general')
    title = models.CharField(max_length=255)
    body = models.TextField()
    icon = models.CharField(max_length=50, blank=True, default='sparkles')
    score = models.FloatField(null=True, blank=True)
    generated_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-generated_at']

    def __str__(self):
        return f'{self.user.email} — {self.title}'


class SyncLog(models.Model):
    DIRECTION_CHOICES = [
        ('push', 'Push to Google'),
        ('pull', 'Pull from Google'),
        ('webhook', 'Webhook'),
    ]
    STATUS_CHOICES = [
        ('success', 'Success'),
        ('error', 'Error'),
        ('partial', 'Partial'),
    ]

    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='sync_logs')
    direction = models.CharField(max_length=10, choices=DIRECTION_CHOICES)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES)
    events_synced = models.IntegerField(default=0)
    error_message = models.TextField(blank=True, default='')
    synced_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-synced_at']

    def __str__(self):
        return f'{self.user.email} — {self.direction} {self.status} @ {self.synced_at}'


class NotificationSettings(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notification_settings')
    browser_notifications = models.BooleanField(default=True)
    email_reminders = models.BooleanField(default=False)
    event_reminders_minutes = models.IntegerField(default=10)
    daily_summary = models.BooleanField(default=True)
    ai_suggestions = models.BooleanField(default=True)
    vapid_subscription = models.JSONField(default=dict, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'{self.user.email} — Notification Settings'
