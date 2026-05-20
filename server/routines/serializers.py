from django.utils import timezone
from rest_framework import serializers

from users.defaults import DEFAULT_CONFIG

from .models import Routine


def active_checklists_for(user):
    config = getattr(user.profile, 'custom_config', None) or DEFAULT_CONFIG
    return config.get('coreChecklists') or DEFAULT_CONFIG['coreChecklists']


def calculate_productivity_score(core_checklists, active_checklists):
    if not active_checklists:
        return 100
    completed = sum(1 for item in active_checklists if core_checklists.get(item.get('id'), False))
    return round((completed / len(active_checklists)) * 100)


class RoutineSerializer(serializers.ModelSerializer):
    class Meta:
        model = Routine
        fields = [
            'id',
            'user',
            'date',
            'study_completed',
            'exercise_completed',
            'ml_completed',
            'study_hours',
            'sleep_time',
            'wake_time',
            'mobile_usage',
            'notes',
            'productivity_score',
            'core_checklists',
            'core_metrics',
            'custom_logs',
            'created_at',
        ]
        read_only_fields = ['id', 'user', 'productivity_score', 'created_at']

    def to_internal_value(self, data):
        mutable = data.copy()
        if not mutable.get('date'):
            mutable['date'] = timezone.localdate()

        camel_to_snake = {
            'studyCompleted': 'study_completed',
            'exerciseCompleted': 'exercise_completed',
            'mlCompleted': 'ml_completed',
            'studyHours': 'study_hours',
            'sleepTime': 'sleep_time',
            'wakeTime': 'wake_time',
            'mobileUsage': 'mobile_usage',
            'productivityScore': 'productivity_score',
            'coreChecklists': 'core_checklists',
            'coreMetrics': 'core_metrics',
            'customLogs': 'custom_logs',
        }
        for camel, snake in camel_to_snake.items():
            if camel in mutable and snake not in mutable:
                mutable[snake] = mutable[camel]

        core_checklists = mutable.get('core_checklists') or {}
        core_metrics = mutable.get('core_metrics') or {}
        mutable.setdefault('study_completed', bool(core_checklists.get('study', False)))
        mutable.setdefault('exercise_completed', bool(core_checklists.get('exercise', False)))
        mutable.setdefault('ml_completed', bool(core_checklists.get('ml', False)))
        mutable.setdefault('study_hours', float(core_metrics.get('studyHours', 0) or 0))
        mutable.setdefault('mobile_usage', float(core_metrics.get('mobileUsage', 0) or 0))
        return super().to_internal_value(mutable)

    def validate(self, attrs):
        instance = getattr(self, 'instance', None)
        core_checklists = attrs.get('core_checklists', getattr(instance, 'core_checklists', {}) or {})
        core_metrics = attrs.get('core_metrics', getattr(instance, 'core_metrics', {}) or {})

        attrs['study_completed'] = bool(core_checklists.get('study', attrs.get('study_completed', False)))
        attrs['exercise_completed'] = bool(core_checklists.get('exercise', attrs.get('exercise_completed', False)))
        attrs['ml_completed'] = bool(core_checklists.get('ml', attrs.get('ml_completed', False)))
        attrs['study_hours'] = float(core_metrics.get('studyHours', attrs.get('study_hours', 0)) or 0)
        attrs['mobile_usage'] = float(core_metrics.get('mobileUsage', attrs.get('mobile_usage', 0)) or 0)

        request = self.context.get('request')
        if request and request.user.is_authenticated:
            attrs['productivity_score'] = calculate_productivity_score(
                core_checklists,
                active_checklists_for(request.user),
            )
        return attrs

    def to_representation(self, instance):
        data = super().to_representation(instance)
        return {
            **data,
            'userId': str(instance.user_id),
            'studyCompleted': instance.study_completed,
            'exerciseCompleted': instance.exercise_completed,
            'mlCompleted': instance.ml_completed,
            'studyHours': instance.study_hours,
            'sleepTime': instance.sleep_time,
            'wakeTime': instance.wake_time,
            'mobileUsage': instance.mobile_usage,
            'productivityScore': instance.productivity_score,
            'coreChecklists': instance.core_checklists or {},
            'coreMetrics': instance.core_metrics or {},
            'customLogs': instance.custom_logs or [],
            'createdAt': instance.created_at.isoformat() if instance.created_at else None,
        }
