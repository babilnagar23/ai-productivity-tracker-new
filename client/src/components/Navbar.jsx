import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { Bell, Moon, Sparkles, Sun } from 'lucide-react';

const Navbar = () => {
  const { user } = useAuth();
  const { isDark, toggleTheme } = useTheme();

  return (
    <header className="h-16 bg-carbon/80 backdrop-blur-md border-b border-smoke flex items-center justify-between px-8 sticky top-0 z-30">
      {/* Search Bar Placeholder or Section Title */}
      <div className="flex items-center gap-2">
        <Sparkles className="h-4 w-4 text-plasma animate-pulse" />
        <span className="text-sm font-hero font-extrabold tracking-wider text-white uppercase">Neural Grid Dashboard</span>
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
          <span className="absolute top-1.5 right-1.5 h-2 w-2 bg-cyan rounded-full shadow-[0_0_8px_rgba(0,255,255,0.8)]"></span>
        </button>

        {/* User Card */}
        {user && (
          <div className="flex items-center gap-3 bg-white/5 border border-smoke px-4 py-1.5 rounded-full">
            <div className="h-7 w-7 rounded-full bg-plasma/20 border border-plasma/30 flex items-center justify-center text-plasma font-bold text-xs uppercase shadow-neon">
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
