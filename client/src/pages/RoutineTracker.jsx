import React, { useState, useEffect, useMemo } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { apiFetch } from '../services/api';
import Navbar from '../components/Navbar';
import Sidebar from '../components/Sidebar';
import { useAuth } from '../context/AuthContext';
import { 
  Plus, 
  Trash2, 
  Edit2,
  X,
  Settings,
  ChevronLeft,
  ChevronRight,
  CheckCircle2,
  Calendar as CalendarIcon,
  BarChart2
} from 'lucide-react';
import { 
  format, 
  addMonths, 
  subMonths, 
  startOfMonth, 
  endOfMonth, 
  startOfWeek, 
  endOfWeek, 
  isSameMonth, 
  isSameDay, 
  addDays, 
  parseISO,
  isToday
} from 'date-fns';
import Modal from '../components/ui/Modal';

const localTodayStr = () => {
  const date = new Date();
  date.setMinutes(date.getMinutes() - date.getTimezoneOffset());
  return date.toISOString().split('T')[0];
};

const RoutineTracker = () => {
  const { user, refreshUser } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const [routines, setRoutines] = useState([]);
  const [loading, setLoading] = useState(true);
  
  // New States for UI
  const [currentMonth, setCurrentMonth] = useState(new Date());
  const [selectedDate, setSelectedDate] = useState(new Date());
  
  // Form states
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [formError, setFormError] = useState('');
  const [duplicateId, setDuplicateId] = useState(null);
  const [deleteError, setDeleteError] = useState('');

  // Fallback Config
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

  const [coreChecklistsState, setCoreChecklistsState] = useState({});
  const [coreMetricsState, setCoreMetricsState] = useState({});
  const [sleepTime, setSleepTime] = useState('23:00');
  const [wakeTime, setWakeTime] = useState('07:00');
  const [notes, setNotes] = useState('');
  const [formDateStr, setFormDateStr] = useState(localTodayStr());
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

  const initializeFormFields = () => {
    const initialChecklists = {};
    config.coreChecklists.forEach(chk => { initialChecklists[chk.id] = false; });
    setCoreChecklistsState(initialChecklists);

    const initialMetrics = {};
    config.coreMetrics.forEach(met => { initialMetrics[met.id] = 0; });
    setCoreMetricsState(initialMetrics);
  };

  useEffect(() => { fetchRoutines(); }, []);
  useEffect(() => { if (user?.customConfig) initializeFormFields(); }, [user]);

  // Handle Edit passed by router state
  useEffect(() => {
    if (location.state?.editId && routines.length > 0) {
      const target = routines.find(r => (r._id || r.id) === location.state.editId);
      if (target) {
        handleEditInit(target);
        setSelectedDate(parseISO(target.date));
        setCurrentMonth(parseISO(target.date));
        window.history.replaceState({}, '');
      }
    }
  }, [location.state, routines]);

  // Derived state for the selected day
  const selectedDateStr = format(selectedDate, 'yyyy-MM-dd');
  const selectedRoutine = useMemo(() => {
    return routines.find(r => r.date.split('T')[0] === selectedDateStr);
  }, [routines, selectedDateStr]);

  const habitsCompletedCount = useMemo(() => {
    if (!selectedRoutine) return 0;
    let count = 0;
    config.coreChecklists.forEach(chk => {
      if (selectedRoutine.coreChecklists?.[chk.id]) count++;
    });
    if (selectedRoutine.customLogs) {
      selectedRoutine.customLogs.forEach(log => {
        if (log.completed) count++;
      });
    }
    return count;
  }, [selectedRoutine, config]);

  const totalHabitsCount = useMemo(() => {
    if (!selectedRoutine) return 0;
    return config.coreChecklists.length + (selectedRoutine.customLogs?.length || 0);
  }, [selectedRoutine, config]);

  // Form Handlers
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
    setFormDateStr(selectedDateStr);
  };

  const handleEditInit = (item) => {
    setEditingId(item.id || item._id);
    setFormDateStr(new Date(item.date).toISOString().split('T')[0]);
    
    const initialChecklists = {};
    config.coreChecklists.forEach(chk => {
      initialChecklists[chk.id] = item.coreChecklists?.[chk.id] || false;
    });
    setCoreChecklistsState(initialChecklists);

    const initialMetrics = {};
    config.coreMetrics.forEach(met => {
      initialMetrics[met.id] = item.coreMetrics?.[met.id] || 0;
    });
    setCoreMetricsState(initialMetrics);

    setSleepTime(item.sleepTime || '23:00');
    setWakeTime(item.wakeTime || '07:00');
    setNotes(item.notes || '');
    setCustomLogs(item.customLogs || []);
    setShowForm(true);
  };

  const openNewForm = () => {
    resetForm();
    setShowForm(true);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setFormError('');
    setDuplicateId(null);
    try {
      const payload = {
        date: formDateStr,
        coreChecklists: coreChecklistsState,
        coreMetrics: coreMetricsState,
        sleepTime,
        wakeTime,
        notes,
        customLogs
      };

      let res;
      if (editingId) {
        res = await apiFetch(`/routines/${editingId}`, { method: 'PUT', body: JSON.stringify(payload) });
      } else {
        res = await apiFetch('/routines', { method: 'POST', body: JSON.stringify(payload) });
      }

      if (res.success) {
        resetForm();
        setShowForm(false);
        fetchRoutines();
        refreshUser();
      }
    } catch (err) {
      if (err.message?.includes('already exists') || err.existingId) {
        setFormError('A log entry already exists for this date. You can edit the existing one instead.');
        const match = err.message?.match(/existingId[":\s]+([a-f0-9]{24})/i);
        if (match) setDuplicateId(match[1]);
      } else {
        setFormError(err.message || 'Error saving routine. Please try again.');
      }
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Are you sure you want to remove this log?')) return;
    setDeleteError('');
    try {
      const res = await apiFetch(`/routines/${id}`, { method: 'DELETE' });
      if (res.success) {
        fetchRoutines();
        refreshUser();
        setSelectedDate(new Date()); // reset selection
      }
    } catch (err) {
      setDeleteError(err.message || 'Failed to delete. Please try again.');
      setTimeout(() => setDeleteError(''), 4000);
    }
  };

  // Calendar render logic
  const renderCalendar = () => {
    const monthStart = startOfMonth(currentMonth);
    const monthEnd = endOfMonth(monthStart);
    const startDate = startOfWeek(monthStart, { weekStartsOn: 1 });
    const endDate = endOfWeek(monthEnd, { weekStartsOn: 1 });
    
    const rows = [];
    let days = [];
    let day = startDate;
    let formattedDate = '';
    
    while (day <= endDate) {
      for (let i = 0; i < 7; i++) {
        formattedDate = format(day, 'd');
        const cloneDay = day;
        const dateStr = format(day, 'yyyy-MM-dd');
        const hasLog = routines.some(r => r.date.split('T')[0] === dateStr);
        const isSelected = isSameDay(day, selectedDate);
        const isCurrentMonth = isSameMonth(day, monthStart);

        days.push(
          <div 
            key={day} 
            className={`flex flex-col items-center justify-center p-2 rounded-xl cursor-pointer transition-all ${
              !isCurrentMonth ? 'text-gray-600' : 'text-gray-300'
            } ${isSelected ? 'border border-[#14b8a6] bg-[#14b8a6]/10 shadow-[0_0_10px_rgba(20,184,166,0.2)] text-white' : 'hover:bg-white/5'}`}
            onClick={() => setSelectedDate(cloneDay)}
          >
            <span className="font-bold text-sm leading-none">{formattedDate}</span>
            <div className="h-2 w-2 mt-1 rounded-full flex items-center justify-center">
              {hasLog && <span className="h-1.5 w-1.5 bg-[#14b8a6] rounded-full"></span>}
            </div>
          </div>
        );
        day = addDays(day, 1);
      }
      rows.push(<div className="grid grid-cols-7 gap-1 mb-1" key={day}>{days}</div>);
      days = [];
    }
    return rows;
  };

  return (
    <div className="flex bg-void min-h-screen text-white font-body relative">
      <Sidebar />
      <div className="flex-1 flex flex-col h-screen overflow-hidden">
        <Navbar />

        {/* Top Action Bar matching mobile app */}
        <div className="flex justify-between items-center px-8 py-4 border-b border-smoke bg-carbon relative z-10">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-cyan/10 rounded-lg">
              <CalendarIcon className="w-5 h-5 text-cyan" />
            </div>
            <h1 className="text-xl font-hero font-extrabold tracking-tight text-white">Daily Log</h1>
          </div>
          <div className="flex items-center gap-4">
            <button 
              className="text-gray-400 hover:text-white transition p-2 hover:bg-white/5 rounded-lg"
              title="View Analytics"
              onClick={() => navigate('/analytics')}
            >
              <BarChart2 className="w-5 h-5" />
            </button>
            <button 
              className="text-gray-400 hover:text-white transition p-2 hover:bg-white/5 rounded-lg"
              title="Settings & Customization"
              onClick={() => navigate('/customization')}
            >
              <Settings className="w-5 h-5" />
            </button>
            <button 
              className="text-cyan hover:text-white transition p-2 hover:bg-cyan/10 rounded-lg"
              title="Add Log"
              onClick={openNewForm}
            >
              <Plus className="w-6 h-6" />
            </button>
          </div>
        </div>

        <main className="flex-1 overflow-y-auto p-8 bg-void relative z-10">
          {deleteError && (
            <div className="mb-4 bg-red-500/10 border border-red-500/20 text-red-400 px-4 py-3 rounded-xl text-sm max-w-4xl mx-auto">
              {deleteError}
            </div>
          )}

          <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 max-w-7xl mx-auto">
            {/* LEFT COLUMN: Calendar & Summary */}
            <div className="lg:col-span-5 space-y-6">
              
              <div className="flex justify-between items-center mb-4">
                <h2 className="text-xl font-hero font-extrabold text-white">Routine</h2>
                <div className="flex items-center gap-3">
                  <button onClick={() => { setSelectedDate(new Date()); setCurrentMonth(new Date()); }} className="text-sm font-bold text-cyan hover:text-white">Today</button>
                  <div className="flex items-center text-cyan font-bold gap-2">
                    <button onClick={() => setCurrentMonth(subMonths(currentMonth, 1))} className="hover:text-white"><ChevronLeft className="w-4 h-4" /></button>
                    <span className="text-sm min-w-[80px] text-center">{format(currentMonth, 'MMMM yyyy')}</span>
                    <button onClick={() => setCurrentMonth(addMonths(currentMonth, 1))} className="hover:text-white"><ChevronRight className="w-4 h-4" /></button>
                  </div>
                </div>
              </div>

              {/* Calendar Grid Card */}
              <div className="glass p-4 card-3d">
                <div className="grid grid-cols-7 gap-1 mb-2">
                  {['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'].map(day => (
                    <div key={day} className="text-center text-[10px] font-bold text-gray-500 tracking-wider">
                      {day}
                    </div>
                  ))}
                </div>
                {renderCalendar()}
              </div>

              {/* Summary Card below calendar */}
              <div className="glass p-5 flex items-center gap-4 card-3d">
                <div className={`flex-shrink-0 w-12 h-12 rounded-full flex items-center justify-center border-2 ${
                  selectedRoutine ? 'bg-cyan/10 border-cyan/30 text-cyan' : 'bg-carbon border-smoke text-gray-600'
                }`}>
                  <CheckCircle2 className="w-6 h-6" />
                </div>
                <div>
                  <h3 className="font-hero font-extrabold text-white">{format(selectedDate, 'EEEE, MMM d, yyyy')}</h3>
                  {selectedRoutine ? (
                    <p className="text-sm text-cyan font-bold">{habitsCompletedCount} of {totalHabitsCount} habits completed</p>
                  ) : (
                    <p className="text-sm text-gray-500 font-bold">No log for this date.</p>
                  )}
                </div>
              </div>

            </div>

            {/* RIGHT COLUMN: Habits & Metrics */}
            <div className="lg:col-span-7 space-y-8 pl-0 lg:pl-6">
              
              {!selectedRoutine ? (
                <div className="flex flex-col items-center justify-center h-full py-20 text-center">
                  <div className="w-20 h-20 bg-white/5 rounded-full flex items-center justify-center mb-4">
                    <CalendarIcon className="w-8 h-8 text-gray-600" />
                  </div>
                  <h3 className="text-xl font-bold text-gray-300 mb-2">No Routine Logged</h3>
                  <p className="text-gray-500 mb-6 text-sm max-w-sm">You haven't logged any habits or metrics for {format(selectedDate, 'MMMM d, yyyy')}. Start tracking your progress!</p>
                  <button 
                    onClick={openNewForm}
                    className="flex items-center gap-2 px-6 py-3 rounded-full bg-cyan/10 text-cyan font-bold hover:bg-cyan/20 transition-all border border-cyan/20"
                  >
                    <Plus className="w-4 h-4" /> Log Day Now
                  </button>
                </div>
              ) : (
                <div className="space-y-8 animate-fadeIn">
                  
                  {/* Actions Bar for the specific log */}
                  <div className="flex justify-between items-center glass p-3 border-smoke shadow-md">
                    <div className="px-3">
                      <span className="text-xs font-bold text-gray-500 uppercase tracking-widest">Entry Options</span>
                    </div>
                    <div className="flex gap-2">
                      <button onClick={() => handleEditInit(selectedRoutine)} className="px-4 py-2 bg-plasma/10 text-plasma hover:bg-plasma/20 rounded-xl text-xs font-bold flex items-center gap-2 transition">
                        <Edit2 className="w-3.5 h-3.5" /> Edit
                      </button>
                      <button onClick={() => handleDelete(selectedRoutine.id || selectedRoutine._id)} className="px-4 py-2 bg-red-500/10 text-red-400 hover:bg-red-500/20 rounded-xl text-xs font-bold flex items-center gap-2 transition">
                        <Trash2 className="w-3.5 h-3.5" /> Delete
                      </button>
                    </div>
                  </div>

                  {/* Active Habits Section */}
                  <div>
                    <h3 className="text-xl font-hero font-extrabold text-white mb-4">Active Habits</h3>
                    <div className="space-y-3">
                      {config.coreChecklists.map(chk => {
                        const isDone = selectedRoutine.coreChecklists?.[chk.id] || false;
                        return (
                          <div key={chk.id} className="glass card-3d p-4 flex items-center justify-between">
                            <div className="flex items-center gap-3">
                              <span className="h-2 w-2 rounded-full bg-cyan"></span>
                              <span className="font-bold text-white tracking-wide">{chk.title}</span>
                            </div>
                            <div className={`w-8 h-8 rounded-full border-2 flex items-center justify-center ${
                              isDone ? 'bg-cyan/10 border-cyan text-cyan' : 'border-smoke text-transparent'
                            }`}>
                              <CheckCircle2 className="w-5 h-5" />
                            </div>
                          </div>
                        );
                      })}
                      {/* Custom Habits mapped */}
                      {selectedRoutine.customLogs && selectedRoutine.customLogs.map((log, idx) => (
                        <div key={idx} className="glass card-3d p-4 flex items-center justify-between">
                          <div className="flex items-center gap-3">
                            <span className="h-2 w-2 rounded-full bg-plasma"></span>
                            <span className="font-bold text-white tracking-wide">{log.title}</span>
                          </div>
                          <div className={`w-8 h-8 rounded-full border-2 flex items-center justify-center ${
                            log.completed ? 'bg-cyan/10 border-cyan text-cyan' : 'border-smoke text-transparent'
                          }`}>
                            <CheckCircle2 className="w-5 h-5" />
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Metrics Section */}
                  <div>
                    <h3 className="text-xl font-hero font-extrabold text-white mb-4">Metrics</h3>
                    <div className="space-y-3">
                      {config.coreMetrics.map(met => {
                        const val = selectedRoutine.coreMetrics?.[met.id] || 0;
                        let unit = 'Pts';
                        if (met.title.toLowerCase().includes('hrs') || met.title.toLowerCase().includes('duration') || met.title.toLowerCase().includes('usage')) unit = 'Hrs';
                        if (met.title.toLowerCase().includes('water')) unit = 'L';
                        
                        return (
                          <div key={met.id} className="glass card-3d p-5">
                            <p className="text-xs font-bold text-gray-500 mb-1 uppercase tracking-widest">{met.title}</p>
                            <div className="flex items-baseline gap-1">
                              <span className="text-3xl font-hero font-extrabold text-white">{Number(val).toFixed(1)}</span>
                              <span className="text-sm font-bold text-cyan">{unit}</span>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>

                  {/* Sleep and Notes */}
                  <div className="grid grid-cols-2 gap-4">
                    <div className="glass card-3d p-5">
                      <p className="text-xs font-bold text-gray-500 mb-1 uppercase tracking-widest">Sleep Schedule</p>
                      <span className="text-lg font-hero font-bold text-white">{selectedRoutine.sleepTime} - {selectedRoutine.wakeTime}</span>
                    </div>
                    {selectedRoutine.notes && (
                      <div className="col-span-2 glass card-3d p-5">
                        <p className="text-xs font-bold text-gray-500 mb-2 uppercase tracking-widest">Reflection</p>
                        <p className="text-sm text-gray-300 leading-relaxed italic">"{selectedRoutine.notes}"</p>
                      </div>
                    )}
                  </div>

                </div>
              )}
            </div>
          </div>
        </main>
        
        {/* Floating Action Button */}
        {!showForm && (
          <button 
            onClick={openNewForm}
            className="fixed bottom-8 right-8 w-14 h-14 bg-cyan text-black rounded-2xl shadow-[0_4px_20px_rgba(0,255,255,0.4)] flex items-center justify-center hover:scale-105 transition-transform z-40"
          >
            <Plus className="w-6 h-6" />
          </button>
        )}

      </div>

      {/* FORM MODAL */}
      <Modal isOpen={showForm} onClose={() => setShowForm(false)} title={editingId ? 'Edit Daily Log' : 'New Daily Log'}>
        <form onSubmit={handleSubmit} className="space-y-6">
          {formError && (
            <div className="bg-red-500/10 border border-red-500/20 text-red-300 px-4 py-3 rounded-xl text-sm flex flex-col gap-2">
              <span className="leading-relaxed">{formError}</span>
              {duplicateId && (
                <button
                  type="button"
                  onClick={() => {
                    const existing = routines.find(r => (r._id || r.id) === duplicateId);
                    if (existing) { handleEditInit(existing); setFormError(''); }
                  }}
                  className="self-start px-3 py-1.5 bg-blue-500/20 border border-blue-500/30 text-blue-400 text-xs font-bold rounded-lg hover:bg-blue-500/30 transition"
                >
                  Edit Existing Instead
                </button>
              )}
            </div>
          )}

          <div className="space-y-4">
            <div>
              <label className="text-xs font-bold text-gray-400 block mb-1">Target Date</label>
              <input type="date" required value={formDateStr} onChange={(e) => setFormDateStr(e.target.value)}
                className="w-full px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-white focus:outline-none focus:border-blue-500 text-sm" />
            </div>

            <div className="grid grid-cols-2 gap-4">
              {config.coreMetrics.map((met) => (
                <div key={met.id}>
                  <label className="text-xs font-bold text-gray-400 block mb-1">{met.title}</label>
                  <input type="number" step="0.5" min="0" max="24" value={coreMetricsState[met.id] || ''}
                    onChange={(e) => setCoreMetricsState({ ...coreMetricsState, [met.id]: Number(e.target.value) })}
                    className="w-full px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-white focus:outline-none focus:border-blue-500 text-sm" />
                </div>
              ))}
            </div>

            <div>
              <label className="text-xs font-bold text-gray-400 block mb-2">Core Habits</label>
              <div className="space-y-2">
                {config.coreChecklists.map((chk) => (
                  <label key={chk.id} className="flex items-center justify-between p-3 bg-white/5 rounded-xl cursor-pointer hover:bg-white/10">
                    <span className="text-sm text-gray-200">{chk.title}</span>
                    <input type="checkbox" checked={coreChecklistsState[chk.id] || false}
                      onChange={(e) => setCoreChecklistsState({ ...coreChecklistsState, [chk.id]: e.target.checked })}
                      className="h-4 w-4 rounded bg-white/5 border-white/10 text-blue-500" />
                  </label>
                ))}
              </div>
            </div>

            <div>
              <label className="text-xs font-bold text-gray-400 block mb-2">Custom Checklist</label>
              <div className="flex gap-2 mb-2">
                <input type="text" placeholder="Add custom item..." value={newCustomLogTitle} onChange={(e) => setNewCustomLogTitle(e.target.value)}
                  className="flex-1 px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-white text-sm" />
                <button type="button" onClick={handleAddCustomLog} className="px-3 bg-blue-500/20 text-blue-400 rounded-xl font-bold text-sm">Add</button>
              </div>
              <div className="space-y-1">
                {customLogs.map((log, index) => (
                  <div key={index} className="flex items-center justify-between p-2 bg-white/5 rounded-lg">
                    <label className="flex items-center gap-2 cursor-pointer">
                      <input type="checkbox" checked={log.completed} onChange={() => handleToggleCustomLog(index)}
                        className="h-4 w-4 rounded text-blue-500" />
                      <span className="text-sm">{log.title}</span>
                    </label>
                    <button type="button" onClick={() => handleRemoveCustomLog(index)} className="text-red-400 hover:text-red-300 p-1"><X className="w-4 h-4" /></button>
                  </div>
                ))}
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <label className="text-xs font-bold text-gray-400 block mb-1">Sleep Time</label>
                <input type="time" value={sleepTime} onChange={(e) => setSleepTime(e.target.value)}
                  className="w-full px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-white text-sm" />
              </div>
              <div>
                <label className="text-xs font-bold text-gray-400 block mb-1">Wake Time</label>
                <input type="time" value={wakeTime} onChange={(e) => setWakeTime(e.target.value)}
                  className="w-full px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-white text-sm" />
              </div>
            </div>

            <div>
              <label className="text-xs font-bold text-gray-400 block mb-1">Notes</label>
              <textarea value={notes} onChange={(e) => setNotes(e.target.value)} rows="2"
                className="w-full px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-white text-sm resize-none"></textarea>
            </div>
          </div>

          <div className="flex gap-3 pt-4 border-t border-white/5">
            <button type="button" onClick={() => setShowForm(false)} className="flex-1 py-3 bg-white/5 hover:bg-white/10 text-white font-bold rounded-xl transition">
              Cancel
            </button>
            <button type="submit" className="flex-1 py-3 bg-blue-500 hover:bg-blue-600 text-white font-bold rounded-xl shadow-lg shadow-blue-500/20 transition">
              {editingId ? 'Save Changes' : 'Create Log'}
            </button>
          </div>
        </form>
      </Modal>

    </div>
  );
};

export default RoutineTracker;