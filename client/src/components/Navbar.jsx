import React from 'react';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { Bell, Moon, Sparkles, Sun } from 'lucide-react';

const Navbar = () => {
  const { user } = useAuth();
  const { isDark, toggleTheme } = useTheme();

  return (
    <header className="h-16 bg-[#050816]/50 backdrop-blur-md border-b border-white/5 flex items-center justify-between px-8 sticky top-0 z-30">
      {/* Search Bar Placeholder or Section Title */}
      <div className="flex items-center gap-2">
        <Sparkles className="h-4 w-4 text-purple-400 animate-pulse" />
        <span className="text-sm font-semibold tracking-wider text-gradient uppercase">Neural Grid Dashboard</span>
      </div>

      {/* User Actions */}
      <div className="flex items-center gap-6">
        <button
          onClick={toggleTheme}
          className="p-2 rounded-lg text-gray-400 hover:bg-white/5 hover:text-white transition-all"
          title={isDark ? 'Switch to light theme' : 'Switch to dark theme'}
          aria-label={isDark ? 'Switch to light theme' : 'Switch to dark theme'}
        >
          {isDark ? <Sun className="h-5 w-5" /> : <Moon className="h-5 w-5" />}
        </button>

        <button className="relative p-2 rounded-lg text-gray-400 hover:bg-white/5 hover:text-white transition-all">
          <Bell className="h-5 w-5" />
          <span className="absolute top-1.5 right-1.5 h-2 w-2 bg-blue-500 rounded-full"></span>
        </button>

        {/* User Card */}
        {user && (
          <div className="flex items-center gap-3 bg-white/5 border border-white/5 px-4 py-1.5 rounded-full">
            <div className="h-7 w-7 rounded-full bg-gradient-to-tr from-blue-500 to-purple-600 flex items-center justify-center text-white font-bold text-xs uppercase shadow-neon">
              {user.name.charAt(0)}
            </div>
            <div className="text-left">
              <p className="text-sm font-medium text-white leading-tight">{user.name}</p>
              <p className="text-[10px] text-gray-400 leading-none">{user.email}</p>
            </div>
          </div>
        )}
      </div>
    </header>
  );
};

export default Navbar;
