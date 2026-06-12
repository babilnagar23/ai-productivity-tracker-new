import React, { useState, useEffect, useRef, useCallback } from 'react';
import AppLayout from '../components/layout/AppLayout';
import Button from '../components/ui/Button';
import Badge from '../components/ui/Badge';
import ProgressRing from '../components/ui/ProgressRing';
import StatCard from '../components/ui/StatCard';
import { focusApi } from '../services/api';
import {
  Timer, Play, Pause, Square, RotateCcw, Clock,
  Target, Trophy, Zap, Plus, History
} from 'lucide-react';
import { format, parseISO } from 'date-fns';

const PRESETS = [
  { label: '25m Pomodoro', minutes: 25, color: '#3B82F6' },
  { label: '10m Break', minutes: 10, color: '#10B981' },
  { label: '60m Flow', minutes: 60, color: '#8B5CF6' },
  { label: '90m Deep', minutes: 90, color: '#F59E0B' },
];

function pad(n) { return String(n).padStart(2, '0'); }

export default function Focus() {
  const [mode, setMode] = useState('pomodoro'); // 'pomodoro' | 'stopwatch'
  const [duration, setDuration] = useState(25 * 60); // seconds
  const [remaining, setRemaining] = useState(25 * 60);
  const [elapsed, setElapsed] = useState(0);
  const [running, setRunning] = useState(false);
  const [label, setLabel] = useState('Focus Session');
  const [sessions, setSessions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [sessionStart, setSessionStart] = useState(null);
  const intervalRef = useRef(null);

  const fetchSessions = useCallback(async () => {
    try {
      const res = await focusApi.list();
      const data = res?.data || res?.results || res || [];
      setSessions(Array.isArray(data) ? data.slice(0, 20) : []);
    } catch { /* silent */ } finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchSessions(); }, [fetchSessions]);

  useEffect(() => {
    if (running) {
      intervalRef.current = setInterval(() => {
        if (mode === 'pomodoro') {
          setRemaining(r => {
            if (r <= 1) {
              clearInterval(intervalRef.current);
              setRunning(false);
              handleSessionEnd(duration);
              return 0;
            }
            return r - 1;
          });
        } else {
          setElapsed(e => e + 1);
        }
      }, 1000);
    }
    return () => clearInterval(intervalRef.current);
  }, [running, mode]);

  const handleStart = () => {
    setSessionStart(new Date());
    setRunning(true);
  };

  const handlePause = () => setRunning(false);

  const handleReset = () => {
    setRunning(false);
    clearInterval(intervalRef.current);
    setRemaining(duration);
    setElapsed(0);
    setSessionStart(null);
  };

  const handleSessionEnd = async (durationMins) => {
    setSaving(true);
    try {
      await focusApi.create({
        label,
        duration_minutes: Math.round(durationMins / 60),
        session_type: mode === 'pomodoro' ? 'pomodoro' : 'stopwatch',
        start_time: sessionStart?.toISOString() || new Date().toISOString(),
        end_time: new Date().toISOString(),
        completed: true,
      });
      fetchSessions();
    } catch { /* silent */ } finally { setSaving(false); }
  };

  const handleStop = async () => {
    setRunning(false);
    clearInterval(intervalRef.current);
    const mins = mode === 'pomodoro' ? Math.round((duration - remaining) / 60) : Math.round(elapsed / 60);
    if (mins > 0 && sessionStart) {
      await handleSessionEnd(mins * 60);
    }
    handleReset();
  };

  const setPreset = (p) => {
    setRunning(false);
    setDuration(p.minutes * 60);
    setRemaining(p.minutes * 60);
    setElapsed(0);
    setSessionStart(null);
    setMode('pomodoro');
  };

  // Stats
  const todayStr = new Date().toISOString().split('T')[0];
  const todaySessions = sessions.filter(s => (s.created_at || s.start_time || '').startsWith(todayStr));
  const todayMins = todaySessions.reduce((s, x) => s + (x.duration_minutes || 0), 0);
  const totalMins = sessions.reduce((s, x) => s + (x.duration_minutes || 0), 0);
  const pct = mode === 'pomodoro' ? ((duration - remaining) / duration) * 100 : 0;

  const displayTime = mode === 'pomodoro'
    ? `${pad(Math.floor(remaining / 60))}:${pad(remaining % 60)}`
    : `${pad(Math.floor(elapsed / 3600))}:${pad(Math.floor(elapsed / 60) % 60)}:${pad(elapsed % 60)}`;

  const ringColor = running ? '#3B82F6' : remaining === 0 ? '#10B981' : '#3B82F6';

  return (
    <AppLayout title="Focus">
      <div className="max-w-4xl mx-auto space-y-6 animate-fadeInUp">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-hero font-extrabold text-white flex items-center gap-2">
              <Timer className="w-5 h-5 text-plasma" /> Focus Timer
            </h1>
            <p className="text-xs text-gray-400 mt-0.5">Deep work sessions · Pomodoro & Stopwatch</p>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <StatCard label="Today" value={`${todayMins}m`} sub={`${todaySessions.length} sessions`} icon={Zap} color="#3B82F6" gradient="from-blue-500/5" />
          <StatCard label="Total" value={`${Math.floor(totalMins / 60)}h`} sub="All time focus" icon={Clock} color="#8B5CF6" gradient="from-purple-500/5" />
          <StatCard label="Sessions" value={sessions.length} sub="Completed" icon={Trophy} color="#F59E0B" gradient="from-orange-500/5" />
          <StatCard label="Avg Session" value={sessions.length ? `${Math.round(totalMins / sessions.length)}m` : '0m'} sub="Per session" icon={Target} color="#10B981" gradient="from-green-500/5" />
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
          {/* Timer */}
          <div className="lg:col-span-3 glass card-3d p-8 flex flex-col items-center gap-6">
            {/* Mode toggle */}
            <div className="flex gap-1 p-1 bg-white/5 rounded-xl border border-white/5">
              {['pomodoro', 'stopwatch'].map(m => (
                <button
                  key={m}
                  onClick={() => { setMode(m); handleReset(); }}
                  className={`px-4 py-2 rounded-lg text-xs font-bold transition-all
                    ${mode === m ? 'bg-cyan/20 text-cyan border border-cyan/30' : 'text-gray-500 hover:text-white'}`}
                >
                  {m === 'pomodoro' ? '🍅 Pomodoro' : '⏱ Stopwatch'}
                </button>
              ))}
            </div>

            {/* Session label */}
            <input
              className="bg-white/4 border border-white/10 rounded-xl px-4 py-2.5 text-sm text-center text-white w-full max-w-xs placeholder-gray-500 focus:outline-none focus:border-cyan/50 transition-colors"
              placeholder="Session label..."
              value={label}
              onChange={e => setLabel(e.target.value)}
              disabled={running}
            />

            {/* Timer ring */}
            <ProgressRing
              value={mode === 'pomodoro' ? pct : elapsed}
              max={mode === 'pomodoro' ? 100 : 3600}
              size={200}
              strokeWidth={10}
              color={ringColor}
            >
              <div className="text-center">
                <p className="text-4xl font-black text-white font-mono tracking-widest">{displayTime}</p>
                <p className="text-xs text-gray-500 mt-1">{running ? 'In progress…' : 'Ready'}</p>
              </div>
            </ProgressRing>

            {/* Controls */}
            <div className="flex items-center gap-3">
              <button
                onClick={handleReset}
                className="p-3 rounded-xl bg-white/5 border border-white/5 text-gray-400 hover:text-white hover:bg-white/10 transition-all"
                title="Reset"
              >
                <RotateCcw className="w-5 h-5" />
              </button>

              <button
                onClick={running ? handlePause : handleStart}
                className={`p-4 rounded-2xl transition-all font-bold shadow-lg ${running
                  ? 'bg-orange-500/20 border border-orange-500/30 text-orange-400 hover:bg-orange-500/30'
                  : 'bg-cyan text-black shadow-glow-cyan hover:opacity-90'
                }`}
              >
                {running ? <Pause className="w-6 h-6" /> : <Play className="w-6 h-6" />}
              </button>

              <button
                onClick={handleStop}
                className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 hover:bg-rose-500/20 transition-all"
                title="Stop & Save"
              >
                <Square className="w-5 h-5" />
              </button>
            </div>

            {/* Presets */}
            <div className="w-full">
              <p className="text-xs text-gray-500 text-center mb-2">Quick presets</p>
              <div className="grid grid-cols-4 gap-2">
                {PRESETS.map(p => (
                  <button
                    key={p.label}
                    onClick={() => setPreset(p)}
                    disabled={running}
                    className="py-2 px-1 rounded-xl bg-white/4 border border-white/5 text-xs font-semibold text-gray-400 hover:text-white hover:bg-white/8 transition-all disabled:opacity-40"
                  >
                    {p.label}
                  </button>
                ))}
              </div>
            </div>
          </div>

          {/* History */}
          <div className="lg:col-span-2 glass card-3d p-5">
            <h3 className="font-bold text-white text-sm flex items-center gap-2 mb-4">
              <History className="w-4 h-4 text-gray-400" /> Recent Sessions
            </h3>
            {loading ? (
              <div className="space-y-2">{[1,2,3,4].map(i => <div key={i} className="h-12 rounded-lg bg-white/3 animate-shimmer" />)}</div>
            ) : sessions.length === 0 ? (
              <p className="text-xs text-gray-500 text-center py-8">No sessions yet. Start focusing!</p>
            ) : (
              <div className="space-y-2 max-h-96 overflow-y-auto">
                {sessions.map((s, i) => (
                  <div key={s.id || i} className="flex items-center gap-3 p-3 rounded-xl bg-white/3 hover:bg-white/5 transition-colors">
                    <div className={`w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 ${s.session_type === 'pomodoro' ? 'bg-blue-500/15' : 'bg-purple-500/15'}`}>
                      <Timer className={`w-4 h-4 ${s.session_type === 'pomodoro' ? 'text-blue-400' : 'text-purple-400'}`} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-xs font-semibold text-white truncate">{s.label || 'Focus Session'}</p>
                      <p className="text-[10px] text-gray-500">{s.duration_minutes || 0}m · {s.created_at ? format(parseISO(s.created_at), 'MMM d, h:mm a') : ''}</p>
                    </div>
                    <Badge variant={s.completed ? 'green' : 'gray'} size="xs">{s.completed ? '✓' : '—'}</Badge>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </AppLayout>
  );
}
