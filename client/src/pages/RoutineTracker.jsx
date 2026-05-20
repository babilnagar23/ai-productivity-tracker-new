import React, { useState, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { apiFetch } from '../services/api';
import Navbar from '../components/Navbar';
import Sidebar from '../components/Sidebar';
import { useAuth } from '../context/AuthContext';
import { 
  Plus, 
  Trash2, 
  Edit2,
  BookOpen, 
  Activity, 
  Smartphone, 
  Clock, 
  FileText,
  CheckSquare,
  X
} from 'lucide-react';

const localToday = () => {
  const date = new Date();
  date.setMinutes(date.getMinutes() - date.getTimezoneOffset());
  return date.toISOString().split('T')[0];
};

const RoutineTracker = () => {
  const { user, refreshUser } = useAuth();
  const location = useLocation();
  const [routines, setRoutines] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [formError, setFormError] = useState('');       // inline form error
  const [duplicateId, setDuplicateId] = useState(null); // existing entry id on duplicate
  const [deleteError, setDeleteError] = useState('');

  // Custom configurations configuration fallback
  const config = user?.customConfig || {
    coreChecklists: [
      { id: 'study', title: 'Core Study session completed', description: 'Main focus agenda checklist' },
      { id: 'exercise', title: 'Exercise completed', description: 'Cardio / Gym / Workout routine' },
      { id: 'ml', title: 'AI / ML learning tracker', description: 'Dev sessions & coding milestones' }
    ],
    coreMetrics: [
      { id: 'studyHours', title: 'Study Duration (Hrs)' },
      { id: 'mobileUsage', title: 'Mobile Usage (Hrs)' }
    ],
    deletedHistory: []
  };

  // Form states mapping dynamically to configs
  const [coreChecklistsState, setCoreChecklistsState] = useState({});
  const [coreMetricsState, setCoreMetricsState] = useState({});
  const [sleepTime, setSleepTime] = useState('23:00');
  const [wakeTime, setWakeTime] = useState('07:00');
  const [notes, setNotes] = useState('');
  const [date, setDate] = useState(localToday());

  // Custom logs dynamic list
  const [customLogs, setCustomLogs] = useState([]);
  const [newCustomLogTitle, setNewCustomLogTitle] = useState('');

  const fetchRoutines = async () => {
    try {
      const res = await apiFetch('/routines');
      if (res.success) {
        setRoutines(res.data);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  // Initialize form state fields based on configuration
  const initializeFormFields = () => {
    const initialChecklists = {};
    config.coreChecklists.forEach(chk => {
      initialChecklists[chk.id] = false;
    });
    setCoreChecklistsState(initialChecklists);

    const initialMetrics = {};
    config.coreMetrics.forEach(met => {
      initialMetrics[met.id] = 0;
    });
    setCoreMetricsState(initialMetrics);
  };

  useEffect(() => {
    fetchRoutines();
  }, []);

  useEffect(() => {
    if (user?.customConfig) {
      initializeFormFields();
    }
  }, [user]);

  // Auto-open edit mode when navigated from Analytics table
  useEffect(() => {
    if (location.state?.editId && routines.length > 0) {
      const target = routines.find(r => (r._id || r.id) === location.state.editId);
      if (target) {
        handleEditInit(target);
        // Clear state so navigating back doesn't re-trigger
        window.history.replaceState({}, '');
      }
    }
  }, [location.state, routines]);

  const handleAddCustomLog = (e) => {
    e.preventDefault();
    if (!newCustomLogTitle.trim()) return;
    setCustomLogs([...customLogs, { title: newCustomLogTitle.trim(), completed: false }]);
    setNewCustomLogTitle('');
  };

  const handleToggleCustomLog = (index) => {
    const updated = [...customLogs];
    updated[index].completed = !updated[index].completed;
    setCustomLogs(updated);
  };

  const handleRemoveCustomLog = (index) => {
    setCustomLogs(customLogs.filter((_, i) => i !== index));
  };

  const resetForm = () => {
    initializeFormFields();
    setNotes('');
    setCustomLogs([]);
    setEditingId(null);
    setFormError('');
    setDuplicateId(null);
    setDate(localToday());
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setFormError('');
    setDuplicateId(null);
    try {
      const payload = {
        date,
        coreChecklists: coreChecklistsState,
        coreMetrics: coreMetricsState,
        sleepTime,
        wakeTime,
        notes,
        customLogs
      };

      let res;
      if (editingId) {
        res = await apiFetch(`/routines/${editingId}`, {
          method: 'PUT',
          body: JSON.stringify(payload)
        });
      } else {
        res = await apiFetch('/routines', {
          method: 'POST',
          body: JSON.stringify(payload)
        });
      }

      if (res.success) {
        resetForm();
        setShowForm(false);
        fetchRoutines();
        refreshUser();
      }
    } catch (err) {
      // Handle 409 duplicate date
      if (err.message?.includes('already exists') || err.existingId) {
        setFormError('A log entry already exists for this date. You can edit the existing one instead.');
        // Try parse existingId from error if API sent it back
        const match = err.message?.match(/existingId[":\s]+([a-f0-9]{24})/i);
        if (match) setDuplicateId(match[1]);
      } else {
        setFormError(err.message || 'Error saving routine. Please try again.');
      }
    }
  };

  const handleEditInit = (item) => {
    setEditingId(item.id || item._id);
    setDate(new Date(item.date).toISOString().split('T')[0]);
    
    const itemChecklists = item.coreChecklists || {};
    const itemMetrics = item.coreMetrics || {};

    const initialChecklists = {};
    config.coreChecklists.forEach(chk => {
      initialChecklists[chk.id] = itemChecklists[chk.id] || false;
    });
    setCoreChecklistsState(initialChecklists);

    const initialMetrics = {};
    config.coreMetrics.forEach(met => {
      initialMetrics[met.id] = itemMetrics[met.id] || 0;
    });
    setCoreMetricsState(initialMetrics);

    setSleepTime(item.sleepTime || '23:00');
    setWakeTime(item.wakeTime || '07:00');
    setNotes(item.notes || '');
    setCustomLogs(item.customLogs || []);
    setShowForm(true);

    // Scroll form into view smoothly
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleDelete = async (id) => {
    if (!confirm('Are you sure you want to remove this log?')) return;
    setDeleteError('');
    try {
      const res = await apiFetch(`/routines/${id}`, { method: 'DELETE' });
      if (res.success) {
        fetchRoutines();
        refreshUser();
      }
    } catch (err) {
      setDeleteError(err.message || 'Failed to delete. Please try again.');
      setTimeout(() => setDeleteError(''), 4000);
    }
  };

  return (
    <div className="flex bg-background min-h-screen text-white">
      <Sidebar />
      <div className="flex-1 flex flex-col overflow-y-auto">
        <Navbar />

        <main className="p-8 space-y-8 flex-1">
          {/* Header */}
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-3xl font-extrabold tracking-tight">Daily Routines</h1>
              <p className="text-sm text-gray-400">Chronicle metrics to monitor habits consistency and daily goals.</p>
            </div>
            
            <button
              onClick={() => {
                if (showForm) resetForm();
                setShowForm(!showForm);
              }}
              className="flex items-center gap-2 px-5 py-3 rounded-xl bg-gradient-to-r from-blue-600 to-purple-600 font-semibold text-sm shadow-neon hover:opacity-90 transition-all duration-300"
            >
              <Plus className="h-4 w-4" /> {showForm ? 'Close Entry' : 'Log New Day'}
            </button>
          </div>

          {/* Delete error toast */}
          {deleteError && (
            <div className="flex items-center gap-3 bg-red-500/10 border border-red-500/20 text-red-400 px-4 py-3 rounded-2xl text-sm animate-fadeIn">
              <span className="flex-1">{deleteError}</span>
            </div>
          )}

          {/* New Entry Form */}
          {showForm && (
            <form onSubmit={handleSubmit} className="glass-card p-8 border border-white/10 space-y-6 animate-fadeIn">
              <div className="flex justify-between items-center border-b border-white/5 pb-4">
                <h3 className="text-xl font-bold text-gradient">
                  {editingId ? 'Update Daily Log Entry' : 'Create Daily Log Entry'}
                </h3>
                {editingId && (
                  <button 
                    type="button" 
                    onClick={resetForm}
                    className="text-xs text-gray-400 hover:text-white flex items-center gap-1 bg-white/5 px-3 py-1.5 rounded-lg transition"
                  >
                    Cancel Edit
                  </button>
                )}
              </div>
              
              {/* Form error banner */}
              {formError && (
                <div className="bg-red-500/10 border border-red-500/20 text-red-300 px-4 py-3 rounded-xl text-sm flex items-start gap-3 animate-fadeIn">
                  <span className="flex-1 leading-relaxed">{formError}</span>
                  {duplicateId && (
                    <button
                      type="button"
                      onClick={() => {
                        const existing = routines.find(r => (r._id || r.id) === duplicateId);
                        if (existing) { handleEditInit(existing); setFormError(''); }
                      }}
                      className="shrink-0 px-3 py-1.5 bg-blue-500/20 border border-blue-500/30 text-blue-400 text-xs font-bold rounded-lg hover:bg-blue-500/30 transition"
                    >
                      Edit Existing
                    </button>
                  )}
                </div>
              )}

              <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                {/* Date Selection */}
                <div className="space-y-2">
                  <label className="text-xs uppercase font-bold text-gray-400">Target Date</label>
                  <input
                    type="date"
                    required
                    value={date}
                    onChange={(e) => setDate(e.target.value)}
                    className="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white focus:outline-none focus:border-blue-500 transition-all text-sm"
                  />
                </div>

                {/* Core Metrics Fields rendering dynamically */}
                {config.coreMetrics.map((met) => (
                  <div key={met.id} className="space-y-2">
                    <label className="text-xs uppercase font-bold text-gray-400">{met.title}</label>
                    <input
                      type="number"
                      step="0.5"
                      min="0"
                      max="24"
                      value={coreMetricsState[met.id] || ''}
                      onChange={(e) => setCoreMetricsState({
                        ...coreMetricsState,
                        [met.id]: Number(e.target.value)
                      })}
                      className="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white focus:outline-none focus:border-blue-500 transition-all text-sm"
                    />
                  </div>
                ))}
              </div>

              {/* Predefined checklogs rendering dynamically */}
              <div className="space-y-2 pt-2">
                <label className="text-xs uppercase font-bold text-gray-400 block">Core Checklists</label>
                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                  {config.coreChecklists.length === 0 ? (
                    <div className="col-span-3 text-xs text-gray-500 italic py-2">
                      No active checklists configured. Go to 'Customization' to add variables!
                    </div>
                  ) : (
                    config.coreChecklists.map((chk) => (
                      <label key={chk.id} className="flex items-center gap-3 p-4 bg-white/5 border border-white/5 rounded-2xl cursor-pointer hover:border-blue-500/20 transition-all select-none">
                        <input
                          type="checkbox"
                          checked={coreChecklistsState[chk.id] || false}
                          onChange={(e) => setCoreChecklistsState({
                            ...coreChecklistsState,
                            [chk.id]: e.target.checked
                          })}
                          className="h-5 w-5 rounded bg-white/5 border-white/10 text-blue-500 focus:ring-0 focus:ring-offset-0"
                        />
                        <div>
                          <span className="font-semibold text-sm block">{chk.title}</span>
                          <span className="text-[10px] text-gray-400">{chk.description}</span>
                        </div>
                      </label>
                    ))
                  )}
                </div>
              </div>

              {/* Dynamic Custom Logs Segment */}
              <div className="space-y-4 pt-2 border-t border-white/5">
                <div className="flex justify-between items-center">
                  <label className="text-xs uppercase font-bold text-gray-400 block">Custom Checklists</label>
                  <span className="text-[10px] text-gray-500">Add operational operators custom milestones</span>
                </div>

                {/* Add Custom Log Input */}
                <div className="flex gap-3">
                  <input
                    type="text"
                    placeholder="e.g. Completed System Refactoring, Water intake metrics..."
                    value={newCustomLogTitle}
                    onChange={(e) => setNewCustomLogTitle(e.target.value)}
                    className="flex-1 px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white focus:outline-none focus:border-blue-500 transition-all text-sm"
                  />
                  <button
                    type="button"
                    onClick={handleAddCustomLog}
                    className="px-5 py-3 rounded-xl bg-blue-500/10 border border-blue-500/20 text-blue-400 font-semibold text-xs hover:bg-blue-500/20 transition"
                  >
                    Add Custom Checkbox
                  </button>
                </div>

                {/* Custom Checklist entries list */}
                {customLogs.length > 0 && (
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-2">
                    {customLogs.map((log, index) => (
                      <div key={index} className="flex justify-between items-center p-3 bg-white/5 border border-white/5 rounded-xl">
                        <label className="flex items-center gap-3 cursor-pointer select-none flex-1">
                          <input
                            type="checkbox"
                            checked={log.completed}
                            onChange={() => handleToggleCustomLog(index)}
                            className="h-4 w-4 rounded bg-white/5 border-white/10 text-blue-500 focus:ring-0 focus:ring-offset-0"
                          />
                          <span className="text-sm font-medium text-gray-200">{log.title}</span>
                        </label>
                        <button
                          type="button"
                          onClick={() => handleRemoveCustomLog(index)}
                          className="text-gray-400 hover:text-red-400 transition p-1"
                        >
                          <X className="h-4 w-4" />
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Sleep & Wake Times */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pt-2 border-t border-white/5">
                <div className="space-y-2">
                  <label className="text-xs uppercase font-bold text-gray-400">Sleep Time</label>
                  <input
                    type="time"
                    value={sleepTime}
                    onChange={(e) => setSleepTime(e.target.value)}
                    className="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white focus:outline-none focus:border-blue-500 transition-all text-sm"
                  />
                </div>

                <div className="space-y-2">
                  <label className="text-xs uppercase font-bold text-gray-400">Wake Time</label>
                  <input
                    type="time"
                    value={wakeTime}
                    onChange={(e) => setWakeTime(e.target.value)}
                    className="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white focus:outline-none focus:border-blue-500 transition-all text-sm"
                  />
                </div>
              </div>

              {/* Notes */}
              <div className="space-y-2">
                <label className="text-xs uppercase font-bold text-gray-400">Daily Reflection & Notes</label>
                <textarea
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="Today went exceptionally well..."
                  rows="3"
                  className="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white focus:outline-none focus:border-blue-500 transition-all text-sm resize-none"
                ></textarea>
              </div>

              <div className="flex gap-4">
                <button
                  type="submit"
                  className="px-6 py-3.5 rounded-xl bg-gradient-to-r from-blue-600 to-purple-600 font-semibold text-sm shadow-neon hover:opacity-90 transition-all"
                >
                  {editingId ? 'Update Entry' : 'Log Entry'}
                </button>
                {editingId && (
                  <button
                    type="button"
                    onClick={resetForm}
                    className="px-6 py-3.5 rounded-xl bg-white/5 border border-white/10 font-semibold text-sm hover:bg-white/10 transition-all"
                  >
                    Cancel
                  </button>
                )}
              </div>
            </form>
          )}

          {/* Routine list grid */}
          <div className="space-y-4">
            <h3 className="font-bold text-xl text-white">Chronological logs</h3>

            {loading ? (
              <div className="text-center py-12 text-gray-400">Retrieving operational logs...</div>
            ) : routines.length === 0 ? (
              <div className="text-center py-12 text-gray-400 bg-white/5 border border-white/5 rounded-2xl">
                No logs recorded yet. Initialize routine tracking using the 'Log New Day' CTA above.
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {routines.map((item) => (
                  <div key={item.id || item._id} className="glass-card p-6 flex flex-col justify-between border border-white/5 relative overflow-hidden group">
                    {/* Score badge */}
                    <div className="absolute top-4 right-4 bg-blue-500/10 border border-blue-500/20 px-3 py-1 rounded-full text-xs font-bold text-blue-400">
                      Productivity: {item.productivityScore}%
                    </div>

                    <div className="space-y-4">
                      {/* Date header */}
                      <div>
                        <h4 className="font-bold text-lg text-white">
                          {new Date(item.date).toLocaleDateString(undefined, { 
                            weekday: 'short', 
                            year: 'numeric', 
                            month: 'short', 
                            day: 'numeric' 
                          })}
                        </h4>
                        <span className="text-[10px] text-gray-400">ID: {item.id || item._id}</span>
                      </div>

                      {/* Dynamic Core checklists status row inside card */}
                      <div className="flex flex-wrap gap-2.5">
                        {config.coreChecklists.map((chk) => {
                          const isCompleted = item.coreChecklists?.[chk.id] || false;
                          return (
                            <div 
                              key={chk.id} 
                              className={`px-3 py-1.5 rounded-xl flex items-center gap-1.5 text-xs font-semibold ${
                                isCompleted ? 'bg-green-500/10 text-green-400 border border-green-500/10' : 'bg-white/5 text-gray-500'
                              }`}
                            >
                              {isCompleted ? '✓' : '✗'} {chk.title.split(' ')[0]}
                            </div>
                          );
                        })}
                      </div>

                      {/* Custom checklist logs rendering inside card */}
                      {item.customLogs && item.customLogs.length > 0 && (
                        <div className="space-y-1.5">
                          <span className="text-[10px] uppercase font-bold text-gray-500 block">Custom Checklists Logged:</span>
                          <div className="flex flex-wrap gap-2">
                            {item.customLogs.map((log, idx) => (
                              <span 
                                key={idx} 
                                className={`px-2.5 py-1.5 rounded-lg text-xs flex items-center gap-1 ${
                                  log.completed 
                                    ? 'bg-blue-500/10 text-blue-400 border border-blue-500/20' 
                                    : 'bg-white/5 text-gray-400 border border-white/5'
                                }`}
                              >
                                {log.completed ? '✓' : '✗'} {log.title}
                              </span>
                            ))}
                          </div>
                        </div>
                      )}

                      {/* Dynamic Numeric metrics layout inside card */}
                      <div className="grid grid-cols-3 gap-2 bg-white/5 p-3 rounded-xl text-center text-xs">
                        {config.coreMetrics.slice(0, 2).map((met) => (
                          <div key={met.id}>
                            <span className="block text-gray-400 truncate">{met.title}</span>
                            <span className="font-bold">{item.coreMetrics?.[met.id] || 0} hrs</span>
                          </div>
                        ))}
                        <div>
                          <span className="block text-gray-400">Sleep Schedule</span>
                          <span className="font-bold">{item.sleepTime} - {item.wakeTime}</span>
                        </div>
                      </div>

                      {/* Notes reflection */}
                      {item.notes && (
                        <p className="text-xs text-gray-400 border-l border-white/10 pl-2 leading-relaxed italic">
                          "{item.notes}"
                        </p>
                      )}
                    </div>

                    <div className="mt-6 pt-4 border-t border-white/5 flex justify-end gap-3">
                      <button
                        onClick={() => handleEditInit(item)}
                        className="flex items-center gap-1.5 text-xs text-blue-400 hover:text-blue-300 transition-colors px-3 py-2 rounded-lg bg-blue-500/5 hover:bg-blue-500/10 border border-blue-500/10"
                      >
                        <Edit2 className="h-3.5 w-3.5" /> Edit Log
                      </button>
                      
                      <button
                        onClick={() => handleDelete(item.id || item._id)}
                        className="flex items-center gap-1.5 text-xs text-red-400 hover:text-red-300 transition-colors px-3 py-2 rounded-lg bg-red-500/5 hover:bg-red-500/10 border border-red-500/10"
                      >
                        <Trash2 className="h-3.5 w-3.5" /> Delete Log
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </main>
      </div>
    </div>
  );
};

export default RoutineTracker;
