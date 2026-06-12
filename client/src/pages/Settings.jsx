import React, { useState } from 'react';
import AppLayout from '../components/layout/AppLayout';
import Button from '../components/ui/Button';
import { useTheme } from '../context/ThemeContext';
import { Settings as SettingsIcon, Sun, Moon, Bell, Calendar, Shield, Palette, Check } from 'lucide-react';

export default function Settings() {
  const { theme, toggleTheme, isDark } = useTheme();
  const [notifications, setNotifications] = useState({
    tasks: true, calendar: true, achievements: true,
    dailyReminder: true,
  });
  const [saved, setSaved] = useState(false);

  const handleSave = () => {
    setSaved(true);
    setTimeout(() => setSaved(false), 2500);
  };

  const togglePref = (key) => setNotifications(p => ({ ...p, [key]: !p[key] }));

  const Toggle = ({ label, sub, enabled, onToggle }) => (
    <div className="flex items-center justify-between py-3 border-b border-white/5 last:border-0">
      <div>
        <p className="text-sm font-semibold text-white">{label}</p>
        {sub && <p className="text-xs text-gray-500 mt-0.5">{sub}</p>}
      </div>
      <button
        onClick={onToggle}
        className={`relative w-11 h-6 rounded-full transition-all duration-300 ${enabled ? 'bg-cyan' : 'bg-white/10'}`}
      >
        <span className={`absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white transition-all duration-300 ${enabled ? 'translate-x-5' : ''}`} />
      </button>
    </div>
  );

  return (
    <AppLayout title="Settings">
      <div className="max-w-2xl mx-auto space-y-6 animate-fadeInUp">
        <div className="flex items-center justify-between">
          <h1 className="text-xl font-hero font-extrabold text-white flex items-center gap-2">
            <SettingsIcon className="w-5 h-5 text-gray-400 animate-spin-slow" /> Settings
          </h1>
          <Button onClick={handleSave} icon={saved ? Check : null} variant={saved ? 'success' : 'primary'} size="sm">
            {saved ? 'Saved!' : 'Save Changes'}
          </Button>
        </div>

        {/* Appearance */}
        <div className="glass card-3d p-6 space-y-4">
          <h3 className="font-bold text-white flex items-center gap-2"><Palette className="w-4 h-4 text-plasma" /> Appearance</h3>
          <div className="grid grid-cols-2 gap-3">
            <button
              onClick={() => !isDark && toggleTheme()}
              className={`flex items-center gap-3 p-4 rounded-xl border transition-all
                ${isDark ? 'border-cyan/40 bg-cyan/10' : 'border-white/5 bg-white/3 hover:bg-white/6'}`}
            >
              <Moon className={`w-5 h-5 ${isDark ? 'text-cyan' : 'text-gray-500'}`} />
              <div className="text-left">
                <p className={`text-sm font-semibold ${isDark ? 'text-white' : 'text-gray-400'}`}>Dark Mode</p>
                <p className="text-[10px] text-gray-500">Default · Easy on eyes</p>
              </div>
              {isDark && <Check className="w-4 h-4 text-cyan ml-auto" />}
            </button>
            <button
              onClick={() => isDark && toggleTheme()}
              className={`flex items-center gap-3 p-4 rounded-xl border transition-all
                ${!isDark ? 'border-cyan/40 bg-cyan/10' : 'border-white/5 bg-white/3 hover:bg-white/6'}`}
            >
              <Sun className={`w-5 h-5 ${!isDark ? 'text-yellow-400' : 'text-gray-500'}`} />
              <div className="text-left">
                <p className={`text-sm font-semibold ${!isDark ? 'text-white' : 'text-gray-400'}`}>Light Mode</p>
                <p className="text-[10px] text-gray-500">Bright & clean</p>
              </div>
              {!isDark && <Check className="w-4 h-4 text-cyan ml-auto" />}
            </button>
          </div>
        </div>

        {/* Notifications */}
        <div className="glass card-3d p-6 space-y-1">
          <h3 className="font-bold text-white flex items-center gap-2 mb-3"><Bell className="w-4 h-4 text-cyan" /> Notifications</h3>
          <Toggle label="Task Reminders" sub="Get reminded of upcoming due dates" enabled={notifications.tasks} onToggle={() => togglePref('tasks')} />
          <Toggle label="Calendar Alerts" sub="Event notifications and reminders" enabled={notifications.calendar} onToggle={() => togglePref('calendar')} />
          <Toggle label="Achievement Alerts" sub="Be notified when you unlock achievements" enabled={notifications.achievements} onToggle={() => togglePref('achievements')} />

          <Toggle label="Daily Check-in" sub="Evening reminder to log your day" enabled={notifications.dailyReminder} onToggle={() => togglePref('dailyReminder')} />
        </div>

        {/* Calendar integration */}
        <div className="glass card-3d p-6 space-y-4">
          <h3 className="font-bold text-white flex items-center gap-2"><Calendar className="w-4 h-4 text-green-400" /> Calendar Integration</h3>
          <div className="p-4 rounded-xl bg-white/3 border border-white/5">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-lg bg-white flex items-center justify-center flex-shrink-0">
                  <span className="text-sm">G</span>
                </div>
                <div>
                  <p className="text-sm font-semibold text-white">Google Calendar</p>
                  <p className="text-xs text-gray-500">Sync events bidirectionally</p>
                </div>
              </div>
              <Button size="sm" variant="secondary">Connect</Button>
            </div>
          </div>
        </div>

        {/* Privacy */}
        <div className="glass card-3d p-6 space-y-4">
          <h3 className="font-bold text-white flex items-center gap-2"><Shield className="w-4 h-4 text-teal-400" /> Privacy & Data</h3>
          <div className="space-y-3">
            <button className="w-full text-left p-4 rounded-xl bg-white/3 border border-white/5 hover:bg-white/5 transition-colors">
              <p className="text-sm font-semibold text-white">Export My Data</p>
              <p className="text-xs text-gray-500 mt-0.5">Download all your productivity data as JSON</p>
            </button>
            <button className="w-full text-left p-4 rounded-xl bg-rose-500/5 border border-rose-500/10 hover:bg-rose-500/10 transition-colors">
              <p className="text-sm font-semibold text-rose-400">Delete Account</p>
              <p className="text-xs text-gray-500 mt-0.5">Permanently delete your account and all data</p>
            </button>
          </div>
        </div>
      </div>
    </AppLayout>
  );
}
