import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Calendar, Clock, MapPin, Users, Bell, RefreshCw, Tag, Wifi } from 'lucide-react';
import { format } from 'date-fns';
import { COLOR_PALETTE, CATEGORY_ICONS } from '../../services/calendarService';

const RECURRENCE_OPTIONS = [
  { value: '', label: 'Does not repeat' },
  { value: 'RRULE:FREQ=DAILY', label: 'Every day' },
  { value: 'RRULE:FREQ=WEEKLY', label: 'Every week' },
  { value: 'RRULE:FREQ=WEEKLY;BYDAY=MO,WE,FR', label: 'Mon, Wed, Fri' },
  { value: 'RRULE:FREQ=MONTHLY', label: 'Every month' },
];

const CATEGORIES = ['study', 'work', 'exercise', 'personal', 'meeting', 'break'];

const AddEventModal = ({ isOpen, onClose, onSave, initialDate, initialEvent }) => {
  const isEdit = !!initialEvent;
  const defaultStart = initialDate ? format(new Date(initialDate), "yyyy-MM-dd'T'HH:mm") : format(new Date(), "yyyy-MM-dd'T'HH:mm");
  const defaultEnd = initialDate
    ? format(new Date(new Date(initialDate).getTime() + 60 * 60000), "yyyy-MM-dd'T'HH:mm")
    : format(new Date(Date.now() + 60 * 60000), "yyyy-MM-dd'T'HH:mm");

  const [form, setForm] = useState({
    title: '',
    description: '',
    start: defaultStart,
    end: defaultEnd,
    color: 'blue',
    category: 'personal',
    location: '',
    attendees: '',
    recurrence: '',
    reminders: 10,
    syncToGoogle: false,
    allDay: false,
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (initialEvent) {
      setForm({
        title: initialEvent.title || '',
        description: initialEvent.description || '',
        start: initialEvent.start ? format(new Date(initialEvent.start), "yyyy-MM-dd'T'HH:mm") : defaultStart,
        end: initialEvent.end ? format(new Date(initialEvent.end), "yyyy-MM-dd'T'HH:mm") : defaultEnd,
        color: initialEvent.colorKey || 'blue',
        category: initialEvent.category || 'personal',
        location: initialEvent.location || '',
        attendees: (initialEvent.attendees || []).join(', '),
        recurrence: (initialEvent.recurrence || [])[0] || '',
        reminders: (initialEvent.reminders || [10])[0] || 10,
        syncToGoogle: initialEvent.syncedToGoogle || false,
        allDay: initialEvent.allDay || false,
      });
    } else if (initialDate) {
      setForm(f => ({
        ...f,
        start: format(new Date(initialDate), "yyyy-MM-dd'T'HH:mm"),
        end: format(new Date(new Date(initialDate).getTime() + 60 * 60000), "yyyy-MM-dd'T'HH:mm"),
      }));
    }
  }, [initialEvent, initialDate]);

  const set = (key, val) => setForm(f => ({ ...f, [key]: val }));

  const handleSave = async () => {
    if (!form.title.trim()) { setError('Title is required'); return; }
    if (!form.start || !form.end) { setError('Start and end times are required'); return; }
    setSaving(true); setError('');
    try {
      await onSave({
        title: form.title.trim(),
        description: form.description,
        start: new Date(form.start).toISOString(),
        end: new Date(form.end).toISOString(),
        color: form.color,
        category: form.category,
        location: form.location,
        attendees: form.attendees ? form.attendees.split(',').map(e => e.trim()).filter(Boolean) : [],
        recurrence: form.recurrence ? [form.recurrence] : [],
        reminders: [Number(form.reminders)],
        syncToGoogle: form.syncToGoogle,
        allDay: form.allDay,
        ...(isEdit ? { id: initialEvent.id } : {}),
      });
      onClose();
    } catch (e) {
      setError(e.message || 'Failed to save event');
    } finally {
      setSaving(false);
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
            className="w-full max-w-lg rounded-3xl overflow-hidden"
            style={{
              background: 'linear-gradient(145deg, #0d1126, #111827)',
              border: '1px solid rgba(139,92,246,0.3)',
              boxShadow: '0 0 60px rgba(139,92,246,0.15), 0 25px 50px rgba(0,0,0,0.5)',
            }}
          >
            {/* Header */}
            <div
              className="px-6 pt-6 pb-4 flex items-center justify-between"
              style={{ borderBottom: '1px solid rgba(255,255,255,0.06)' }}
            >
              <div className="flex items-center gap-3">
                <div
                  className="w-9 h-9 rounded-xl flex items-center justify-center"
                  style={{ background: `${COLOR_PALETTE[form.color]?.hex}20`, border: `1px solid ${COLOR_PALETTE[form.color]?.hex}40` }}
                >
                  <Calendar className="w-4 h-4" style={{ color: COLOR_PALETTE[form.color]?.hex }} />
                </div>
                <h2 className="text-lg font-bold text-white">
                  {isEdit ? 'Edit Event' : 'New Event'}
                </h2>
              </div>
              <button onClick={onClose} className="p-2 rounded-xl hover:bg-white/5 text-gray-400 hover:text-white transition-colors">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="px-6 py-5 space-y-4 max-h-[70vh] overflow-y-auto custom-scrollbar">
              {error && (
                <div className="p-3 rounded-xl text-sm text-red-400" style={{ background: 'rgba(239,68,68,0.1)', border: '1px solid rgba(239,68,68,0.2)' }}>
                  {error}
                </div>
              )}

              {/* Title */}
              <div>
                <input
                  type="text"
                  placeholder="Event title..."
                  value={form.title}
                  onChange={e => set('title', e.target.value)}
                  className="w-full bg-transparent text-xl font-semibold text-white placeholder-gray-600 border-none outline-none"
                  style={{ borderBottom: '1px solid rgba(255,255,255,0.08)', paddingBottom: '8px' }}
                />
              </div>

              {/* Date / Time */}
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-xs text-gray-500 font-medium flex items-center gap-1"><Clock className="w-3 h-3" />Start</label>
                  <input
                    type="datetime-local"
                    value={form.start}
                    onChange={e => set('start', e.target.value)}
                    className="w-full text-sm text-white rounded-xl px-3 py-2.5 outline-none"
                    style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.08)', colorScheme: 'dark' }}
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-xs text-gray-500 font-medium flex items-center gap-1"><Clock className="w-3 h-3" />End</label>
                  <input
                    type="datetime-local"
                    value={form.end}
                    onChange={e => set('end', e.target.value)}
                    className="w-full text-sm text-white rounded-xl px-3 py-2.5 outline-none"
                    style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.08)', colorScheme: 'dark' }}
                  />
                </div>
              </div>

              {/* Color picker */}
              <div className="space-y-2">
                <label className="text-xs text-gray-500 font-medium flex items-center gap-1"><Tag className="w-3 h-3" />Color</label>
                <div className="flex gap-2 flex-wrap">
                  {Object.entries(COLOR_PALETTE).map(([key, { hex, glow, label }]) => (
                    <motion.button
                      key={key}
                      whileHover={{ scale: 1.15 }}
                      whileTap={{ scale: 0.9 }}
                      onClick={() => set('color', key)}
                      title={label}
                      className="w-7 h-7 rounded-full relative"
                      style={{
                        background: hex,
                        boxShadow: form.color === key ? `0 0 12px ${glow}, 0 0 20px ${glow}` : 'none',
                        border: form.color === key ? '2px solid white' : '2px solid transparent',
                      }}
                    />
                  ))}
                </div>
              </div>

              {/* Category */}
              <div className="space-y-2">
                <label className="text-xs text-gray-500 font-medium">Category</label>
                <div className="flex gap-2 flex-wrap">
                  {CATEGORIES.map(cat => (
                    <button
                      key={cat}
                      onClick={() => set('category', cat)}
                      className="px-3 py-1.5 rounded-xl text-xs font-medium capitalize transition-all"
                      style={{
                        background: form.category === cat ? 'rgba(139,92,246,0.3)' : 'rgba(255,255,255,0.05)',
                        border: `1px solid ${form.category === cat ? 'rgba(139,92,246,0.5)' : 'rgba(255,255,255,0.08)'}`,
                        color: form.category === cat ? '#C4B5FD' : '#9CA3AF',
                      }}
                    >
                      {CATEGORY_ICONS[cat]} {cat}
                    </button>
                  ))}
                </div>
              </div>

              {/* Description */}
              <div className="space-y-1">
                <textarea
                  placeholder="Add description..."
                  value={form.description}
                  onChange={e => set('description', e.target.value)}
                  rows={2}
                  className="w-full text-sm text-gray-300 placeholder-gray-600 rounded-xl px-3 py-2.5 outline-none resize-none"
                  style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.07)' }}
                />
              </div>

              {/* Location + Attendees */}
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-xs text-gray-500 font-medium flex items-center gap-1"><MapPin className="w-3 h-3" />Location</label>
                  <input
                    type="text"
                    placeholder="Add location..."
                    value={form.location}
                    onChange={e => set('location', e.target.value)}
                    className="w-full text-sm text-gray-300 placeholder-gray-600 rounded-xl px-3 py-2.5 outline-none"
                    style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.07)' }}
                  />
                </div>
                <div className="space-y-1">
                  <label className="text-xs text-gray-500 font-medium flex items-center gap-1"><Users className="w-3 h-3" />Attendees</label>
                  <input
                    type="text"
                    placeholder="email1, email2..."
                    value={form.attendees}
                    onChange={e => set('attendees', e.target.value)}
                    className="w-full text-sm text-gray-300 placeholder-gray-600 rounded-xl px-3 py-2.5 outline-none"
                    style={{ background: 'rgba(255,255,255,0.04)', border: '1px solid rgba(255,255,255,0.07)' }}
                  />
                </div>
              </div>

              {/* Recurrence + Reminder */}
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-xs text-gray-500 font-medium flex items-center gap-1"><RefreshCw className="w-3 h-3" />Repeat</label>
                  <select
                    value={form.recurrence}
                    onChange={e => set('recurrence', e.target.value)}
                    className="w-full text-sm text-gray-300 rounded-xl px-3 py-2.5 outline-none"
                    style={{ background: '#1a2035', border: '1px solid rgba(255,255,255,0.07)' }}
                  >
                    {RECURRENCE_OPTIONS.map(o => (
                      <option key={o.value} value={o.value}>{o.label}</option>
                    ))}
                  </select>
                </div>
                <div className="space-y-1">
                  <label className="text-xs text-gray-500 font-medium flex items-center gap-1"><Bell className="w-3 h-3" />Reminder</label>
                  <select
                    value={form.reminders}
                    onChange={e => set('reminders', Number(e.target.value))}
                    className="w-full text-sm text-gray-300 rounded-xl px-3 py-2.5 outline-none"
                    style={{ background: '#1a2035', border: '1px solid rgba(255,255,255,0.07)' }}
                  >
                    {[5, 10, 15, 30, 60, 120].map(m => (
                      <option key={m} value={m}>{m < 60 ? `${m} min` : `${m / 60}h`} before</option>
                    ))}
                  </select>
                </div>
              </div>

              {/* Sync to Google toggle */}
              <div
                className="flex items-center justify-between p-3 rounded-xl cursor-pointer"
                style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid rgba(255,255,255,0.06)' }}
                onClick={() => set('syncToGoogle', !form.syncToGoogle)}
              >
                <div className="flex items-center gap-2">
                  <Wifi className="w-4 h-4 text-blue-400" />
                  <span className="text-sm text-gray-300">Sync to Google Calendar</span>
                </div>
                <div
                  className="w-10 h-5 rounded-full relative transition-all duration-300"
                  style={{ background: form.syncToGoogle ? 'linear-gradient(90deg, #3B82F6, #8B5CF6)' : 'rgba(255,255,255,0.1)' }}
                >
                  <motion.div
                    animate={{ x: form.syncToGoogle ? 20 : 2 }}
                    className="absolute top-0.5 w-4 h-4 rounded-full bg-white"
                    transition={{ type: 'spring', stiffness: 500, damping: 30 }}
                  />
                </div>
              </div>
            </div>

            {/* Footer */}
            <div
              className="px-6 py-4 flex gap-3"
              style={{ borderTop: '1px solid rgba(255,255,255,0.06)' }}
            >
              <button
                onClick={onClose}
                className="flex-1 py-3 rounded-xl text-sm font-semibold text-gray-400 hover:text-white transition-colors"
                style={{ background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.08)' }}
              >
                Cancel
              </button>
              <motion.button
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                onClick={handleSave}
                disabled={saving}
                className="flex-1 py-3 rounded-xl text-sm font-semibold text-white disabled:opacity-50 transition-all"
                style={{
                  background: 'linear-gradient(135deg, #3B82F6, #8B5CF6)',
                  boxShadow: '0 0 20px rgba(139,92,246,0.4)',
                }}
              >
                {saving ? 'Saving...' : isEdit ? 'Update Event' : 'Create Event'}
              </motion.button>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};

export default AddEventModal;
