import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { 
  LayoutDashboard, 
  CalendarRange, 
  Sparkles, 
  BarChart3, 
  LogOut,
  Zap,
  Award,
  Settings,
  CalendarDays
} from 'lucide-react';

const Sidebar = () => {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const menuItems = [
    { name: 'Dashboard', path: '/dashboard', icon: LayoutDashboard },
    { name: 'Google Calendar', path: '/calendar', icon: CalendarDays },
    { name: 'Daily Routines', path: '/routines', icon: CalendarRange },
    { name: 'AI Assistant', path: '/ai-coach', icon: Sparkles },
    { name: 'Analytics', path: '/analytics', icon: BarChart3 },
    { name: 'Customization', path: '/customization', icon: Settings },
  ];

  const handleLogout = () => {
    logout();
    navigate('/');
  };

  return (
    <aside className="w-64 bg-[#0d1126] border-r border-white/5 flex flex-col min-h-screen text-gray-300">
      {/* Brand Header */}
      <div className="p-6 border-b border-white/5 flex items-center gap-3">
        <div className="bg-gradient-to-r from-blue-500 to-purple-600 p-2 rounded-xl text-white shadow-neon">
          <Zap className="h-5 w-5" />
        </div>
        <div>
          <h1 className="font-bold text-lg text-white tracking-wide">ProductiveAI</h1>

        </div>
      </div>

      {/* Navigation Menu */}
      <nav className="flex-1 px-4 py-6 space-y-2">
        {menuItems.map((item) => (
          <NavLink
            key={item.name}
            to={item.path}
            className={({ isActive }) => 
              `flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-200 group ${
                isActive 
                  ? 'bg-blue-600/10 text-blue-400 border border-blue-500/20' 
                  : 'hover:bg-white/5 hover:text-white border border-transparent'
              }`
            }
          >
            <item.icon className="h-5 w-5 transition-transform group-hover:scale-110" />
            <span className="font-medium text-sm">{item.name}</span>
          </NavLink>
        ))}
      </nav>

      {/* User Stats Card in Sidebar */}
      {user && (
        <div className="mx-4 my-2 p-4 bg-white/5 rounded-2xl border border-white/5">
          <div className="flex justify-between items-center text-sm">
            <span className="text-gray-400 font-semibold text-xs uppercase tracking-wider">Streak Count:</span>
            <span className="text-orange-400 font-extrabold flex items-center gap-1">
              🔥 {user.streak || 0} Days
            </span>
          </div>
        </div>
      )}

      {/* Logout Footer */}
      <div className="p-4 border-t border-white/5">
        <button
          onClick={handleLogout}
          className="w-full flex items-center gap-3 px-4 py-3 rounded-xl text-red-400 hover:bg-red-500/10 border border-transparent hover:border-red-500/20 transition-all duration-200"
        >
          <LogOut className="h-5 w-5" />
          <span className="font-medium text-sm">Logout</span>
        </button>
      </div>
    </aside>
  );
};

export default Sidebar;
