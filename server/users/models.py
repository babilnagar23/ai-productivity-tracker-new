import random
import string
from datetime import timedelta

from django.conf import settings
from django.db import models
from django.utils import timezone

from .defaults import DEFAULT_CONFIG


def default_config():
    return {
        'coreChecklists': [item.copy() for item in DEFAULT_CONFIG['coreChecklists']],
        'coreMetrics': [item.copy() for item in DEFAULT_CONFIG['coreMetrics']],
        'deletedHistory': [],
    }


class EmailOTP(models.Model):
    """Stores one-time passwords for email verification during registration."""

    email = models.EmailField(db_index=True)
    otp_code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    is_verified = models.BooleanField(default=False)
    attempt_count = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['email', 'is_verified']),
        ]
        verbose_name = 'Email OTP'
        verbose_name_plural = 'Email OTPs'

    def __str__(self):
        return f'OTP for {self.email} (verified={self.is_verified})'

    def save(self, *args, **kwargs):
        if not self.expires_at:
            self.expires_at = timezone.now() + timedelta(minutes=10)
        super().save(*args, **kwargs)

    @property
    def is_expired(self):
        return timezone.now() > self.expires_at

    @classmethod
    def generate_otp(cls):
        """Generate a random 6-digit numeric OTP."""
        return ''.join(random.choices(string.digits, k=6))

    @classmethod
    def cleanup_expired(cls):
        """Delete all expired, unverified OTPs."""
        cls.objects.filter(expires_at__lt=timezone.now(), is_verified=False).delete()

    @classmethod
    def get_recent_count(cls, email, hours=1):
        """Count OTPs sent to an email within the last N hours (rate limiting)."""
        cutoff = timezone.now() - timedelta(hours=hours)
        return cls.objects.filter(email__iexact=email, created_at__gte=cutoff).count()


class UserProfile(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='profile')
    streak = models.PositiveIntegerField(default=0)
    xp = models.PositiveIntegerField(default=0)
    avatar = models.TextField(blank=True, null=True)
    custom_config = models.JSONField(default=default_config)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'{self.user.email} profile'
