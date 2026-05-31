import React, { useState, useEffect } from 'react';
import { useAuth } from '../context/AuthContext';
import { apiFetch } from '../services/api';
import Navbar from '../components/Navbar';
import Sidebar from '../components/Sidebar';
import DailyLogPopup from '../components/DailyLogPopup';
import { 
  Zap, 
  Flame, 
  Target, 
  Award,
  Sparkles, 
  TrendingUp, 
  Clock, 
  CheckCircle2,
  Smartphone,
  CalendarCheck2
} from 'lucide-react';

/* Module-level variable to track if the user skipped the check-in popup
   during this active SPA session. Survives in-app navigation, but resets
   to false on full page refresh/reload. */
let inAppSkippedThisSession = false;

const localToday = () => {
  const date = new Date();
  date.setMinutes(date.getMinutes() - date.getTimezoneOffset());
  return date.toISOString().split('T')[0];
};

const Dashboard = () => {
  const { user } = useAuth();
  const [routines, setRoutines]         = useState([]);
  const [aiAdvice, setAiAdvice]         = useState('Fetching real-time neural insights...');
  const [loading, setLoading]           = useState(true);

  /* ── Popup state ────────────────────────────────────────────── */
  // skipped: uses in-memory session tracking. Cleared completely on page reload.
  const [skipped, setSkippedState]       = useState(inAppSkippedThisSession);
  const setSkipped = (val) => {
    inAppSkippedThisSession = val;
    setSkippedState(val);
  };
  // hasTodayEntry: true if the user already has a log for today
  const [hasTodayEntry, setHasTodayEntry] = useState(false);
  // popupReady: don't show until we've confirmed the above
  const [popupReady, setPopupReady]     = useState(false);

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        const res = await apiFetch('/routines');
        if (res.success) {
          setRoutines(res.data);

          /* Check if any entry matches today's local date */
          const todayStr = localToday();
          const todayEntry = res.data.find(r => {
            const entryDate = r.date ? r.date.split('T')[0] : '';
            return entryDate === todayStr;
          });
          setHasTodayEntry(!!todayEntry);
        }

        /* Fetch quick advice */
        const adviceRes = await apiFetch('/ai/analyze', { method: 'POST' });
        if (adviceRes.success) setAiAdvice(adviceRes.data);
      } catch (err) {
        console.error('Error fetching dashboard data:', err);
        setAiAdvice('AI Assistant currently resting. Maintain study metrics manually.');
      } finally {
        setLoading(false);
        setPopupReady(true); // we now know if today is logged or not
      }
    };

    fetchDashboardData();
  }, []);

  /* Show popup when: ready, not skipped this session, no entry for today */
  const showPopup = popupReady && !loading && !skipped && !hasTodayEntry;

  /* Compute stats */
  const totalRoutines        = routines.length;
  const averageProductivity  = totalRoutines 
    ? Math.round(routines.reduce((acc, curr) => acc + (curr.productivityScore || 0), 0) / totalRoutines)
    : 0;
  const averageStudyHours    = totalRoutines
    ? (routines.reduce((acc, curr) => acc + (curr.coreMetrics?.studyHours || curr.studyHours || 0), 0) / totalRoutines).toFixed(1)
    : 0;
  const averageMobileUsage   = totalRoutines
    ? (routines.reduce((acc, curr) => acc + (curr.coreMetrics?.mobileUsage || curr.mobileUsage || 0), 0) / totalRoutines).toFixed(1)
    : 0;

  return (
    <div className="flex bg-background min-h-screen text-white">

      {/* ── Daily Log Popup ────────────────────────────────────── */}
      {showPopup && (
        <DailyLogPopup
          onClose={() => setSkipped(true)}
          onLogged={() => {
            setHasTodayEntry(true);
            setSkipped(false);
          }}
        />
      )}

      <Sidebar />
      <div className="flex-1 flex flex-col overflow-y-auto">
        <Navbar />
        
        <main className="p-8 space-y-8 flex-1">
          {/* Welcome section */}
          <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
            <div>
              <h1 className="text-3xl font-extrabold tracking-tight">
                Welcome back, <span className="text-gradient font-black">{user?.name}</span>
              </h1>
              <p className="text-sm text-gray-400">Neural mainframe active. Ready to monitor daily consistency.</p>
            </div>
            
            <div className="flex items-center gap-3">
              {/* Today's log status badge */}
              <div className={`flex items-center gap-2 px-4 py-2.5 rounded-2xl border ${
                hasTodayEntry
                  ? 'bg-green-500/10 border-green-500/20 text-green-400'
                  : 'bg-orange-500/10 border-orange-500/20 text-orange-400'
              }`}>
                <CalendarCheck2 className="h-4 w-4" />
                <div>
                  <p className="text-[10px] uppercase font-bold leading-none">Today's Log</p>
                  <p className="text-xs font-semibold">
                    {hasTodayEntry ? 'Completed ✓' : 'Not logged yet'}
                  </p>
                </div>
              </div>

              {/* Daily Streak */}
              <div className="flex items-center gap-2 bg-white/5 border border-white/5 px-4 py-2.5 rounded-2xl">
                <Flame className="h-5 w-5 text-orange-500 animate-bounce" />
                <div>
                  <p className="text-[10px] uppercase font-semibold text-gray-400 leading-none">Daily Streak</p>
                  <p className="text-sm font-bold text-orange-400">{user?.streak || 0} Days</p>
                </div>
              </div>
            </div>
          </div>

          {/* Today not logged — inline nudge (when popup was skipped) */}
          {!hasTodayEntry && skipped && !loading && (
            <div className="glass-card p-4 border border-orange-500/20 bg-orange-500/5 flex items-center justify-between gap-4 animate-fadeIn">
              <div className="flex items-center gap-3">
                <CalendarCheck2 className="h-5 w-5 text-orange-400 flex-shrink-0" />
                <p className="text-sm text-gray-300">
                  <span className="font-semibold text-orange-300">No entry for today yet.</span>{' '}
                  Log your daily routine to maintain your streak.
                </p>
              </div>
              <button
                onClick={() => setSkipped(false)}
                className="shrink-0 flex items-center gap-1.5 px-4 py-2 rounded-xl
                           bg-orange-500/15 border border-orange-500/20 text-orange-400
                           text-xs font-bold hover:bg-orange-500/25 transition"
              >
                <Zap className="h-3.5 w-3.5" /> Log Now
              </button>
            </div>
          )}

          {/* AI Quick Insight Banner */}
          <div className="glass-card p-6 border-l-4 border-blue-500 flex gap-4 items-start relative overflow-hidden">
            <div className="absolute top-0 right-0 w-64 h-64 bg-blue-500/5 rounded-full blur-3xl -z-10" />
            <div className="p-3 bg-blue-500/10 rounded-2xl text-blue-400">
              <Sparkles className="h-6 w-6" />
            </div>
            <div>
              <h3 className="font-bold text-white mb-1">AI Habit Synthesis</h3>
              <p className="text-sm text-gray-300 leading-relaxed italic">
                "{aiAdvice}"
              </p>
            </div>
          </div>

          {/* Stats Cards */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6">
            <div className="glass-card p-6 space-y-4">
              <div className="flex justify-between items-start">
                <span className="text-sm text-gray-400 font-medium">Productivity Index</span>
                <TrendingUp className="h-5 w-5 text-green-400" />
              </div>
              <div className="space-y-1">
                <h3 className="text-3xl font-extrabold">{averageProductivity}%</h3>
                <p className="text-xs text-gray-500">Avg across logged routines</p>
              </div>
            </div>

            <div className="glass-card p-6 space-y-4">
              <div className="flex justify-between items-start">
                <span className="text-sm text-gray-400 font-medium">Study Focus</span>
                <Clock className="h-5 w-5 text-blue-400" />
              </div>
              <div className="space-y-1">
                <h3 className="text-3xl font-extrabold">{averageStudyHours} hrs</h3>
                <p className="text-xs text-gray-500">Average Daily Study Hours</p>
              </div>
            </div>

            <div className="glass-card p-6 space-y-4">
              <div className="flex justify-between items-start">
                <span className="text-sm text-gray-400 font-medium">Mobile Downtime</span>
                <Smartphone className="h-5 w-5 text-purple-400" />
              </div>
              <div className="space-y-1">
                <h3 className="text-3xl font-extrabold">{averageMobileUsage} hrs</h3>
                <p className="text-xs text-gray-500">Average daily screen time</p>
              </div>
            </div>

            <div className="glass-card p-6 space-y-4">
              <div className="flex justify-between items-start">
                <span className="text-sm text-gray-400 font-medium">Neural Milestones</span>
                <Award className="h-5 w-5 text-yellow-400" />
              </div>
              <div className="space-y-1">
                <h3 className="text-3xl font-extrabold">{totalRoutines} Done</h3>
                <p className="text-xs text-gray-500">Routines submitted in system</p>
              </div>
            </div>
          </div>

          {/* Subpanels */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
            {/* Active Config variables */}
            <div className="glass-card p-6 space-y-4">
              <h3 className="font-bold text-lg text-white">Active Variables Summary</h3>
              <p className="text-xs text-gray-400">Core checklists and numerical inputs dynamically tracked in your forms</p>
              
              <div className="grid grid-cols-2 gap-4 pt-2">
                <div className="p-4 bg-white/5 border border-white/5 rounded-2xl space-y-2">
                  <span className="text-[10px] uppercase font-bold text-blue-400">Core Checklists</span>
                  <div className="text-xs text-white space-y-1 font-semibold">
                    {user?.customConfig?.coreChecklists?.length > 0 ? (
                      user.customConfig.coreChecklists.slice(0, 3).map((chk, idx) => (
                        <div key={chk.id || idx} className="truncate">✓ {chk.title}</div>
                      ))
                    ) : (
                      <div className="text-gray-500 italic">None active</div>
                    )}
                    {user?.customConfig?.coreChecklists?.length > 3 && (
                      <div className="text-[9px] text-gray-400 font-normal italic">
                        + {user.customConfig.coreChecklists.length - 3} more checklists
                      </div>
                    )}
                  </div>
                </div>

                <div className="p-4 bg-white/5 border border-white/5 rounded-2xl space-y-2">
                  <span className="text-[10px] uppercase font-bold text-purple-400">Core Metrics</span>
                  <div className="text-xs text-white space-y-1 font-semibold">
                    {user?.customConfig?.coreMetrics?.length > 0 ? (
                      user.customConfig.coreMetrics.slice(0, 3).map((met, idx) => (
                        <div key={met.id || idx} className="truncate">📊 {met.title}</div>
                      ))
                    ) : (
                      <div className="text-gray-500 italic">None active</div>
                    )}
                    {user?.customConfig?.coreMetrics?.length > 3 && (
                      <div className="text-[9px] text-gray-400 font-normal italic">
                        + {user.customConfig.coreMetrics.length - 3} more metrics
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>

            {/* Quick Actions / Shortcuts */}
            <div className="glass-card p-6 space-y-4">
              <h3 className="font-bold text-lg text-white">System Actions</h3>
              <p className="text-xs text-gray-400">Access primary operation control segments instantly</p>
              
              <div className="space-y-3 pt-2">
                <a href="/routines" className="w-full flex items-center justify-between p-4 bg-white/5 border border-white/5 rounded-2xl hover:border-blue-500/30 hover:bg-white/10 transition-all text-left">
                  <div>
                    <h4 className="font-semibold text-sm">Update Daily Routines</h4>
                    <p className="text-xs text-gray-400">Log study hours and exercise progress</p>
                  </div>
                  <CheckCircle2 className="h-5 w-5 text-blue-400" />
                </a>

                <a href="/ai-coach" className="w-full flex items-center justify-between p-4 bg-white/5 border border-white/5 rounded-2xl hover:border-purple-500/30 hover:bg-white/10 transition-all text-left">
                  <div>
                    <h4 className="font-semibold text-sm">Consult AI Coach</h4>
                    <p className="text-xs text-gray-400">Generate high-efficiency exam routine</p>
                  </div>
                  <Sparkles className="h-5 w-5 text-purple-400 animate-pulse" />
                </a>
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>
  );
};

export default Dashboard;
