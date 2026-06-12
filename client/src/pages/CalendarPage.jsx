import React, { useState, useEffect, useCallback } from 'react';
import AppLayout from '../components/layout/AppLayout';
import Button from '../components/ui/Button';
import Badge from '../components/ui/Badge';
import EmptyState from '../components/ui/EmptyState';
import { apiFetch, calendarApi } from '../services/api';
import { Calendar as CalendarIcon, ChevronLeft, ChevronRight, Plus, RefreshCw, Star, CheckCircle } from 'lucide-react';
import { startOfMonth, endOfMonth, startOfWeek, endOfWeek, eachDayOfInterval, format, isSameMonth, isSameDay, addMonths, subMonths } from 'date-fns';

export default function CalendarPage() {
  const [currentDate, setCurrentDate] = useState(new Date());
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [googleStatus, setGoogleStatus] = useState({ connected: false, email: '' });
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [showModal, setShowModal] = useState(false);
  const [saving, setSaving] = useState(false);
  const [newEvent, setNewEvent] = useState({ title: '', start_time: '', end_time: '' });

  const handleCreateEvent = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      // Ensure date is formatted properly, attaching selectedDate + time
      const startDateTime = new Date(selectedDate);
      if (newEvent.start_time) {
        const [h, m] = newEvent.start_time.split(':');
        startDateTime.setHours(parseInt(h), parseInt(m), 0);
      }
      
      const endDateTime = new Date(startDateTime);
      if (newEvent.end_time) {
        const [eh, em] = newEvent.end_time.split(':');
        endDateTime.setHours(parseInt(eh), parseInt(em), 0);
      } else {
        endDateTime.setHours(startDateTime.getHours() + 1); // Default 1 hour duration
      }

      const payload = {
        title: newEvent.title,
        start: startDateTime.toISOString(),
        end: endDateTime.toISOString(),
      };

      // Depending on API, it could be `apiFetch('/calendar/events/', {method: 'POST', body: ...})`
      await apiFetch('/calendar/events/', { method: 'POST', body: JSON.stringify(payload) });
      await fetchEvents();
      setShowModal(false);
      setNewEvent({ title: '', start_time: '', end_time: '' });
    } catch (err) {
      console.error(err);
    } finally {
      setSaving(false);
    }
  };

  const fetchEvents = useCallback(async () => {
    try {
      setLoading(true);
      const start = startOfMonth(currentDate).toISOString();
      const end = endOfMonth(currentDate).toISOString();
      // Adjust URL based on your backend
      const res = await apiFetch(`/calendar/events/?start=${start}&end=${end}`);
      setEvents(res?.events || res?.data || (Array.isArray(res) ? res : []));
    } catch (err) {
      setError('Failed to load events');
    } finally {
      setLoading(false);
    }
  }, [currentDate]);

  useEffect(() => { fetchEvents(); }, [fetchEvents]);

  useEffect(() => {
    const fetchGoogleStatus = async () => {
      try {
        const res = await calendarApi.googleStatus();
        setGoogleStatus({ connected: res.connected, email: res.googleEmail });
        console.log("Google Status:", res);
      } catch (err) {
        console.error("Failed to fetch Google Calendar status", err);
      }
    };
    fetchGoogleStatus();
  }, []);

  const handleGoogleConnect = async () => {
    try {
      console.log("Google Connect Clicked");
      const res = await calendarApi.googleConnect();
      console.log("OAuth URL:", res.authUrl);
      if (res.authUrl) {
        window.location.href = res.authUrl;
      }
    } catch (err) {
      console.error("Failed to get Google OAuth URL:", err);
      setError("Failed to connect to Google Calendar.");
    }
  };

  const handleGoogleDisconnect = async () => {
    try {
      await calendarApi.googleDisconnect();
      setGoogleStatus({ connected: false, email: '' });
      console.log("Google Status: Disconnected");
    } catch (err) {
      console.error("Failed to disconnect Google Calendar:", err);
      setError("Failed to disconnect.");
    }
  };

  const monthStart = startOfMonth(currentDate);
  const monthEnd = endOfMonth(monthStart);
  const startDate = startOfWeek(monthStart);
  const endDate = endOfWeek(monthEnd);
  const calendarDays = eachDayOfInterval({ start: startDate, end: endDate });

  const getEventsForDay = (day) => {
    if (!Array.isArray(events)) return [];
    return events.filter(e => {
      const startStr = e.start || e.start_time || e.date;
      if (!startStr) return false;
      const eDate = new Date(startStr);
      if (isNaN(eDate.getTime())) return false;
      return isSameDay(eDate, day);
    });
  };

  const selectedDayEvents = getEventsForDay(selectedDate);

  return (
    <AppLayout title="Calendar">
      <div className="max-w-6xl mx-auto flex flex-col lg:flex-row gap-6 animate-fadeInUp h-[calc(100vh-8rem)]">
        
        {/* Main Calendar View */}
        <div className="flex-1 glass card-3d p-6 flex flex-col min-h-0">
          <div className="flex items-center justify-between mb-6 flex-shrink-0">
            <h2 className="text-2xl font-hero font-extrabold text-white flex items-center gap-3">
              <CalendarIcon className="w-6 h-6 text-plasma" />
              {format(currentDate, 'MMMM yyyy')}
            </h2>
            <div className="flex items-center gap-2">
              <Button variant="secondary" size="sm" onClick={() => setCurrentDate(subMonths(currentDate, 1))} icon={ChevronLeft} />
              <Button variant="secondary" size="sm" onClick={() => setCurrentDate(new Date())}>Today</Button>
              <Button variant="secondary" size="sm" onClick={() => setCurrentDate(addMonths(currentDate, 1))} icon={ChevronRight} />
            </div>
          </div>

          <div className="grid grid-cols-7 gap-px bg-white/5 border border-white/10 rounded-xl overflow-y-auto flex-1 h-full min-h-[400px]">
            {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map(day => (
              <div key={day} className="bg-[#0d1126]/80 p-2 text-center text-xs font-bold text-gray-400">
                {day}
              </div>
            ))}
            
            {calendarDays.map((day, idx) => {
              const isSelected = isSameDay(day, selectedDate);
              const isCurrentMonth = isSameMonth(day, currentDate);
              const dayEvents = getEventsForDay(day);
              
              return (
                <button
                  key={idx}
                  onClick={() => setSelectedDate(day)}
                  className={`bg-carbon/40 p-2 flex flex-col items-center hover:bg-white/5 transition-colors min-h-[80px]
                    ${!isCurrentMonth ? 'opacity-30' : ''}
                    ${isSelected ? 'ring-2 ring-plasma/50 bg-plasma/10' : ''}
                  `}
                >
                  <span className={`w-7 h-7 flex items-center justify-center rounded-full text-sm font-semibold
                    ${isSameDay(day, new Date()) ? 'bg-plasma text-white' : 'text-gray-300'}`}>
                    {format(day, 'd')}
                  </span>
                  
                  <div className="mt-1 flex flex-col gap-1 w-full px-1">
                    {dayEvents.slice(0, 2).map((e, i) => (
                      <div key={i} className="w-full truncate text-[10px] px-1.5 py-0.5 rounded bg-plasma/20 text-plasma">
                        {e.title || e.summary || 'Event'}
                      </div>
                    ))}
                    {dayEvents.length > 2 && (
                      <div className="text-[10px] text-gray-500">+{dayEvents.length - 2} more</div>
                    )}
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Sidebar */}
        <div className="w-full lg:w-80 flex flex-col gap-4 flex-shrink-0 min-h-0">
          <Button icon={Plus} fullWidth className="flex-shrink-0" onClick={() => setShowModal(true)}>New Event</Button>
          
          <div className="glass card-3d p-5 flex-shrink-0">
            <h3 className="font-bold text-white text-sm mb-3">Integrations</h3>
            <div className="p-3 bg-white/4 rounded-xl border border-white/10 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div className={`w-8 h-8 rounded-lg flex items-center justify-center text-white font-bold ${googleStatus.connected ? 'bg-green-500/20 text-green-400' : 'bg-white/10'}`}>G</div>
                <div className="truncate max-w-[120px]">
                  <p className="text-sm font-bold text-white">Google Calendar</p>
                  {googleStatus.connected ? (
                    <p className="text-[10px] text-green-400 flex items-center gap-1 truncate" title={googleStatus.email}>
                      <CheckCircle className="w-3 h-3 flex-shrink-0" />
                      <span className="truncate">{googleStatus.email || 'Connected'}</span>
                    </p>
                  ) : (
                    <p className="text-[10px] text-gray-400">Not connected</p>
                  )}
                </div>
              </div>
              {googleStatus.connected ? (
                <Button size="sm" variant="secondary" onClick={handleGoogleDisconnect}>Disconnect</Button>
              ) : (
                <Button size="sm" variant="secondary" onClick={handleGoogleConnect}>Connect</Button>
              )}
            </div>
          </div>

          <div className="glass card-3d flex-1 p-5 overflow-hidden flex flex-col min-h-0">
            <h3 className="font-bold text-white text-sm mb-3 pb-3 border-b border-white/10 flex items-center justify-between">
              <span>{format(selectedDate, 'MMM d, yyyy')}</span>
              <Badge variant="purple">{selectedDayEvents.length} events</Badge>
            </h3>
            
            <div className="flex-1 overflow-y-auto space-y-3 pr-2 -mr-2">
              {loading ? (
                <div className="flex justify-center p-4"><RefreshCw className="w-5 h-5 text-gray-500 animate-spin" /></div>
              ) : selectedDayEvents.length === 0 ? (
                <EmptyState icon={Star} title="No events" description="Enjoy your free time!" />
              ) : (
                selectedDayEvents.map((e, i) => (
                  <div key={i} className="p-3 bg-white/5 border border-white/5 rounded-xl hover:bg-white/10 transition-colors group cursor-pointer">
                    <p className="text-sm font-semibold text-white group-hover:text-plasma transition-colors">
                      {e.title || e.summary || 'Event'}
                    </p>
                    <p className="text-[10px] text-gray-400 mt-1 flex items-center gap-1">
                      <Clock className="w-3 h-3" />
                      {e.start ? format(new Date(e.start), 'h:mm a') : 'All day'}
                    </p>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>

      </div>

      {/* New Event Modal */}
      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-fadeIn">
          <div className="glass card-3d p-6 w-full max-w-md animate-fadeInUp">
            <div className="flex justify-between items-center mb-6">
              <h3 className="text-xl font-bold text-white flex items-center gap-2">
                <CalendarIcon className="w-5 h-5 text-plasma" />
                Add Event for {format(selectedDate, 'MMM d, yyyy')}
              </h3>
              <button onClick={() => setShowModal(false)} className="text-gray-400 hover:text-white transition-colors">
                ✕
              </button>
            </div>
            <form onSubmit={handleCreateEvent} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-gray-400 mb-1.5 block">Event Title</label>
                <input
                  type="text"
                  required
                  placeholder="E.g., Team Sync"
                  value={newEvent.title}
                  onChange={(e) => setNewEvent({ ...newEvent, title: e.target.value })}
                  className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-cyan/50 focus:bg-white/8 transition-all"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="text-xs font-semibold text-gray-400 mb-1.5 block">Start Time</label>
                  <input
                    type="time"
                    required
                    value={newEvent.start_time}
                    onChange={(e) => setNewEvent({ ...newEvent, start_time: e.target.value })}
                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan/50 transition-all"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-gray-400 mb-1.5 block">End Time</label>
                  <input
                    type="time"
                    value={newEvent.end_time}
                    onChange={(e) => setNewEvent({ ...newEvent, end_time: e.target.value })}
                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-sm text-white focus:outline-none focus:border-cyan/50 transition-all"
                  />
                </div>
              </div>
              <div className="pt-4 flex gap-3">
                <Button type="button" variant="secondary" fullWidth onClick={() => setShowModal(false)}>Cancel</Button>
                <Button type="submit" fullWidth loading={saving}>Add Event</Button>
              </div>
            </form>
          </div>
        </div>
      )}
    </AppLayout>
  );
}

// Quick Clock icon for the sidebar
function Clock(props) {
  return (
    <svg {...props} xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>
    </svg>
  );
}
