import { NavLink } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { Bell, Sun, Moon } from 'lucide-react';

export default function Topbar({ title, unreadCount = 0 }) {
  const { user } = useAuth();
  const { theme, toggleTheme } = useTheme();

  return (
    <header className="h-16 flex items-center gap-4 px-6 border-b border-smoke bg-carbon/80 backdrop-blur-xl flex-shrink-0 sticky top-0 z-20">
      {/* Page title */}
      {title && (
        <h1 className="text-lg font-hero font-extrabold text-white hidden sm:block">{title}</h1>
      )}



      <div className="flex items-center gap-2 ml-auto">
        {/* Theme toggle */}
        <button
          onClick={toggleTheme}
          className="p-2 rounded-xl hover:bg-white/5 text-gray-400 hover:text-white transition-colors"
          title="Toggle theme"
        >
          {theme === 'dark' ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
        </button>

        {/* Notifications */}
        <NavLink
          to="/notifications"
          className="relative p-2 rounded-xl hover:bg-white/5 text-gray-400 hover:text-white transition-colors"
          title="Notifications"
        >
          <Bell className="w-4 h-4" />
          {unreadCount > 0 && (
            <span className="absolute top-1 right-1 w-2 h-2 bg-rose-500 rounded-full ring-2 ring-[#0d1126]" />
          )}
        </NavLink>

        {/* Profile avatar */}
        <NavLink
          to="/profile"
          className="flex items-center gap-2 p-1.5 pr-3 rounded-xl hover:bg-white/5 transition-colors"
        >
          <div className="w-7 h-7 rounded-full bg-plasma/20 border border-plasma/30 flex items-center justify-center text-xs font-bold text-plasma overflow-hidden">
            {user?.avatar && user.avatar.startsWith('avatar') ? (
              <img src={`/avatars/${user.avatar}.jpg`} alt="Avatar" className="w-full h-full object-cover" />
            ) : (
              (user?.name || user?.username || 'U').charAt(0).toUpperCase()
            )}
          </div>
          <span className="text-sm font-medium text-white hidden sm:block">
            {user?.name || user?.username}
          </span>
        </NavLink>
      </div>
    </header>
  );
}
