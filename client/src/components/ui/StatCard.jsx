import ProgressRing from './ProgressRing';

export default function StatCard({ label, value, sub, icon: Icon, color = '#3B82F6', gradient = 'from-blue-500/10', ring, trend }) {
  return (
    <div className={`glass-card glass-card-hover p-5 space-y-3 bg-gradient-to-br ${gradient} to-transparent`}>
      <div className="flex items-start justify-between">
        <span className="text-xs font-semibold text-gray-400 uppercase tracking-wider">{label}</span>
        {ring != null ? (
          <ProgressRing value={ring} size={44} strokeWidth={4} color={color}>
            <span className="text-[9px] font-bold" style={{ color }}>{ring}%</span>
          </ProgressRing>
        ) : Icon ? (
          <div className="p-2 rounded-xl" style={{ background: `${color}15` }}>
            <Icon className="w-4 h-4" style={{ color }} />
          </div>
        ) : null}
      </div>
      <div>
        <p className="text-2xl font-extrabold text-white leading-none">{value}</p>
        {sub && <p className="text-xs text-gray-500 mt-1">{sub}</p>}
      </div>
      {trend != null && (
        <div className={`text-xs font-semibold ${trend >= 0 ? 'text-green-400' : 'text-rose-400'}`}>
          {trend >= 0 ? '↑' : '↓'} {Math.abs(trend)}% vs last week
        </div>
      )}
    </div>
  );
}
