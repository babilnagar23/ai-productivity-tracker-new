import React, { useState } from 'react';
import FullCalendar from '@fullcalendar/react';
import dayGridPlugin from '@fullcalendar/daygrid';
import interactionPlugin from '@fullcalendar/interaction';
import { Search, ChevronLeft, ChevronRight, Check } from 'lucide-react';
import SyncStatus from './SyncStatus';

const CalendarSidebar = ({
  currentDate,
  onDateChange,
  calendars = [],
  onToggleCalendar,
  syncProps = {}
}) => {
  const [search, setSearch] = useState('');

  return (
    <div className="w-72 h-full flex flex-col border-r border-white/10 bg-[#0d1126]/50 backdrop-blur-md overflow-hidden">
      
      {/* Search */}
      <div className="p-4 border-b border-white/5">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="text"
            placeholder="Search events..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full bg-white/5 border border-white/10 rounded-xl py-2 pl-9 pr-4 text-sm text-white placeholder-gray-500 outline-none focus:border-purple-500/50 transition-colors"
          />
        </div>
      </div>

      <div className="flex-1 overflow-y-auto custom-scrollbar">
        
        {/* Mini Calendar */}
        <div className="p-4 border-b border-white/5">
          <style>{`
            .mini-cal .fc-toolbar {
              margin-bottom: 0.5em !important;
            }
            .mini-cal .fc-toolbar-title {
              font-size: 0.875rem !important;
              font-weight: 600 !important;
              color: white;
            }
            .mini-cal .fc-button {
              background: transparent !important;
              border: none !important;
              padding: 0.2em !important;
              color: #9CA3AF !important;
            }
            .mini-cal .fc-button:hover {
              color: white !important;
            }
            .mini-cal .fc-col-header-cell-cushion {
              font-size: 0.65rem !important;
              color: #6B7280 !important;
              font-weight: 600 !important;
            }
            .mini-cal .fc-daygrid-day-number {
              font-size: 0.75rem !important;
              color: #D1D5DB;
              padding: 4px !important;
              width: 24px;
              height: 24px;
              display: flex;
              align-items: center;
              justify-content: center;
              border-radius: 50%;
              margin: auto;
            }
            .mini-cal .fc-day-today .fc-daygrid-day-number {
              background: linear-gradient(135deg, #3B82F6, #8B5CF6);
              color: white !important;
              font-weight: bold;
              box-shadow: 0 0 10px rgba(139, 92, 246, 0.4);
            }
            .mini-cal td, .mini-cal th {
              border: none !important;
            }
            .mini-cal .fc-day:hover .fc-daygrid-day-number {
              background: rgba(255, 255, 255, 0.1);
              cursor: pointer;
            }
          `}</style>
          <div className="mini-cal bg-black/20 rounded-2xl p-3 border border-white/5">
            <FullCalendar
              plugins={[dayGridPlugin, interactionPlugin]}
              initialView="dayGridMonth"
              headerToolbar={{
                left: 'title',
                center: '',
                right: 'prev,next'
              }}
              height="auto"
              dateClick={(info) => onDateChange(info.date)}
            />
          </div>
        </div>

        {/* My Calendars */}
        <div className="p-4 border-b border-white/5">
          <h3 className="text-xs font-semibold text-gray-400 uppercase tracking-wider mb-3">
            My Calendars
          </h3>
          <div className="space-y-2">
            {calendars.map((cal) => (
              <label key={cal.id} className="flex items-center gap-3 cursor-pointer group">
                <div 
                  className={`w-5 h-5 rounded flex items-center justify-center transition-all ${cal.visible ? '' : 'opacity-50'}`}
                  style={{ 
                    border: `1px solid ${cal.color}`,
                    background: cal.visible ? cal.color : 'transparent' 
                  }}
                  onClick={() => onToggleCalendar(cal.id)}
                >
                  {cal.visible && <Check className="w-3 h-3 text-white" />}
                </div>
                <span className={`text-sm transition-colors ${cal.visible ? 'text-gray-200' : 'text-gray-500'}`}>
                  {cal.name}
                </span>
              </label>
            ))}
          </div>
        </div>

        {/* Sync Status Widget */}
        <div className="p-4">
          <SyncStatus {...syncProps} />
        </div>

      </div>
    </div>
  );
};

export default CalendarSidebar;
