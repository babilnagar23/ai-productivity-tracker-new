import  { useMemo } from 'react';
import { motion } from 'framer-motion';
import { format, eachDayOfInterval, subDays } from 'date-fns';

const ProductivityHeatmap = ({ heatmap = {}, eventDensity = {}, days = 30 }) => {
  const dateRange = useMemo(() => {
    const end = new Date();
    const start = subDays(end, days - 1);
    return eachDayOfInterval({ start, end });
  }, [days]);

  const getColor = (score) => {
    if (score === undefined || score === null) return 'rgba(255,255,255,0.04)';
    if (score >= 85) return 'rgba(16,185,129,0.85)';
    if (score >= 70) return 'rgba(59,130,246,0.75)';
    if (score >= 55) return 'rgba(139,92,246,0.65)';
    if (score >= 40) return 'rgba(245,158,11,0.55)';
    if (score >= 20) return 'rgba(239,68,68,0.45)';
    return 'rgba(255,255,255,0.06)';
  };

  const getGlow = (score) => {
    if (!score || score < 40) return 'none';
    if (score >= 85) return '0 0 8px rgba(16,185,129,0.6)';
    if (score >= 70) return '0 0 8px rgba(59,130,246,0.5)';
    if (score >= 55) return '0 0 8px rgba(139,92,246,0.4)';
    return '0 0 6px rgba(245,158,11,0.3)';
  };

  // Group into weeks (rows of 7)
  const weeks = [];
  for (let i = 0; i < dateRange.length; i += 7) {
    weeks.push(dateRange.slice(i, i + 7));
  }

  const dayLabels = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <span className="text-xs font-semibold text-gray-400 uppercase tracking-wider">
          Productivity Heatmap — {days}d
        </span>
        {/* Legend */}
        <div className="flex items-center gap-1.5">
          <span className="text-xs text-gray-500">Low</span>
          {['rgba(255,255,255,0.06)', 'rgba(239,68,68,0.45)', 'rgba(245,158,11,0.55)', 'rgba(59,130,246,0.75)', 'rgba(16,185,129,0.85)'].map((c, i) => (
            <div key={i} className="w-3 h-3 rounded-sm" style={{ background: c }} />
          ))}
          <span className="text-xs text-gray-500">High</span>
        </div>
      </div>

      {/* Day-of-week labels */}
      <div className="flex gap-1 pl-0">
        {dayLabels.map(d => (
          <div key={d} className="w-8 text-center text-xs text-gray-600 font-medium">{d}</div>
        ))}
      </div>

      {/* Grid */}
      <div className="space-y-1">
        {weeks.map((week, wi) => (
          <div key={wi} className="flex gap-1">
            {week.map((date, di) => {
              const key = format(date, 'yyyy-MM-dd');
              const data = heatmap[key];
              const score = data?.score;
              const evtCount = eventDensity[key] || 0;

              return (
                <motion.div
                  key={key}
                  initial={{ opacity: 0, scale: 0.7 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: (wi * 7 + di) * 0.01 }}
                  whileHover={{ scale: 1.3, zIndex: 10 }}
                  className="relative group w-8 h-8 rounded-md cursor-pointer flex-shrink-0"
                  style={{
                    background: getColor(score),
                    boxShadow: getGlow(score),
                    border: '1px solid rgba(255,255,255,0.06)',
                  }}
                >
                  {/* Event count dot */}
                  {evtCount > 0 && (
                    <div
                      className="absolute -top-0.5 -right-0.5 w-2 h-2 rounded-full text-white flex items-center justify-center"
                      style={{ background: '#8B5CF6', fontSize: '6px', fontWeight: 700 }}
                    >
                      {evtCount > 9 ? '9' : evtCount}
                    </div>
                  )}

                  {/* Tooltip */}
                  <div
                    className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none z-20"
                  >
                    <div
                      className="rounded-xl px-3 py-2 text-xs whitespace-nowrap"
                      style={{
                        background: 'rgba(13,17,38,0.95)',
                        border: '1px solid rgba(255,255,255,0.1)',
                        backdropFilter: 'blur(12px)',
                        color: 'white',
                      }}
                    >
                      <div className="font-semibold text-white">{format(date, 'MMM d')}</div>
                      {score !== undefined ? (
                        <>
                          <div style={{ color: score >= 70 ? '#10B981' : score >= 40 ? '#F59E0B' : '#EF4444' }}>
                            Score: {score}%
                          </div>
                          {data?.studyHours > 0 && <div className="text-gray-400">Study: {data.studyHours}h</div>}
                          {evtCount > 0 && <div className="text-purple-400">{evtCount} events</div>}
                        </>
                      ) : (
                        <div className="text-gray-500">No data</div>
                      )}
                    </div>
                  </div>
                </motion.div>
              );
            })}
          </div>
        ))}
      </div>
    </div>
  );
};

export default ProductivityHeatmap;
