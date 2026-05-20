from django.urls import path

from .views import FullAnalyticsView, InsightsView, WeeklyAnalyticsView

urlpatterns = [
    path('analytics/weekly', WeeklyAnalyticsView.as_view(), name='weekly_analytics'),
    path('analytics/weekly/', WeeklyAnalyticsView.as_view(), name='weekly_analytics_slash'),
    path('analytics/full', FullAnalyticsView.as_view(), name='full_analytics'),
    path('analytics/full/', FullAnalyticsView.as_view(), name='full_analytics_slash'),
    path('analytics/insights', InsightsView.as_view(), name='analytics_insights'),
    path('analytics/insights/', InsightsView.as_view(), name='analytics_insights_slash'),
]
