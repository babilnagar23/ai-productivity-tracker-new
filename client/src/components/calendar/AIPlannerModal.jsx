import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Sparkles, X, Loader2, ArrowRight, Calendar, Info } from 'lucide-react';
import { generateAISchedule, applyAISchedule } from '../../services/calendarService';
import { format, parseISO } from 'date-fns';
import { COLOR_PALETTE, CATEGORY_ICONS } from '../../services/calendarService';

const AIPlannerModal = ({ isOpen, onClose, onScheduleApplied }) => {
  const [prompt, setPrompt] = useState('');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState(null);
  const [applying, setApplying] = useState(false);
  const [error, setError] = useState('');
  const [syncToGoogle, setSyncToGoogle] = useState(true);

  const handleGenerate = async () => {
    if (!prompt.trim()) return;
    setLoading(true);
    setError('');
    setResult(null);
    try {
      const res = await generateAISchedule(prompt);
      if (res.success) {
        setResult(res);
      } else {
        setError(res.error || 'Failed to generate schedule.');
      }
    } catch (e) {
      setError(e.message || 'An error occurred during generation.');
    } finally {
      setLoading(false);
    }
  };

  const handleApply = async () => {
    if (!result || !result.scheduleId) return;
    setApplying(true);
    setError('');
    try {
      const res = await applyAISchedule(result.scheduleId, syncToGoogle);
      if (res.success) {
        onScheduleApplied();
        onClose();
        // Reset state after closing
        setTimeout(() => {
          setPrompt('');
          setResult(null);
        }, 500);
      } else {
        setError(res.error || 'Failed to apply schedule.');
      }
    } catch (e) {
      setError(e.message || 'An error occurred while applying the schedule.');
    } finally {
      setApplying(false);
    }
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          className="fixed inset-0 z-50 flex items-center justify-center p-4"
          style={{ background: 'rgba(0,0,0,0.7)', backdropFilter: 'blur(8px)' }}
          onClick={(e) => e.target === e.currentTarget && onClose()}
        >
          <motion.div
            initial={{ opacity: 0, scale: 0.9, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.9, y: 20 }}
            transition={{ type: 'spring', stiffness: 300, damping: 25 }}
            className="w-full max-w-2xl rounded-3xl overflow-hidden flex flex-col max-h-[85vh]"
            style={{
              background: 'linear-gradient(145deg, #0d1126, #111827)',
              border: '1px solid rgba(139,92,246,0.3)',
              boxShadow: '0 0 60px rgba(139,92,246,0.15), 0 25px 50px rgba(0,0,0,0.5)',
            }}
          >
            {/* Header */}
            <div className="px-6 pt-6 pb-4 flex items-center justify-between" style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}>
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl flex items-center justify-center bg-purple-500/20 border border-purple-500/40">
                  <Sparkles className="w-5 h-5 text-purple-400" />
                </div>
                <div>
                  <h2 className="text-xl font-bold text-white leading-tight">AI Planner</h2>
                  <p className="text-xs text-purple-300">Powered by Gemini Intelligence</p>
                </div>
              </div>
              <button onClick={onClose} className="p-2 rounded-xl hover:bg-white/5 text-gray-400 hover:text-white transition-colors">
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Body */}
            <div className="flex-1 overflow-y-auto custom-scrollbar px-6 py-5 space-y-6">
              
              {/* Input Area */}
              <div className="space-y-3">
                <label className="text-sm font-semibold text-gray-300">What do you want to plan?</label>
                <div className="relative">
                  <textarea
                    value={prompt}
                    onChange={(e) => setPrompt(e.target.value)}
                    placeholder="e.g., 'I have a DSA exam in 10 days. Generate a 7-day preparation plan balancing study, exercise, and breaks...'"
                    className="w-full bg-white/5 border border-white/10 rounded-2xl p-4 text-white placeholder-gray-500 resize-none outline-none focus:border-purple-500/50 transition-colors"
                    rows={3}
                  />
                  {!result && !loading && (
                    <motion.button
                      whileHover={{ scale: 1.05 }}
                      whileTap={{ scale: 0.95 }}
                      onClick={handleGenerate}
                      disabled={!prompt.trim()}
                      className="absolute bottom-3 right-3 px-4 py-2 rounded-xl text-sm font-semibold text-white flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                      style={{ background: 'linear-gradient(135deg, #8B5CF6, #EC4899)' }}
                    >
                      Generate <ArrowRight className="w-4 h-4" />
                    </motion.button>
                  )}
                </div>
              </div>

              {error && (
                <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/20 flex items-start gap-3">
                  <Info className="w-5 h-5 text-red-400 mt-0.5" />
                  <p className="text-sm text-red-300">{error}</p>
                </div>
              )}

              {loading && (
                <div className="flex flex-col items-center justify-center py-10 space-y-4">
                  <motion.div animate={{ rotate: 360 }} transition={{ repeat: Infinity, duration: 1.5, ease: 'linear' }}>
                    <Loader2 className="w-10 h-10 text-purple-500" />
                  </motion.div>
                  <p className="text-sm text-purple-300 animate-pulse">Analyzing schedule & optimizing routines...</p>
                </div>
              )}

              {/* Results Area */}
              {result && !loading && (
                <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} className="space-y-6">
                  <div className="p-5 rounded-2xl bg-white/5 border border-purple-500/30 space-y-3">
                    <h3 className="text-lg font-bold text-white">{result.planTitle}</h3>
                    <p className="text-sm text-gray-300 leading-relaxed">{result.planSummary}</p>
                    
                    {result.insights && result.insights.length > 0 && (
                      <div className="pt-3 flex flex-wrap gap-2">
                        {result.insights.map((insight, idx) => (
                          <span key={idx} className="px-3 py-1 text-xs rounded-full bg-purple-500/20 text-purple-300 border border-purple-500/30">
                             {insight}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>

                  <div className="space-y-3">
                    <h4 className="text-sm font-semibold text-gray-300 flex items-center gap-2">
                      <Calendar className="w-4 h-4 text-purple-400" />
                      Generated Sessions ({result.events.length})
                    </h4>
                    <div className="grid gap-3">
                      {result.events.map((evt, i) => {
                        const palette = COLOR_PALETTE[evt.color] || COLOR_PALETTE.purple;
                        const icon = CATEGORY_ICONS[evt.category] || CATEGORY_ICONS.study;
                        return (
                          <div key={i} className="flex items-stretch rounded-xl overflow-hidden bg-white/5 border border-white/10 relative">
                            <div className="w-2" style={{ background: palette.hex }} />
                            <div className="p-3 flex-1 flex items-center justify-between">
                              <div>
                                <div className="flex items-center gap-2 mb-1">
                                  <span className="text-xs">{icon}</span>
                                  <span className="text-[10px] font-bold uppercase tracking-wider" style={{ color: palette.hex }}>
                                    {evt.category}
                                  </span>
                                  <span className="text-[10px] text-gray-500">
                                    • {evt.date} • {evt.startTime} - {evt.endTime}
                                  </span>
                                </div>
                                <h5 className="text-sm font-semibold text-white">{evt.title}</h5>
                              </div>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                </motion.div>
              )}
            </div>

            {/* Footer */}
            {result && !loading && (
              <div className="px-6 py-4 border-t border-white/10 flex items-center justify-between bg-black/20">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={syncToGoogle}
                    onChange={(e) => setSyncToGoogle(e.target.checked)}
                    className="w-4 h-4 rounded text-purple-500 bg-white/10 border-white/20 focus:ring-purple-500 focus:ring-offset-gray-900"
                  />
                  <span className="text-sm text-gray-300">Sync to Google Calendar</span>
                </label>
                
                <div className="flex gap-3">
                  <button onClick={() => setResult(null)} className="px-4 py-2 rounded-xl text-sm font-semibold text-gray-400 hover:text-white transition-colors">
                    Discard
                  </button>
                  <motion.button
                    whileHover={{ scale: 1.05 }}
                    whileTap={{ scale: 0.95 }}
                    onClick={handleApply}
                    disabled={applying}
                    className="px-6 py-2 rounded-xl text-sm font-semibold text-white shadow-lg disabled:opacity-50"
                    style={{ background: 'linear-gradient(135deg, #3B82F6, #8B5CF6)', boxShadow: '0 0 20px rgba(139,92,246,0.4)' }}
                  >
                    {applying ? 'Applying...' : 'Apply Schedule'}
                  </motion.button>
                </div>
              </div>
            )}
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};

export default AIPlannerModal;
