import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { apiFetch } from '../services/api';
import {
  ClipboardList, X, ArrowRight, CheckCircle2,
  Clock, Zap, Calendar, SkipForward
} from 'lucide-react';

const today = () => {
  const date = new Date();
  date.setMinutes(date.getMinutes() - date.getTimezoneOffset());
  return date.toISOString().split('T')[0];
};

const DailyLogPopup = ({ onClose, onLogged }) => {
  const { user, refreshUser } = useAuth();
  const navigate = useNavigate();

  const config = user?.customConfig || {
    coreChecklists: [
      { id: 'study',    title: 'Study session completed',  description: 'Main focus agenda' },
      { id: 'exercise', title: 'Exercise completed',        description: 'Cardio / Workout' },
      { id: 'ml',       title: 'AI / ML learning',          description: 'Dev & coding' }
    ],
    coreMetrics: [
      { id: 'studyHours',  title: 'Study Hours' },
      { id: 'mobileUsage', title: 'Mobile Usage (Hrs)' }
    ]
  };

  // Form state
  const [coreChecks, setCoreChecks]   = useState(() => {
    const init = {};
    config.coreChecklists.forEach(c => { init[c.id] = false; });
    return init;
  });
  const [coreMetrics, setCoreMetrics] = useState(() => {
    const init = {};
    config.coreMetrics.forEach(m => { init[m.id] = 0; });
    return init;
  });
  const [sleepTime, setSleepTime]     = useState('23:00');
  const [wakeTime,  setWakeTime]      = useState('07:00');
  const [notes,     setNotes]         = useState('');
  const [submitting, setSubmitting]   = useState(false);
  const [error, setError]             = useState('');
  const [step, setStep]               = useState(1); // 1 = prompt, 2 = form

  const todayStr = new Date().toLocaleDateString(undefined, {
    weekday: 'long', month: 'long', day: 'numeric'
  });

  const handleQuickLog = async () => {
    setSubmitting(true);
    setError('');
    try {
      const payload = {
        date:           today(),
        coreChecklists: coreChecks,
        coreMetrics,
        sleepTime,
        wakeTime,
        notes,
        customLogs:     []
      };
      const res = await apiFetch('/routines', {
        method: 'POST',
        body:   JSON.stringify(payload)
      });
      if (res.success) {
        await refreshUser();
        onLogged?.();
        onClose();
      }
    } catch (err) {
      if (err.message?.includes('already exists')) {
        // Entry already exists — just close, don't block user
        onLogged?.();
        onClose();
      } else {
        setError(err.message || 'Failed to log. Please try again.');
      }
    } finally {
      setSubmitting(false);
    }
  };

  const completedCount = Object.values(coreChecks).filter(Boolean).length;
  const totalCount     = config.coreChecklists.length;

  return (
    /* Backdrop */
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4"
         style={{ background: 'rgba(5, 8, 22, 0.85)', backdropFilter: 'blur(8px)' }}>

      {/* Modal */}
      <div className="glass-card border border-white/10 w-full max-w-lg animate-fadeIn overflow-hidden shadow-2xl">

        {/* Gradient top bar */}
        <div className="h-1 w-full bg-gradient-to-r from-blue-500 via-purple-500 to-pink-500" />

        {/* ── Step 1: Prompt ── */}
        {step === 1 && (
          <div className="p-8 space-y-6">
            {/* Header */}
            <div className="flex justify-between items-start">
              <div className="flex items-center gap-3">
                <div className="p-2.5 bg-blue-500/15 rounded-2xl border border-blue-500/20">
                  <ClipboardList className="h-6 w-6 text-blue-400" />
                </div>
                <div>
                  <h2 className="text-xl font-extrabold text-white">Daily Check-In</h2>
                  <p className="text-xs text-gray-400">{todayStr}</p>
                </div>
              </div>
              <button
                onClick={onClose}
                className="p-2 text-gray-500 hover:text-white hover:bg-white/10 rounded-xl transition"
                title="Skip for now"
              >
                <X className="h-4 w-4" />
              </button>
            </div>

            {/* Greeting */}
            <div className="bg-gradient-to-r from-blue-500/10 to-purple-500/10 border border-blue-500/15 rounded-2xl p-5 space-y-1">
              <p className="text-sm font-semibold text-white">
                👋 Hey {user?.name?.split(' ')[0] || 'there'}!
              </p>
              <p className="text-sm text-gray-300 leading-relaxed">
                You haven't logged today's entry yet. It only takes a minute —
                track your progress and keep your streak alive!
              </p>
            </div>

            {/* ── Static customization summary ── */}
            <div className="grid grid-cols-2 gap-4">
              {/* Core Checklists */}
              <div className="bg-white/4 border border-white/8 rounded-2xl p-4 space-y-3">
                <p className="text-[10px] uppercase font-black text-blue-400 tracking-wider">
                  Core Checklists
                </p>
                <div className="space-y-2">
                  {config.coreChecklists.length === 0 ? (
                    <p className="text-[11px] text-gray-500 italic">None configured</p>
                  ) : (
                    config.coreChecklists.map(chk => (
                      <div key={chk.id} className="flex items-start gap-2">
                        <span className="text-green-400 text-xs mt-px font-bold">✓</span>
                        <span className="text-xs text-gray-200 font-medium leading-snug">
                          {chk.title}
                        </span>
                      </div>
                    ))
                  )}
                </div>
              </div>

              {/* Core Metrics */}
              <div className="bg-white/4 border border-white/8 rounded-2xl p-4 space-y-3">
                <p className="text-[10px] uppercase font-black text-purple-400 tracking-wider">
                  Core Metrics
                </p>
                <div className="space-y-2">
                  {config.coreMetrics.length === 0 ? (
                    <p className="text-[11px] text-gray-500 italic">None configured</p>
                  ) : (
                    config.coreMetrics.map(met => (
                      <div key={met.id} className="flex items-start gap-2">
                        <span className="text-xs mt-px">📊</span>
                        <span className="text-xs text-gray-200 font-medium leading-snug">
                          {met.title}
                        </span>
                      </div>
                    ))
                  )}
                </div>
              </div>
            </div>

            {/* Actions */}
            <div className="flex flex-col sm:flex-row gap-3">
              <button
                onClick={() => setStep(2)}
                className="flex-1 flex items-center justify-center gap-2 px-5 py-3.5 rounded-xl
                           bg-gradient-to-r from-blue-600 to-purple-600 font-bold text-sm
                           hover:opacity-90 transition-all shadow-neon"
              >
                <Zap className="h-4 w-4" />
                Log Today's Entry
                <ArrowRight className="h-4 w-4" />
              </button>
              <button
                onClick={onClose}
                className="flex items-center justify-center gap-2 px-5 py-3.5 rounded-xl
                           bg-white/5 border border-white/10 text-gray-400 font-semibold text-sm
                           hover:bg-white/10 hover:text-white transition"
              >
                <SkipForward className="h-4 w-4" />
                Skip for Now
              </button>
            </div>

            <p className="text-center text-[10px] text-gray-600">
              Skipping will remind you again next time you open the dashboard today.
            </p>
          </div>
        )}

        {/* ── Step 2: Quick-log form ── */}
        {step === 2 && (
          <div className="p-8 space-y-5 max-h-[85vh] overflow-y-auto">
            {/* Header */}
            <div className="flex justify-between items-center border-b border-white/5 pb-4">
              <div>
                <h2 className="text-lg font-extrabold text-white">Quick Log — Today</h2>
                <p className="text-xs text-gray-400 flex items-center gap-1 mt-0.5">
                  <Calendar className="h-3 w-3" /> {todayStr}
                </p>
              </div>
              <button onClick={() => setStep(1)}
                      className="text-xs text-gray-400 hover:text-white bg-white/5 px-3 py-1.5 rounded-lg transition">
                ← Back
              </button>
            </div>

            {/* Progress bar */}
            {totalCount > 0 && (
              <div className="space-y-1.5">
                <div className="flex justify-between text-[10px] text-gray-500">
                  <span>{completedCount}/{totalCount} habits checked</span>
                  <span>{Math.round((completedCount / totalCount) * 100)}%</span>
                </div>
                <div className="h-1.5 w-full bg-white/5 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-gradient-to-r from-blue-500 to-purple-500 rounded-full transition-all duration-500"
                    style={{ width: `${totalCount > 0 ? (completedCount / totalCount) * 100 : 0}%` }}
                  />
                </div>
              </div>
            )}

            {/* Core Checklists */}
            {config.coreChecklists.length > 0 && (
              <div className="space-y-2">
                <p className="text-[10px] uppercase font-bold text-gray-500 tracking-wider">
                  Habits
                </p>
                {config.coreChecklists.map(chk => (
                  <label key={chk.id}
                         className={`flex items-center gap-3 p-4 rounded-2xl cursor-pointer transition-all select-none border ${
                           coreChecks[chk.id]
                             ? 'bg-green-500/10 border-green-500/20'
                             : 'bg-white/4 border-white/5 hover:border-white/15'
                         }`}>
                    <div className={`h-5 w-5 rounded-lg border-2 flex items-center justify-center flex-shrink-0 transition-all ${
                      coreChecks[chk.id]
                        ? 'bg-green-500 border-green-500'
                        : 'border-white/20 bg-white/5'
                    }`}>
                      {coreChecks[chk.id] && <CheckCircle2 className="h-3.5 w-3.5 text-white" />}
                    </div>
                    <input
                      type="checkbox"
                      className="sr-only"
                      checked={coreChecks[chk.id] || false}
                      onChange={e => setCoreChecks({ ...coreChecks, [chk.id]: e.target.checked })}
                    />
                    <div>
                      <span className={`font-semibold text-sm block ${coreChecks[chk.id] ? 'text-green-300' : 'text-gray-200'}`}>
                        {chk.title}
                      </span>
                      {chk.description && (
                        <span className="text-[10px] text-gray-500">{chk.description}</span>
                      )}
                    </div>
                  </label>
                ))}
              </div>
            )}

            {/* Core Metrics */}
            {config.coreMetrics.length > 0 && (
              <div className="space-y-3">
                <p className="text-[10px] uppercase font-bold text-gray-500 tracking-wider">
                  Metrics
                </p>
                <div className="grid grid-cols-2 gap-3">
                  {config.coreMetrics.map(met => (
                    <div key={met.id} className="space-y-1.5">
                      <label className="text-xs font-semibold text-gray-400">{met.title}</label>
                      <input
                        type="number"
                        step="0.5"
                        min="0"
                        max="24"
                        value={coreMetrics[met.id] || ''}
                        onChange={e => setCoreMetrics({ ...coreMetrics, [met.id]: Number(e.target.value) })}
                        className="w-full px-3 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white
                                   focus:outline-none focus:border-blue-500 transition text-sm"
                      />
                    </div>
                  ))}
                </div>
              </div>
            )}

            {/* Sleep / Wake */}
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-gray-400 flex items-center gap-1">
                  <Clock className="h-3 w-3" /> Sleep Time
                </label>
                <input
                  type="time"
                  value={sleepTime}
                  onChange={e => setSleepTime(e.target.value)}
                  className="w-full px-3 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white
                             focus:outline-none focus:border-blue-500 transition text-sm"
                />
              </div>
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-gray-400 flex items-center gap-1">
                  <Clock className="h-3 w-3" /> Wake Time
                </label>
                <input
                  type="time"
                  value={wakeTime}
                  onChange={e => setWakeTime(e.target.value)}
                  className="w-full px-3 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white
                             focus:outline-none focus:border-blue-500 transition text-sm"
                />
              </div>
            </div>

            {/* Notes */}
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-400">Notes (optional)</label>
              <textarea
                value={notes}
                onChange={e => setNotes(e.target.value)}
                placeholder="Quick reflection on today..."
                rows="2"
                className="w-full px-3 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white
                           focus:outline-none focus:border-blue-500 transition text-sm resize-none"
              />
            </div>

            {/* Error */}
            {error && (
              <div className="bg-red-500/10 border border-red-500/20 text-red-400 px-4 py-3 rounded-xl text-xs">
                {error}
              </div>
            )}

            {/* Submit actions */}
            <div className="flex gap-3 pt-1">
              <button
                onClick={handleQuickLog}
                disabled={submitting}
                className="flex-1 flex items-center justify-center gap-2 px-5 py-3.5 rounded-xl
                           bg-gradient-to-r from-blue-600 to-purple-600 font-bold text-sm
                           hover:opacity-90 transition disabled:opacity-50 shadow-neon"
              >
                {submitting ? (
                  <><span className="h-4 w-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                  Saving...</>
                ) : (
                  <><CheckCircle2 className="h-4 w-4" /> Save Log Entry</>
                )}
              </button>
              <button
                onClick={onClose}
                className="px-5 py-3.5 rounded-xl bg-white/5 border border-white/10 text-gray-400
                           font-semibold text-sm hover:bg-white/10 hover:text-white transition"
              >
                Skip
              </button>
            </div>

            <p className="text-center text-[10px] text-gray-600 pb-1">
              You can always edit or add more details in Daily Routines.
            </p>
          </div>
        )}
      </div>
    </div>
  );
};

export default DailyLogPopup;
