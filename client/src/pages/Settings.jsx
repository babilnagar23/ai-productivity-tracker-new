import  { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import AppLayout from '../components/layout/AppLayout';
import Button from '../components/ui/Button';
import { useTheme } from '../context/ThemeContext';
import { useAuth } from '../context/AuthContext';
import { apiFetch, calendarApi } from '../services/api';
import { Settings as SettingsIcon, Sun, Moon, Bell, Calendar, Shield, Palette, Check, Download, Trash2, CheckCircle, AlertTriangle, Loader2 } from 'lucide-react';

export default function Settings() {
  const {  toggleTheme, isDark } = useTheme();
  const { logout } = useAuth();
  const navigate = useNavigate();
  const [notifications, setNotifications] = useState(() => {
    const stored = localStorage.getItem('notificationPrefs');
    return stored ? JSON.parse(stored) : {
      tasks: true, calendar: true, achievements: true,
      dailyReminder: true,
    };
  });
  const [saved, setSaved] = useState(false);
  const [saving, setSaving] = useState(false);
  const [googleStatus, setGoogleStatus] = useState({ connected: false, email: '' });
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [deletePassword, setDeletePassword] = useState('');
  const [deleteError, setDeleteError] = useState('');
  const [deleting, setDeleting] = useState(false);
  const [exporting, setExporting] = useState(false);

  // Fetch Google Calendar status on mount
  useEffect(() => {
    const fetchStatus = async () => {
      try {
        const res = await calendarApi.googleStatus();
        setGoogleStatus({ connected: res.connected, email: res.googleEmail || '' });
      } catch { /* non-critical */ }
    };
    fetchStatus();
  }, []);

  const handleSave = () => {
    setSaving(true);
    // Persist notification prefs to localStorage (no backend endpoint for this yet)
    localStorage.setItem('notificationPrefs', JSON.stringify(notifications));
    setSaved(true);
    setSaving(false);
    setTimeout(() => setSaved(false), 2500);
  };

  const togglePref = (key) => setNotifications(p => ({ ...p, [key]: !p[key] }));

  const handleGoogleConnect = async () => {
    try {
      const res = await calendarApi.googleConnect();
      if (res.authUrl) window.location.href = res.authUrl;
    } catch (err) {
      console.error('Failed to get Google OAuth URL');
    }
  };

  const handleGoogleDisconnect = async () => {
    try {
      await calendarApi.googleDisconnect();
      setGoogleStatus({ connected: false, email: '' });
    } catch (err) {
      console.error('Failed to disconnect');
    }
  };

  const handleExportData = async () => {
    setExporting(true);
    try {
      const res = await apiFetch('/auth/export-data');
      const exportData = res?.data || res;
      const blob = new Blob([JSON.stringify(exportData, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `productivity-tracker-export-${new Date().toISOString().split('T')[0]}.json`;
      a.click();
      URL.revokeObjectURL(url);
    } catch (err) {
      console.error('Export failed:', err);
    } finally {
      setExporting(false);
    }
  };

  const handleDeleteAccount = async () => {
    if (!deletePassword) { setDeleteError('Password is required.'); return; }
    setDeleting(true);
    setDeleteError('');
    try {
      await apiFetch('/auth/delete-account', {
        method: 'POST',
        body: JSON.stringify({ password: deletePassword }),
      });
      // Account deleted — clear local state and redirect
      localStorage.removeItem('token');
      localStorage.removeItem('notificationPrefs');
      if (logout) logout();
      navigate('/login');
    } catch (err) {
      setDeleteError(err.message || 'Failed to delete account.');
    } finally {
      setDeleting(false);
    }
  };

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
          <Button onClick={handleSave} icon={saved ? Check : null} variant={saved ? 'success' : 'primary'} size="sm" loading={saving}>
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
                <div className={`w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 ${googleStatus.connected ? 'bg-green-500/20' : 'bg-white'}`}>
                  <span className={`text-sm font-bold ${googleStatus.connected ? 'text-green-400' : ''}`}>G</span>
                </div>
                <div>
                  <p className="text-sm font-semibold text-white">Google Calendar</p>
                  {googleStatus.connected ? (
                    <p className="text-xs text-green-400 flex items-center gap-1">
                      <CheckCircle className="w-3 h-3" /> {googleStatus.email || 'Connected'}
                    </p>
                  ) : (
                    <p className="text-xs text-gray-500">Sync events bidirectionally</p>
                  )}
                </div>
              </div>
              {googleStatus.connected ? (
                <Button size="sm" variant="secondary" onClick={handleGoogleDisconnect}>Disconnect</Button>
              ) : (
                <Button size="sm" variant="secondary" onClick={handleGoogleConnect}>Connect</Button>
              )}
            </div>
          </div>
        </div>

        {/* Privacy */}
        <div className="glass card-3d p-6 space-y-4">
          <h3 className="font-bold text-white flex items-center gap-2"><Shield className="w-4 h-4 text-teal-400" /> Privacy & Data</h3>
          <div className="space-y-3">
            <button
              onClick={handleExportData}
              disabled={exporting}
              className="w-full text-left p-4 rounded-xl bg-white/3 border border-white/5 hover:bg-white/5 transition-colors flex items-center gap-3 disabled:opacity-50"
            >
              {exporting ? <Loader2 className="w-5 h-5 text-cyan flex-shrink-0 animate-spin" /> : <Download className="w-5 h-5 text-cyan flex-shrink-0" />}
              <div>
                <p className="text-sm font-semibold text-white">Export My Data</p>
                <p className="text-xs text-gray-500 mt-0.5">Download all your productivity data as JSON</p>
              </div>
            </button>
            <button
              onClick={() => setShowDeleteConfirm(true)}
              className="w-full text-left p-4 rounded-xl bg-rose-500/5 border border-rose-500/10 hover:bg-rose-500/10 transition-colors flex items-center gap-3"
            >
              <Trash2 className="w-5 h-5 text-rose-400 flex-shrink-0" />
              <div>
                <p className="text-sm font-semibold text-rose-400">Delete Account</p>
                <p className="text-xs text-gray-500 mt-0.5">Permanently delete your account and all data</p>
              </div>
            </button>
          </div>
        </div>

        {/* Delete Confirmation Modal */}
        {showDeleteConfirm && (
          <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-fadeIn">
            <div className="glass card-3d p-6 w-full max-w-sm animate-fadeInUp">
              <div className="flex items-center gap-3 mb-4">
                <AlertTriangle className="w-6 h-6 text-rose-400" />
                <h3 className="text-lg font-bold text-white">Delete Account?</h3>
              </div>
              <p className="text-sm text-gray-400 mb-4">
                This action is permanent and cannot be undone. All your data will be lost.
              </p>
              <div className="mb-4">
                <label className="text-xs text-gray-400 mb-1 block">Enter your password to confirm</label>
                <input
                  type="password"
                  value={deletePassword}
                  onChange={(e) => { setDeletePassword(e.target.value); setDeleteError(''); }}
                  placeholder="Your password"
                  className="w-full bg-white/4 border border-white/10 rounded-xl px-3 py-2.5 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-rose-500/50 transition-colors"
                />
                {deleteError && <p className="text-xs text-rose-400 mt-1.5">{deleteError}</p>}
              </div>
              <div className="flex gap-3">
                <Button variant="secondary" fullWidth onClick={() => { setShowDeleteConfirm(false); setDeletePassword(''); setDeleteError(''); }}>Cancel</Button>
                <Button variant="secondary" fullWidth onClick={handleDeleteAccount} loading={deleting}
                  className="!border-rose-500/30 !text-rose-400 hover:!bg-rose-500/10">
                  Delete Forever
                </Button>
              </div>
            </div>
          </div>
        )}
      </div>
    </AppLayout>
  );
}
