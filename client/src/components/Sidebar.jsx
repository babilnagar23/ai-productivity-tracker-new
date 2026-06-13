import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import {
  LayoutDashboard, CheckSquare, RotateCcw, Timer, Calendar, BarChart3, Bell, Trophy, Settings, User,
  Sparkles, ChevronLeft, ChevronRight, Zap, LogOut
} from 'lucide-react';

const navItems = [
  { to: '/dashboard',     icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/todos',         icon: CheckSquare,     label: 'Tasks' },  { to: '/routines',      icon: RotateCcw,       label: 'Daily Routines' },
  { to: '/focus',         icon: Timer,           label: 'Focus' },
  { to: '/calendar',      icon: Calendar,        label: 'Calendar' },
  { to: '/analytics',     icon: BarChart3,       label: 'Analytics' },
  { to: '/ai-coach',      icon: Sparkles,        label: 'AI Assistant' },
  { to: '/achievements',  icon: Trophy,          label: 'Achievements' },
  { to: '/notifications', icon: Bell,            label: 'Notifications' },
];

const bottomItems = [
  { to: '/profile',  icon: User,     label: 'Profile' },
  { to: '/settings', icon: Settings, label: 'Settings' },
];

export default function Sidebar({ collapsed, onToggle, unreadCount = 0 }) {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const level = user ? Math.floor((user.xp || 0) / 100) + 1 : 1;
  const xpInLevel = (user?.xp || 0) % 100;

  return (
    <aside
      className={`
        flex flex-col h-screen bg-carbon border-r border-smoke
        transition-all duration-300 ease-in-out flex-shrink-0
        ${collapsed ? 'w-16' : 'w-60'}
      `}
    >
      {/* Logo + collapse toggle */}
      <div className={`flex items-center border-b border-smoke h-16 px-3 ${collapsed ? 'justify-center' : 'justify-between'}`}>
        {!collapsed && (
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-cyan/10 flex items-center justify-center shadow-md border border-cyan/30">
              <Zap className="w-4 h-4 text-cyan" />
            </div>
            <span className="font-hero font-extrabold text-sm tracking-tight text-white">Productive<span className="text-cyan">AI</span></span>
          </div>
        )}
        {collapsed && (
          <div className="w-8 h-8 rounded-xl bg-cyan/10 flex items-center justify-center border border-cyan/30">
            <Zap className="w-4 h-4 text-cyan" />
          </div>
        )}
        <button
          onClick={onToggle}
          className="p-1.5 rounded-lg hover:bg-white/5 text-gray-500 hover:text-gray-300 transition-colors"
          title={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          {collapsed ? <ChevronRight className="w-4 h-4" /> : <ChevronLeft className="w-4 h-4" />}
        </button>
      </div>

      {/* Navigation */}
      <nav className="flex-1 py-4 px-2 space-y-0.5 overflow-y-auto">
        {navItems.map(({ to, icon: Icon, label }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) => `
              group relative flex items-center gap-3 px-2.5 py-2.5 rounded-xl
              text-sm font-medium transition-all duration-200
              ${isActive
                ? 'bg-cyan/10 text-cyan border border-cyan/20'
                : 'text-gray-400 hover:text-white hover:bg-white/5'
              }
            `}
            title={collapsed ? label : undefined}
          >
            {({ isActive }) => (
              <>
                {isActive && (
                  <span className="absolute left-0 top-1/2 -translate-y-1/2 w-0.5 h-5 bg-cyan rounded-full" />
                )}
                <div className="relative">
                  <Icon className="w-4.5 h-4.5 flex-shrink-0" style={{width:'18px',height:'18px'}} />
                  {label === 'Notifications' && unreadCount > 0 && (
                    <span className="absolute -top-1.5 -right-1.5 w-4 h-4 bg-rose-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center">
                      {unreadCount > 9 ? '9+' : unreadCount}
                    </span>
                  )}
                </div>
                {!collapsed && <span className="truncate">{label}</span>}
              </>
            )}
          </NavLink>
        ))}
      </nav>

      {/* Bottom items */}
      <div className="px-2 py-2 border-t border-white/5 space-y-0.5">
        {bottomItems.map(({ to, icon: Icon, label }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) => `
              flex items-center gap-3 px-2.5 py-2.5 rounded-xl
              text-sm font-medium transition-all duration-200
              ${isActive
                ? 'bg-cyan/10 text-cyan border border-cyan/20'
                : 'text-gray-400 hover:text-white hover:bg-white/5'
              }
            `}
            title={collapsed ? label : undefined}
          >
            <Icon style={{width:'18px',height:'18px'}} className="flex-shrink-0" />
            {!collapsed && <span className="truncate">{label}</span>}
          </NavLink>
        ))}

        <button
          onClick={handleLogout}
          className="w-full flex items-center gap-3 px-2.5 py-2.5 rounded-xl text-sm font-medium text-gray-400 hover:text-rose-400 hover:bg-rose-500/10 transition-all duration-200"
          title={collapsed ? 'Logout' : undefined}
        >
          <LogOut style={{width:'18px',height:'18px'}} className="flex-shrink-0" />
          {!collapsed && <span>Logout</span>}
        </button>
      </div>

      {/* User profile card */}
      {!collapsed && user && (
        <div className="p-3 border-t border-smoke">
          <NavLink to="/profile" className="flex items-center gap-3 p-2 rounded-xl hover:bg-white/5 transition-colors group">
            <div className="w-8 h-8 rounded-full bg-plasma/20 flex items-center justify-center text-xs font-bold text-plasma flex-shrink-0 border border-plasma/30 overflow-hidden">
              {user.avatar && user.avatar.startsWith('avatar') ? (
                <img src={`/avatars/${user.avatar}.jpg`} alt="Avatar" className="w-full h-full object-cover" />
              ) : (
                (user.name || user.username || 'U').charAt(0).toUpperCase()
              )}
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-xs font-semibold text-white truncate">{user.name || user.username}</p>
              <p className="text-[10px] text-gray-500">Level {level} · {xpInLevel}/100 XP</p>
            </div>
          </NavLink>
          {/* XP bar */}
          <div className="mt-2 px-2">
            <div className="h-1 rounded-full bg-white/5 overflow-hidden">
              <div
                className="h-full rounded-full bg-cyan transition-all duration-700"
                style={{ width: `${xpInLevel}%` }}
              />
            </div>
          </div>
        </div>
      )}
    </aside>
  );
}
