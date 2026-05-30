import React, { useRef } from 'react';
import FullCalendar from '@fullcalendar/react';
import timeGridPlugin from '@fullcalendar/timegrid';
import dayGridPlugin from '@fullcalendar/daygrid';
import interactionPlugin from '@fullcalendar/interaction';
import EventCard from './EventCard';

const WeeklyCalendar = ({
  events,
  currentDate,
  onEventClick,
  onDateSelect,
  onEventDrop,
  onEventResize,
  view = 'timeGridWeek'
}) => {
  const calendarRef = useRef(null);

  // Sync external currentDate with FullCalendar
  React.useEffect(() => {
    if (calendarRef.current) {
      const calendarApi = calendarRef.current.getApi();
      calendarApi.gotoDate(currentDate);
      if (calendarApi.view.type !== view) {
        calendarApi.changeView(view);
      }
    }
  }, [currentDate, view]);

  const handleEventContent = (eventInfo) => {
    return <EventCard eventInfo={eventInfo} />;
  };

  const mapEvents = (evts) => evts.map(e => ({
    id: e.id,
    title: e.title,
    start: e.start,
    end: e.end,
    allDay: e.allDay,
    extendedProps: {
      description: e.description,
      colorKey: e.colorKey,
      category: e.category,
      location: e.location,
      attendees: e.attendees,
      recurrence: e.recurrence,
      reminders: e.reminders,
      syncedToGoogle: e.syncedToGoogle,
      isAiGenerated: e.isAiGenerated,
      completed: e.completed
    }
  }));

  return (
    <div className="h-full w-full custom-calendar-wrapper relative">
      <style>{`
        /* Futuristic FullCalendar Overrides */
        .fc {
          --fc-border-color: rgba(255, 255, 255, 0.05);
          --fc-page-bg-color: transparent;
          --fc-neutral-bg-color: rgba(255, 255, 255, 0.02);
          --fc-today-bg-color: rgba(59, 130, 246, 0.05);
          --fc-event-border-color: transparent;
          font-family: inherit;
        }
        
        .fc-theme-standard td, .fc-theme-standard th {
          border-color: var(--fc-border-color);
        }

        .fc .fc-timegrid-slot {
          height: 3em; /* Taller slots for better visual spacing */
        }

        .fc-timegrid-slot-label-cushion {
          color: #9CA3AF;
          font-size: 0.75rem;
          font-weight: 500;
        }

        .fc-col-header-cell-cushion {
          color: #E5E7EB;
          padding: 12px 8px !important;
          font-weight: 600;
          text-transform: uppercase;
          font-size: 0.8rem;
          letter-spacing: 0.05em;
        }

        .fc-col-header-cell.fc-day-today .fc-col-header-cell-cushion {
          color: #8B5CF6; /* Purple for today */
        }

        .fc-event {
          background: transparent !important;
          border: none !important;
          border-radius: 8px !important;
          padding: 0 !important;
          overflow: visible !important;
          box-shadow: none !important;
        }
        
        .fc-v-event {
          background-color: transparent !important;
          border: none !important;
        }

        .fc-timegrid-event-harness > .fc-timegrid-event {
          box-shadow: none !important;
          background: transparent !important;
        }
        
        /* Custom scrollbar for FullCalendar */
        .fc-scroller {
          overflow-y: overlay !important;
        }
        .fc-scroller::-webkit-scrollbar {
          width: 6px;
        }
        .fc-scroller::-webkit-scrollbar-track {
          background: transparent;
        }
        .fc-scroller::-webkit-scrollbar-thumb {
          background-color: rgba(255, 255, 255, 0.1);
          border-radius: 10px;
        }
        
        /* Highlight current time */
        .fc-timegrid-now-indicator-line {
          border-color: #8B5CF6;
          border-width: 2px;
          box-shadow: 0 0 10px rgba(139, 92, 246, 0.5);
        }
        .fc-timegrid-now-indicator-arrow {
          border-color: #8B5CF6;
          border-width: 6px;
        }

        /* Hide default header since we use custom controls */
        .fc-header-toolbar {
          display: none !important;
        }
      `}</style>
      
      <FullCalendar
        ref={calendarRef}
        plugins={[timeGridPlugin, dayGridPlugin, interactionPlugin]}
        initialView={view}
        initialDate={currentDate}
        events={mapEvents(events)}
        eventContent={handleEventContent}
        eventClick={(info) => {
          info.jsEvent.preventDefault();
          const evt = events.find(e => e.id == info.event.id);
          if(evt) onEventClick(evt);
        }}
        selectable={true}
        selectMirror={true}
        select={(info) => {
          onDateSelect(info.startStr, info.endStr, info.allDay);
          info.view.calendar.unselect();
        }}
        editable={true}
        eventDrop={(info) => {
          onEventDrop(info.event.id, info.event.startStr, info.event.endStr, info.event.allDay);
        }}
        eventResize={(info) => {
          onEventResize(info.event.id, info.event.startStr, info.event.endStr);
        }}
        slotMinTime="06:00:00" // Usually start at 6 AM
        slotMaxTime="24:00:00"
        allDaySlot={true}
        height="100%"
        nowIndicator={true}
        dayMaxEvents={true}
      />
    </div>
  );
};

export default WeeklyCalendar;
