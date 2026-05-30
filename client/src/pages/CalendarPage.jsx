import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { startOfWeek, endOfWeek, format, addWeeks, subWeeks } from 'date-fns';
import { ChevronLeft, ChevronRight, Sparkles } from 'lucide-react';

import Sidebar from '../components/Sidebar';
import CalendarSidebar from '../components/calendar/CalendarSidebar';
import WeeklyCalendar from '../components/calendar/WeeklyCalendar';
import FloatingActionButton from '../components/calendar/FloatingActionButton';
import AddEventModal from '../components/calendar/AddEventModal';
import AIPlannerModal from '../components/calendar/AIPlannerModal';
import AIInsightCard from '../components/calendar/AIInsightCard';
import ProductivityHeatmap from '../components/calendar/ProductivityHeatmap';

import {
  getEvents,
  createEvent,
  updateEvent,
  getCalendarStatus,
  getCalendarAuthUrl,
  submitCalendarCallback,
  fetchFromGoogle,
  getInsights,
  getHeatmap
} from '../services/calendarService';

const CalendarPage = () => {
  const [currentDate, setCurrentDate] = useState(new Date());
  const [view, setView] = useState('timeGridWeek'); // timeGridWeek, timeGridDay, dayGridMonth
  const [events, setEvents] = useState([]);
  
  // Modals
  const [isAddEventOpen, setIsAddEventOpen] = useState(false);
  const [isAIPlannerOpen, setIsAIPlannerOpen] = useState(false);
  const [selectedDate, setSelectedDate] = useState(null);
  const [selectedEvent, setSelectedEvent] = useState(null);

  // Data
  const [insights, setInsights] = useState([]);
  const [heatmapData, setHeatmapData] = useState({ heatmap: {}, eventDensity: {}, stats: {} });
  
  // Sync Status
  const [syncStatus, setSyncStatus] = useState({
    connected: false,
    googleEmail: '',
    lastSynced: null,
    isSyncing: false
  });

  const [calendars, setCalendars] = useState([
    { id: 'primary', name: 'Primary Calendar', color: '#3B82F6', visible: true },
    { id: 'ai', name: 'Neural Sync', color: '#10B981', visible: true },
    { id: 'tasks', name: 'Tasks', color: '#F59E0B', visible: true },
  ]);

  const loadData = async () => {
    const start = format(startOfWeek(currentDate), "yyyy-MM-dd'T'00:00:00");
    const end = format(endOfWeek(currentDate), "yyyy-MM-dd'T'23:59:59");
    
    try {
      const [eventsRes, statusRes, insightsRes, heatmapRes] = await Promise.all([
        getEvents(start, end),
        getCalendarStatus(),
        getInsights(),
        getHeatmap(14)
      ]);

      if (eventsRes.success) setEvents(eventsRes.events);
      if (statusRes.success) {
        setSyncStatus(prev => ({
          ...prev,
          connected: statusRes.connected,
          googleEmail: statusRes.googleEmail,
          lastSynced: statusRes.lastSynced
        }));
      }
      if (insightsRes.success) setInsights(insightsRes.insights.slice(0, 2)); // Show top 2
      if (heatmapRes.success) setHeatmapData(heatmapRes);
    } catch (e) {
      console.error('Error loading calendar data:', e);
    }
  };

  useEffect(() => {
    // Check if there is an OAuth code in the URL parameters from Google redirect
    const params = new URLSearchParams(window.location.search);
    const code = params.get('code');
    if (code) {
      // Clear code from URL immediately so we don't try to resubmit on refresh
      window.history.replaceState({}, document.title, window.location.pathname);
      
      const processOAuth = async () => {
        setSyncStatus(prev => ({ ...prev, isSyncing: true }));
        try {
          const res = await submitCalendarCallback(code);
          if (res.success || res.connected) {
            await loadData();
          }
        } catch (e) {
          console.error("Failed to connect Google Calendar:", e);
        } finally {
          setSyncStatus(prev => ({ ...prev, isSyncing: false }));
        }
      };
      processOAuth();
    }
  }, []);

  useEffect(() => {
    loadData();
    // Setup polling every 5 minutes
    const interval = setInterval(loadData, 5 * 60 * 1000);
    return () => clearInterval(interval);
  }, [currentDate]); // Reload when date changes to get new range

  const handleSync = async () => {
    if (!syncStatus.connected) return;
    setSyncStatus(prev => ({ ...prev, isSyncing: true }));
    try {
      await fetchFromGoogle();
      await loadData();
    } finally {
      setSyncStatus(prev => ({ ...prev, isSyncing: false }));
    }
  };

  const handleConnect = async () => {
    try {
      const res = await getCalendarAuthUrl();
      if (res.success && res.authUrl) {
        window.location.href = res.authUrl; // Redirect to Google OAuth
      }
    } catch (e) {
      console.error("Failed to get auth URL", e);
    }
  };

  const handleSaveEvent = async (eventData) => {
    if (eventData.id) {
      await updateEvent(eventData.id, eventData);
    } else {
      await createEvent(eventData);
    }
    await loadData();
  };

  const handleEventDropOrResize = async (id, start, end, allDay = false) => {
    try {
      await updateEvent(id, { start, end, allDay });
      await loadData(); // refresh
    } catch(e) {
      console.error("Failed to update event", e);
      await loadData(); // revert
    }
  };

  const filteredEvents = events.filter(e => {
    if (e.isAiGenerated && !calendars.find(c => c.id === 'ai')?.visible) return false;
    if (e.category === 'task' && !calendars.find(c => c.id === 'tasks')?.visible) return false;
    if (!e.isAiGenerated && e.category !== 'task' && !calendars.find(c => c.id === 'primary')?.visible) return false;
    return true;
  });

  return (
    <div className="flex h-screen bg-[#050816] text-white overflow-hidden font-sans">
      
      <Sidebar />
      
      {/* Left Sidebar */}
      <CalendarSidebar 
        currentDate={currentDate}
        onDateChange={setCurrentDate}
        calendars={calendars}
        onToggleCalendar={(id) => setCalendars(c => c.map(cal => cal.id === id ? { ...cal, visible: !cal.visible } : cal))}
        syncProps={{
          ...syncStatus,
          onSync: handleSync,
          onConnect: handleConnect
        }}
      />

      {/* Main Content */}
      <div className="flex-1 flex flex-col min-w-0">
        
        {/* Top Header */}
        <header className="h-20 flex items-center justify-between px-8 border-b border-white/5 bg-[#0d1126]/30 backdrop-blur-md">
          <div className="flex items-center gap-6">
            <button 
              onClick={() => setCurrentDate(new Date())}
              className="px-4 py-2 rounded-xl text-sm font-semibold bg-white/5 hover:bg-white/10 transition-colors border border-white/5"
            >
              Today
            </button>
            <div className="flex items-center gap-2">
              <button onClick={() => setCurrentDate(subWeeks(currentDate, 1))} className="p-2 rounded-lg hover:bg-white/10 text-gray-400 hover:text-white transition-colors">
                <ChevronLeft className="w-5 h-5" />
              </button>
              <h2 className="text-2xl font-bold text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-purple-400 min-w-[200px] text-center">
                {format(currentDate, 'MMMM yyyy')}
              </h2>
              <button onClick={() => setCurrentDate(addWeeks(currentDate, 1))} className="p-2 rounded-lg hover:bg-white/10 text-gray-400 hover:text-white transition-colors">
                <ChevronRight className="w-5 h-5" />
              </button>
            </div>
          </div>

          {/* View Toggles */}
          <div className="flex bg-black/40 p-1 rounded-xl border border-white/5">
            {['timeGridWeek', 'timeGridDay', 'dayGridMonth'].map((v) => (
              <button
                key={v}
                onClick={() => setView(v)}
                className={`px-4 py-1.5 rounded-lg text-sm font-medium transition-all ${
                  view === v 
                    ? 'bg-gradient-to-r from-blue-500/20 to-purple-500/20 text-blue-300 shadow-neon' 
                    : 'text-gray-500 hover:text-gray-300'
                }`}
              >
                {v.replace('timeGrid', '').replace('dayGrid', '')}
              </button>
            ))}
          </div>
        </header>

        {/* Calendar Area */}
        <div className="flex-1 overflow-hidden relative flex">
          <div className="flex-1 h-full p-6">
            <div className="w-full h-full bg-[#0d1126]/40 rounded-3xl border border-white/5 backdrop-blur-sm overflow-hidden p-4">
              <WeeklyCalendar 
                events={filteredEvents}
                currentDate={currentDate}
                view={view}
                onEventClick={(evt) => {
                  setSelectedEvent(evt);
                  setIsAddEventOpen(true);
                }}
                onDateSelect={(start, end) => {
                  setSelectedDate(start);
                  setSelectedEvent(null);
                  setIsAddEventOpen(true);
                }}
                onEventDrop={handleEventDropOrResize}
                onEventResize={handleEventDropOrResize}
              />
            </div>
          </div>

          {/* Right Insights Panel */}
          <div className="w-80 border-l border-white/5 bg-[#0d1126]/20 p-6 overflow-y-auto custom-scrollbar flex flex-col gap-6">
            
            <div>
              <h3 className="text-sm font-bold text-white mb-4 flex items-center gap-2">
                <Sparkles className="w-4 h-4 text-purple-400" /> Neural Insights
              </h3>
              <div className="space-y-3">
                {insights.length > 0 ? (
                  insights.map((ins, i) => <AIInsightCard key={ins.id} insight={ins} index={i} />)
                ) : (
                  <p className="text-xs text-gray-500 italic">Sync your routines to generate insights.</p>
                )}
              </div>
            </div>

            <div className="pt-4 border-t border-white/5">
              <ProductivityHeatmap 
                heatmap={heatmapData.heatmap} 
                eventDensity={heatmapData.eventDensity}
                days={14}
              />
            </div>

          </div>
        </div>

      </div>

      <FloatingActionButton 
        onAddEvent={() => { setSelectedEvent(null); setSelectedDate(null); setIsAddEventOpen(true); }}
        onAddTask={() => { setSelectedEvent(null); setSelectedDate(null); setIsAddEventOpen(true); }}
        onAIGenerate={() => setIsAIPlannerOpen(true)}
      />

      <AddEventModal 
        isOpen={isAddEventOpen} 
        onClose={() => setIsAddEventOpen(false)} 
        initialDate={selectedDate}
        initialEvent={selectedEvent}
        onSave={handleSaveEvent}
      />

      <AIPlannerModal 
        isOpen={isAIPlannerOpen}
        onClose={() => setIsAIPlannerOpen(false)}
        onScheduleApplied={loadData}
      />

    </div>
  );
};

export default CalendarPage;
