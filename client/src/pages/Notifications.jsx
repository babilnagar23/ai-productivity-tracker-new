import  { useState, useEffect, useCallback } from 'react';
import AppLayout from '../components/layout/AppLayout';
import Button from '../components/ui/Button';
import EmptyState from '../components/ui/EmptyState';
import { notificationsApi } from '../services/api';
import { Bell, Check, CheckCheck, Trash2, Calendar, Trophy, RotateCcw, Zap } from 'lucide-react';
import {  parseISO, formatDistanceToNow } from 'date-fns';

const TYPE_ICONS = {
  todo: CheckCheck,
  calendar: Calendar,
  achievement: Trophy,

  focus: Zap,
  daily_log: RotateCcw,
  default: Bell,
};
const TYPE_COLORS = {
  todo: 'blue', calendar: 'purple', achievement: 'yellow',
  focus: 'orange', default: 'gray',
};

export default function Notifications() {
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');
  const [marking, setMarking] = useState(false);

  const fetchNotifications = useCallback(async () => {
    try {
      const res = await notificationsApi.list();
      const data = res?.data || res?.results || res || [];
      setNotifications(Array.isArray(data) ? data : []);
    } catch { /* silent */ } finally { setLoading(false); }
  }, []);

  useEffect(() => { fetchNotifications(); }, [fetchNotifications]);

  const markRead = async (n) => {
    try {
      await notificationsApi.markRead(n.id);
      setNotifications(prev => prev.map(x => x.id === n.id ? { ...x, read_at: new Date().toISOString() } : x));
    } catch { /* silent */ }
  };

  const markAllRead = async () => {
    setMarking(true);
    try {
      await notificationsApi.markAllRead();
      setNotifications(prev => prev.map(n => ({ ...n, read_at: n.read_at || new Date().toISOString() })));
    } catch { /* silent */ } finally { setMarking(false); }
  };

  const remove = async (n) => {
    try {
      await notificationsApi.delete(n.id);
      setNotifications(prev => prev.filter(x => x.id !== n.id));
    } catch { /* silent */ }
  };

  const FILTERS = ['all', 'unread', 'todo', 'calendar', 'achievement'];
  const filtered = notifications.filter(n => {
    if (filter === 'unread') return !n.read_at;
    if (filter !== 'all') return n.type === filter;
    return true;
  });

  const unreadCount = notifications.filter(n => !n.read_at).length;

  return (
    <AppLayout title="Notifications">
      <div className="max-w-3xl mx-auto space-y-5 animate-fadeInUp">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-xl font-extrabold text-white flex items-center gap-2">
              <Bell className="w-5 h-5 text-blue-400" /> Notifications
            </h1>
            <p className="text-xs text-gray-400 mt-0.5">
              {unreadCount} unread · {notifications.length} total
            </p>
          </div>
          {unreadCount > 0 && (
            <Button variant="secondary" size="sm" loading={marking} icon={CheckCheck} onClick={markAllRead}>
              Mark all read
            </Button>
          )}
        </div>

        {/* Filter tabs */}
        <div className="flex gap-1.5 flex-wrap glass-card p-2">
          {FILTERS.map(f => (
            <button
              key={f}
              onClick={() => setFilter(f)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all
                ${filter === f ? 'bg-blue-500/20 text-blue-300 border border-blue-500/30' : 'text-gray-400 hover:text-white hover:bg-white/5'}`}
            >
              {f.charAt(0).toUpperCase() + f.slice(1)}
              {f === 'unread' && unreadCount > 0 && (
                <span className="ml-1 px-1.5 py-0.5 bg-rose-500/20 text-rose-400 rounded-full text-[9px]">{unreadCount}</span>
              )}
            </button>
          ))}
        </div>

        {/* List */}
        <div className="space-y-2">
          {loading ? (
            Array.from({length:4}).map((_,i) => <div key={i} className="h-16 rounded-xl bg-white/3 animate-shimmer" />)
          ) : filtered.length === 0 ? (
            <EmptyState icon={Bell} title="No notifications" description={filter === 'unread' ? 'You\'re all caught up!' : 'Nothing here.'} />
          ) : (
            filtered.map(n => {
              const Icon = TYPE_ICONS[n.type] || TYPE_ICONS.default;
              const color = TYPE_COLORS[n.type] || 'gray';
              const isUnread = !n.read_at;
              const relTime = n.created_at ? formatDistanceToNow(parseISO(n.created_at), { addSuffix: true }) : '';

              return (
                <div
                  key={n.id}
                  className={`group glass-card p-4 flex items-start gap-3 transition-all duration-200 hover:border-white/10
                    ${isUnread ? 'border-blue-500/15 bg-blue-500/3' : ''}`}
                >
                  <div className={`w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 ${isUnread ? 'bg-blue-500/15' : 'bg-white/4'}`}>
                    <Icon className="w-4 h-4 text-gray-400" />
                  </div>

                  <div className="flex-1 min-w-0">
                    <p className={`text-sm font-semibold ${isUnread ? 'text-white' : 'text-gray-300'}`}>
                      {n.title || 'Notification'}
                    </p>
                    <p className="text-xs text-gray-500 mt-0.5 line-clamp-2">{n.body || n.message || ''}</p>
                    <p className="text-[10px] text-gray-600 mt-1">{relTime}</p>
                  </div>

                  <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0">
                    {isUnread && (
                      <button onClick={() => markRead(n)}
                        className="p-1.5 rounded-lg hover:bg-blue-500/10 text-gray-500 hover:text-blue-400 transition-colors"
                        title="Mark as read">
                        <Check className="w-3.5 h-3.5" />
                      </button>
                    )}
                    <button onClick={() => remove(n)}
                      className="p-1.5 rounded-lg hover:bg-rose-500/10 text-gray-500 hover:text-rose-400 transition-colors"
                      title="Delete">
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>

                  {isUnread && (
                    <span className="w-2 h-2 rounded-full bg-blue-400 flex-shrink-0 mt-1" />
                  )}
                </div>
              );
            })
          )}
        </div>
      </div>
    </AppLayout>
  );
}
