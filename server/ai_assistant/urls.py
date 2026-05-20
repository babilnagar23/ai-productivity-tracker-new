from django.urls import path

from .views import AnalyzeHabitsView, ChatCoachView, GeneratePlanView

urlpatterns = [
    path('ai/generate-plan', GeneratePlanView.as_view(), name='generate_plan'),
    path('ai/generate-plan/', GeneratePlanView.as_view(), name='generate_plan_slash'),
    path('ai/analyze', AnalyzeHabitsView.as_view(), name='analyze_habits'),
    path('ai/analyze/', AnalyzeHabitsView.as_view(), name='analyze_habits_slash'),
    path('ai/chat', ChatCoachView.as_view(), name='chat_coach'),
    path('ai/chat/', ChatCoachView.as_view(), name='chat_coach_slash'),
]
