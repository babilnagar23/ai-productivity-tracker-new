import React, { useState, useEffect, useRef } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { apiFetch, aiApi, calendarApi, todosApi, focusApi } from '../services/api';
import AppLayout from '../components/layout/AppLayout';
import StatCard from '../components/ui/StatCard';
import ProgressRing from '../components/ui/ProgressRing';
import Badge from '../components/ui/Badge';
import DailyLogPopup from '../components/DailyLogPopup';
import {
  Flame, Sparkles, Timer, CheckSquare, Calendar,
  TrendingUp, RotateCcw, Trophy, ArrowRight, Clock,
  BookOpen, BarChart3, Zap, Target, CalendarCheck2, Plus
} from 'lucide-react';
import { format, isToday, isTomorrow, parseISO } from 'date-fns';

let inAppSkippedThisSession = false;

const localToday = () => {
  const d = new Date();
  d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
  return d.toISOString().split('T')[0];
};

const formatEventTime = (dt) => {
  try { return format(parseISO(dt), 'h:mm a'); } catch { return dt || ''; }
};

const formatUpcomingDate = (dt) => {
  try {
    const d = parseISO(dt);
    if (isToday(d)) return `Today, ${format(d, 'h:mm a')}`;
    if (isTomorrow(d)) return `Tomorrow, ${format(d, 'h:mm a')}`;
    return format(d, 'MMM d, h:mm a');
  } catch { return dt; }
};

const QuickAction = ({ to, icon: Icon, label, color, bg }) => (
  <Link
    to={to}
    className="group glass card-3d p-4 flex flex-col items-center gap-2.5 text-center"
  >
    <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${bg}`}>
      <Icon className="w-5 h-5" style={{ color }} />
    </div>
    <span className="text-xs font-semibold text-gray-300 group-hover:text-white transition-colors">{label}</span>
  </Link>
);

export default function Dashboard() {
  const { user } = useAuth();
  const [routines, setRoutines] = useState([]);
  const [todayEvents, setTodayEvents] = useState([]);
  const [upcomingEvents, setUpcomingEvents] = useState([]);
  const [todos, setTodos] = useState([]);
  const [focusSessions, setFocusSessions] = useState([]);
  const [achievements, setAchievements] = useState([]);
  const [aiAdvice, setAiAdvice] = useState('');
  const [loading, setLoading] = useState(true);
  const [hasTodayEntry, setHasTodayEntry] = useState(false);
  const [popupReady, setPopupReady] = useState(false);
  const [skipped, setSkippedState] = useState(inAppSkippedThisSession);

  const setSkipped = (v) => { inAppSkippedThisSession = v; setSkippedState(v); };
  const showPopup = popupReady && !skipped && !hasTodayEntry;

  // Guard against StrictMode double-mount
  const loadGuard = useRef(false);

  // ── Core data load (fast — no AI) ──────────────────────────────
  useEffect(() => {
    if (loadGuard.current) return;
    loadGuard.current = true;

    const load = async () => {
      const todayStr = localToday();
      const now = new Date();
      const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
      const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59).toISOString();
      const endOfWeek = new Date(now.getTime() + 7 * 86400000).toISOString();

      try {
        const [routineRes, todayEvRes, upcomingEvRes, todoRes, focusRes] = await Promise.allSettled([
          apiFetch('/routines'),
          calendarApi.list({ start: startOfDay, end: endOfDay }),
          calendarApi.list({ start: endOfDay, end: endOfWeek }),
          todosApi.list({ completed: false }),
          focusApi.list(),
        ]);

        if (routineRes.status === 'fulfilled') {
          const data = routineRes.value?.data || routineRes.value || [];
          setRoutines(Array.isArray(data) ? data : []);
          const todayEntry = Array.isArray(data) && data.find(r => (r.date || '').split('T')[0] === todayStr);
          setHasTodayEntry(!!todayEntry);
        }

        if (todayEvRes.status === 'fulfilled') {
          const evs = todayEvRes.value?.data || todayEvRes.value?.results || todayEvRes.value || [];
          setTodayEvents(Array.isArray(evs) ? evs : []);
        }

        if (upcomingEvRes.status === 'fulfilled') {
          const evs = upcomingEvRes.value?.data || upcomingEvRes.value?.results || upcomingEvRes.value || [];
          setUpcomingEvents(Array.isArray(evs) ? evs.slice(0, 5) : []);
        }

        if (todoRes.status === 'fulfilled') {
          const data = todoRes.value?.data || todoRes.value?.results || todoRes.value || [];
          setTodos(Array.isArray(data) ? data.slice(0, 5) : []);
        }

        if (focusRes.status === 'fulfilled') {
          const data = focusRes.value?.data || focusRes.value?.results || focusRes.value || [];
          setFocusSessions(Array.isArray(data) ? data : []);
        }
      } catch (err) {
        console.error('Dashboard load error:', err);
      } finally {
        setLoading(false);
        setPopupReady(true);
      }
    };
    load();
  }, []);

  // ── AI insight loaded lazily AFTER page renders ────────────────
  useEffect(() => {
    const AI_CACHE_KEY = 'dashboard_ai_advice';
    const AI_CACHE_TS_KEY = 'dashboard_ai_advice_ts';
    const AI_CACHE_TTL = 5 * 60 * 1000; // 5 minutes

    const loadAI = async () => {
      // Check sessionStorage cache first
      const cached = sessionStorage.getItem(AI_CACHE_KEY);
      const cachedTs = Number(sessionStorage.getItem(AI_CACHE_TS_KEY) || '0');
      if (cached && Date.now() - cachedTs < AI_CACHE_TTL) {
        setAiAdvice(cached);
        return;
      }

      try {
        const aiRes = await aiApi.analyze();
        const advice = aiRes?.data || aiRes || '';
        if (advice) {
          setAiAdvice(advice);
          sessionStorage.setItem(AI_CACHE_KEY, typeof advice === 'string' ? advice : JSON.stringify(advice));
          sessionStorage.setItem(AI_CACHE_TS_KEY, String(Date.now()));
        }
      } catch {
        // AI insight is non-critical — fail silently
      }
    };
    loadAI();
  }, []);

  // Stats
  const totalRoutines = routines.length;
  const avgProductivity = totalRoutines
    ? Math.round(routines.reduce((s, r) => s + (r.productivityScore || r.productivity_score || 0), 0) / totalRoutines)
    : 0;
  const avgStudy = totalRoutines
    ? (routines.reduce((s, r) => s + (r.studyHours || r.study_hours || r.coreMetrics?.studyHours || 0), 0) / totalRoutines).toFixed(1)
    : '0';
  const todayFocusMins = focusSessions
    .filter(s => (s.created_at || s.start_time || '').startsWith(localToday()))
    .reduce((s, session) => s + (session.durationMinutes || session.duration_minutes || 0), 0);
  const streak = user?.streak || 0;
  const level = Math.floor((user?.xp || 0) / 100) + 1;
  const xpProgress = (user?.xp || 0) % 100;

  const todayRoutine = routines.find(r => (r.date || '').split('T')[0] === localToday());
  const routineScore = todayRoutine?.productivityScore || todayRoutine?.productivity_score || 0;

  return (
    <AppLayout title="Dashboard">
      {showPopup && (
        <DailyLogPopup
          onClose={() => setSkipped(true)}
          onLogged={() => { setHasTodayEntry(true); setSkipped(false); }}
        />
      )}

      <div className="space-y-6 max-w-7xl mx-auto animate-fadeInUp">
        {/* ── Welcome Header ──────────────────────────────────────── */}
        <div className="flex flex-col sm:flex-row sm:items-center gap-4 justify-between">
          <div>
            <h1 className="text-2xl font-hero font-extrabold text-white">
              Welcome back, <span className="text-cyan">{user?.name || user?.username}</span> 👋
            </h1>
            <p className="text-sm text-gray-400 mt-1">
              {format(new Date(), "EEEE, MMMM do yyyy")} · Your productivity command center
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            {/* Log status */}
            <div className={`flex items-center gap-2 px-3 py-2 rounded-xl border text-sm font-semibold
              ${hasTodayEntry
                ? 'bg-green-500/10 border-green-500/20 text-green-400'
                : 'bg-orange-500/10 border-orange-500/20 text-orange-400'
              }`}>
              <CalendarCheck2 className="w-4 h-4" />
              {hasTodayEntry ? 'Today logged ✓' : 'Not logged yet'}
            </div>

            {/* Streak */}
            <div className="flex items-center gap-2 glass px-3 py-2">
              <Flame className="w-4 h-4 text-orange-400 animate-bounce" />
              <span className="text-sm font-bold text-orange-400">{streak} day streak</span>
            </div>
          </div>
        </div>

        {/* Nudge if skipped */}
        {!hasTodayEntry && skipped && !loading && (
          <div className="glass card-3d p-4 border border-orange-500/20 bg-orange-500/5 flex items-center justify-between gap-4 animate-fadeIn">
            <div className="flex items-center gap-3">
              <CalendarCheck2 className="w-5 h-5 text-orange-400 flex-shrink-0" />
              <p className="text-sm text-gray-300">
                <span className="font-semibold text-orange-300">No entry for today.</span>{' '}
                Log your daily routine to maintain your streak.
              </p>
            </div>
            <button
              onClick={() => setSkipped(false)}
              className="shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-xl bg-orange-500/15 border border-orange-500/20 text-orange-400 text-xs font-bold hover:bg-orange-500/25 transition"
            >
              <Zap className="w-3.5 h-3.5" /> Log Now
            </button>
          </div>
        )}

        {/* ── AI Insight Banner ────────────────────────────────────── */}
        <div className="glass card-3d p-5 flex gap-4 items-start relative overflow-hidden border-l-4 border-cyan/60">
          <div className="absolute top-0 right-0 w-48 h-48 bg-cyan/5 rounded-full blur-3xl pointer-events-none" />
          <div className="p-2.5 bg-cyan/15 rounded-xl text-cyan flex-shrink-0">
            <Sparkles className="w-5 h-5" />
          </div>
          <div className="min-w-0">
            <h3 className="font-bold text-white text-sm mb-1">AI Habit Synthesis</h3>
            <p className="text-sm text-gray-300 leading-relaxed italic">
              {aiAdvice
                ? `"${aiAdvice}"`
                : loading
                  ? 'Analyzing your patterns...'
                  : 'Connect to the AI for personalized productivity insights.'}
            </p>
          </div>
        </div>

        {/* ── Stats Grid ───────────────────────────────────────────── */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard
            label="Productivity Index"
            value={`${avgProductivity}%`}
            sub="Average across routines"
            icon={TrendingUp}
            color="#00FFFF"
            gradient="from-cyan/5"
            ring={avgProductivity}
          />
          <StatCard
            label="Study Focus"
            value={`${avgStudy}h`}
            sub="Average daily study hours"
            icon={Clock}
            color="#3B82F6"
            gradient="from-blue-500/5"
          />
          <StatCard
            label="Focus Today"
            value={`${Math.floor(todayFocusMins / 60)}h ${todayFocusMins % 60}m`}
            sub="Deep work sessions"
            icon={Timer}
            color="#BF5AF2"
            gradient="from-plasma/5"
          />
          <StatCard
            label="Daily Streak"
            value={`${streak} Days`}
            sub={`Level ${level} · ${xpProgress}/100 XP`}
            icon={Flame}
            color="#F59E0B"
            gradient="from-orange-500/5"
          />
        </div>

        {/* ── Main Content Grid ────────────────────────────────────── */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Today's Schedule */}
          <div className="lg:col-span-2 space-y-6">
            <div className="glass card-3d p-5">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <Calendar className="w-4 h-4 text-cyan" />
                  <h2 className="font-bold text-white">Today's Schedule</h2>
                </div>
                <Link to="/calendar" className="text-xs text-cyan hover:text-white flex items-center gap-1">
                  Open Calendar <ArrowRight className="w-3 h-3" />
                </Link>
              </div>
              {loading ? (
                <div className="space-y-2">
                  {[1,2,3].map(i => <div key={i} className="h-10 rounded-lg bg-white/4 animate-shimmer" />)}
                </div>
              ) : todayEvents.length === 0 ? (
                <div className="py-8 text-center text-sm text-gray-500">No events today.{' '}
                  <Link to="/calendar" className="text-blue-400 hover:underline">Add one →</Link>
                </div>
              ) : (
                <div className="space-y-2">
                  {todayEvents.slice(0, 6).map((ev, i) => (
                    <div key={ev.id || i} className="flex items-center gap-3 p-3 rounded-xl bg-white/3 hover:bg-white/5 transition-colors">
                      <div className="w-1.5 h-1.5 rounded-full bg-blue-400 flex-shrink-0 mt-0.5" />
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium text-white truncate">{ev.title}</p>
                        {ev.start_time && <p className="text-xs text-gray-500">{formatEventTime(ev.start_time)}</p>}
                      </div>
                      {ev.color && (
                        <span className="w-2 h-2 rounded-full flex-shrink-0"
                          style={{ background: ev.color === 'blue' ? '#3B82F6' : ev.color === 'green' ? '#10B981' : ev.color === 'purple' ? '#8B5CF6' : '#F59E0B' }}
                        />
                      )}
                    </div>
                  ))}
                  {todayEvents.length > 6 && (
                    <Link to="/calendar" className="block text-xs text-blue-400 text-center py-2 hover:underline">
                      +{todayEvents.length - 6} more events
                    </Link>
                  )}
                </div>
              )}
            </div>

            {/* Tasks Preview */}
            <div className="glass card-3d p-5">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <CheckSquare className="w-4 h-4 text-green-400" />
                  <h2 className="font-bold text-white">Pending Tasks</h2>
                </div>
                <Link to="/todos" className="text-xs text-cyan hover:text-white flex items-center gap-1">
                  View All <ArrowRight className="w-3 h-3" />
                </Link>
              </div>
              {loading ? (
                <div className="space-y-2">
                  {[1,2,3].map(i => <div key={i} className="h-10 rounded-lg bg-white/4 animate-shimmer" />)}
                </div>
              ) : todos.length === 0 ? (
                <div className="py-6 text-center text-sm text-gray-500">
                  All tasks complete! 🎉{' '}
                  <Link to="/todos" className="text-blue-400 hover:underline">Add new →</Link>
                </div>
              ) : (
                <div className="space-y-2">
                  {todos.map((t, i) => (
                    <div key={t.id || i} className="flex items-center gap-3 p-3 rounded-xl bg-white/3 hover:bg-white/5 transition-colors">
                      <div className="w-4 h-4 rounded border border-white/20 flex-shrink-0" />
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium text-white truncate">{t.title}</p>
                        {t.due_date && (
                          <p className="text-xs text-gray-500">Due {format(parseISO(t.due_date), 'MMM d')}</p>
                        )}
                      </div>
                      {t.priority && (
                        <Badge variant={t.priority === 'high' ? 'rose' : t.priority === 'medium' ? 'orange' : 'gray'} size="xs">
                          {t.priority}
                        </Badge>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>

          {/* Right column */}
          <div className="space-y-6">


            {/* Upcoming Events */}
            <div className="glass card-3d p-5">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-2">
                  <Target className="w-4 h-4 text-plasma" />
                  <h2 className="font-bold text-white text-sm">Upcoming</h2>
                </div>
                <Link to="/calendar" className="text-xs text-cyan hover:underline">View all</Link>
              </div>
              {upcomingEvents.length === 0 ? (
                <p className="text-xs text-gray-500 py-4 text-center">No upcoming events</p>
              ) : (
                <div className="space-y-2">
                  {upcomingEvents.map((ev, i) => (
                    <div key={ev.id || i} className="flex items-start gap-2.5 p-2 rounded-lg hover:bg-white/3 transition-colors">
                      <div className="w-1.5 h-1.5 rounded-full bg-green-400 flex-shrink-0 mt-1.5" />
                      <div className="min-w-0">
                        <p className="text-xs font-semibold text-white truncate">{ev.title}</p>
                        <p className="text-[10px] text-gray-500">{formatUpcomingDate(ev.start_time)}</p>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Quick Links */}
            <div>
              <h2 className="font-bold text-white text-sm mb-3 flex items-center gap-2">
                <Zap className="w-4 h-4 text-yellow-400" /> Quick Actions
              </h2>
              <div className="grid grid-cols-2 gap-2">
                <QuickAction to="/daily-log" icon={BookOpen} label="Log Today" color="#00FFFF" bg="bg-cyan/10" />
                <QuickAction to="/focus" icon={Timer} label="Focus" color="#BF5AF2" bg="bg-plasma/10" />
                <QuickAction to="/todos" icon={Plus} label="Add Task" color="#3B82F6" bg="bg-blue-500/10" />
                <QuickAction to="/analytics" icon={BarChart3} label="Analytics" color="#F59E0B" bg="bg-orange-500/10" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </AppLayout>
  );
}
