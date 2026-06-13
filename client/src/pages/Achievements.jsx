import  { useState, useEffect, useCallback } from 'react';
import AppLayout from '../components/layout/AppLayout';
import Badge from '../components/ui/Badge';
import EmptyState from '../components/ui/EmptyState';
import { achievementsApi } from '../services/api';
import { Trophy, Lock, Star, Flame, Timer, RotateCcw, CheckSquare } from 'lucide-react';

const CATEGORY_ICONS = { focus: Timer, routine: RotateCcw, tasks: CheckSquare, streak: Flame, general: Star };
const CATEGORY_COLORS = { focus: '#8B5CF6', routine: '#14B8A6', tasks: '#3B82F6', streak: '#F59E0B', general: '#10B981' };

export default function Achievements() {
  const [achievements, setAchievements] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');

  const fetchAchievements = useCallback(async () => {
    try {
      const res = await achievementsApi.list();
      const data = res?.data || res?.results || res || [];
      setAchievements(Array.isArray(data) ? data : []);
    } catch { /* silent */ } finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchAchievements(); }, [fetchAchievements]);

  const earned = achievements.filter(a => a.earned || a.completed);
  const total = achievements.length;
  const pct = total ? Math.round((earned.length / total) * 100) : 0;

  const categories = ['all', ...new Set(achievements.map(a => a.category).filter(Boolean))];
  const filtered = achievements.filter(a => filter === 'all' || a.category === filter);

  return (
    <AppLayout title="Achievements">
      <div className="max-w-4xl mx-auto space-y-6 animate-fadeInUp">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-hero font-extrabold text-white flex items-center gap-2">
              <Trophy className="w-5 h-5 text-yellow-400" /> Achievements
            </h1>
            <p className="text-xs text-gray-400 mt-0.5">{earned.length} of {total} unlocked · {pct}% complete</p>
          </div>
        </div>

        {/* Progress */}
        <div className="glass card-3d p-6 flex flex-col sm:flex-row items-center gap-6">
          <div className="relative w-28 h-28 flex-shrink-0">
            <svg viewBox="0 0 120 120" className="w-full h-full -rotate-90">
              <circle cx="60" cy="60" r="50" fill="none" stroke="rgba(255,255,255,0.05)" strokeWidth="10" />
              <circle cx="60" cy="60" r="50" fill="none" stroke="url(#achievGrad)" strokeWidth="10"
                strokeLinecap="round"
                strokeDasharray={`${2 * Math.PI * 50}`}
                strokeDashoffset={`${2 * Math.PI * 50 * (1 - pct / 100)}`}
                className="transition-all duration-700" />
              <defs>
                <linearGradient id="achievGrad" x1="0%" y1="0%" x2="100%" y2="0%">
                  <stop offset="0%" stopColor="#F59E0B" />
                  <stop offset="100%" stopColor="#EF4444" />
                </linearGradient>
              </defs>
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center">
              <span className="text-2xl font-black text-white">{pct}%</span>
              <span className="text-[9px] text-gray-500">Complete</span>
            </div>
          </div>
          <div className="flex-1 space-y-3">
            <h2 className="text-lg font-bold text-white">Achievement Progress</h2>
            <div className="grid grid-cols-2 gap-3">
              <div className="bg-white/4 border border-white/5 rounded-xl p-3 text-center">
                <p className="text-xl font-black text-yellow-400">{earned.length}</p>
                <p className="text-xs text-gray-500">Unlocked</p>
              </div>
              <div className="bg-white/4 border border-white/5 rounded-xl p-3 text-center">
                <p className="text-xl font-black text-gray-400">{total - earned.length}</p>
                <p className="text-xs text-gray-500">Remaining</p>
              </div>
            </div>
          </div>
        </div>

        {/* Category filter */}
        <div className="flex gap-1.5 flex-wrap glass card-3d p-2">
          {categories.map(c => (
            <button key={c}
              onClick={() => setFilter(c)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold capitalize transition-all
                ${filter === c ? 'bg-yellow-500/20 text-yellow-300 border border-yellow-500/30' : 'text-gray-400 hover:text-white hover:bg-white/5'}`}>
              {c}
            </button>
          ))}
        </div>

        {/* Achievement grid */}
        {loading ? (
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
            {Array.from({length:6}).map((_,i) => <div key={i} className="h-36 rounded-xl bg-white/3 animate-shimmer" />)}
          </div>
        ) : filtered.length === 0 ? (
          <EmptyState icon={Trophy} title="No achievements yet" description="Start completing tasks and building streaks!" />
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
            {filtered.map((a, i) => {
              const isEarned = a.earned || a.completed;
              const CatIcon = CATEGORY_ICONS[a.category] || Star;
              const catColor = CATEGORY_COLORS[a.category] || '#10B981';
              const progress = a.progress || 0;
              const goal = a.goal || 1;
              const pctDone = Math.min(Math.round((progress / goal) * 100), 100);

              return (
                <div key={a.id || i}
                  className={`glass card-3d p-4 text-center space-y-3
                    ${isEarned ? 'border-yellow-500/20 shadow-glow-cyan' : 'opacity-60'}`}>

                  <div className={`w-14 h-14 rounded-2xl flex items-center justify-center mx-auto
                    ${isEarned ? 'animate-float' : ''}`}
                    style={{ background: isEarned ? `${catColor}20` : 'rgba(255,255,255,0.04)' }}>
                    {isEarned
                      ? <CatIcon className="w-7 h-7" style={{ color: catColor }} />
                      : <Lock className="w-6 h-6 text-gray-600" />
                    }
                  </div>

                  <div>
                    <p className={`text-sm font-bold ${isEarned ? 'text-white' : 'text-gray-500'}`}>{a.name || a.title}</p>
                    <p className="text-[10px] text-gray-500 mt-0.5">{a.description}</p>
                  </div>

                  {!isEarned && progress > 0 && (
                    <div className="space-y-1">
                      <div className="h-1 rounded-full bg-white/5 overflow-hidden">
                        <div className="h-full rounded-full bg-yellow-500/50" style={{ width: `${pctDone}%` }} />
                      </div>
                      <p className="text-[9px] text-gray-500">{progress}/{goal}</p>
                    </div>
                  )}

                  {isEarned && (
                    <Badge variant="yellow" size="xs">✓ Unlocked</Badge>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </div>
    </AppLayout>
  );
}
