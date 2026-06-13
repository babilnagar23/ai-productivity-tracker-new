import { motion } from 'framer-motion';
import { COLOR_PALETTE, CATEGORY_ICONS, formatDuration } from '../../services/calendarService';

const EventCard = ({ eventInfo }) => {
  const { event } = eventInfo;
  const colorKey = event.extendedProps?.colorKey || 'blue';
  const category = event.extendedProps?.category || 'personal';
  const isCompleted = event.extendedProps?.completed || false;
  
  const palette = COLOR_PALETTE[colorKey] || COLOR_PALETTE.blue;
  const icon = CATEGORY_ICONS[category] || CATEGORY_ICONS.personal;

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      className="w-full h-full relative group overflow-hidden rounded-lg p-1.5 flex flex-col cursor-pointer"
      style={{
        background: `linear-gradient(135deg, ${palette.hex}20, ${palette.hex}05)`,
        border: `1px solid ${palette.hex}40`,
        boxShadow: `0 0 10px ${palette.glow}`,
        opacity: isCompleted ? 0.6 : 1,
      }}
    >
      {/* Glow highlight on left edge */}
      <div 
        className="absolute left-0 top-0 bottom-0 w-1 rounded-l-lg"
        style={{ background: palette.hex, boxShadow: `0 0 8px ${palette.hex}` }}
      />

      <div className="flex items-start justify-between gap-1 z-10 pl-1">
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-1 mb-0.5">
            <span className="text-[10px]">{icon}</span>
            <span 
              className="text-[9px] font-bold uppercase tracking-wider truncate"
              style={{ color: palette.hex }}
            >
              {category}
            </span>
          </div>
          <h4 className="text-xs font-semibold text-white leading-tight truncate">
            {event.title}
          </h4>
        </div>
        
        {isCompleted && (
          <div className="flex-shrink-0 w-4 h-4 rounded-full bg-green-500/20 border border-green-500/40 flex items-center justify-center">
            <svg className="w-2.5 h-2.5 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
            </svg>
          </div>
        )}
      </div>

      <div className="mt-auto z-10 pl-1">
        <p className="text-[10px] text-gray-400 font-medium">
          {formatDuration(event.start, event.end)}
        </p>
      </div>

      {/* Hover background effect */}
      <motion.div
        className="absolute inset-0 z-0 opacity-0 group-hover:opacity-100 transition-opacity duration-300"
        style={{
          background: `radial-gradient(circle at center, ${palette.hex}30 0%, transparent 70%)`
        }}
      />
    </motion.div>
  );
};

export default EventCard;
