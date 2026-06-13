import  { useState, useEffect } from 'react';
import AppLayout from '../components/layout/AppLayout';
import Button from '../components/ui/Button';
import StatCard from '../components/ui/StatCard';
import { useAuth } from '../context/AuthContext';
import { apiFetch } from '../services/api';
import { X, User, Lock, Camera, Trophy, Flame, Timer, CheckSquare, Save } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';

const AVATARS = [
  'avatar1', 'avatar2', 'avatar3', 'avatar4',
  'avatar5', 'avatar6', 'avatar7', 'avatar8'
];

export default function Profile() {
  const { user, refreshUser } = useAuth();
  const [form, setForm] = useState({ name: '', email: '' });
  const [pwForm, setPwForm] = useState({ current_password: '', new_password: '', confirm_password: '' });
  const [saving, setSaving] = useState(false);
  const [savingPw, setSavingPw] = useState(false);
  const [msg, setMsg] = useState('');
  const [error, setError] = useState('');
  const [pwError, setPwError] = useState('');
  const [pwMsg, setPwMsg] = useState('');
  const [showAvatarModal, setShowAvatarModal] = useState(false);

  useEffect(() => {
    if (user) setForm({ name: user.name || user.username || '', email: user.email || '' });
  }, [user]);

  const handleSaveProfile = async (e) => {
    e.preventDefault();
    setSaving(true); setMsg(''); setError('');
    try {
      await apiFetch('/auth/me', { method: 'PATCH', body: JSON.stringify({ name: form.name }) });
      await refreshUser();
      setMsg('Profile updated successfully!');
    } catch (err) { setError(err.message || 'Failed to update'); }
    finally { setSaving(false); }
  };

  const handleSaveAvatar = async (avatarId) => {
    try {
      setSaving(true);
      await apiFetch('/auth/me', { method: 'PATCH', body: JSON.stringify({ avatar: avatarId }) });
      await refreshUser();
      setMsg('Avatar updated successfully!');
      setShowAvatarModal(false);
    } catch (err) {
      setError('Failed to update avatar');
    } finally {
      setSaving(false);
    }
  };

  const handleChangePassword = async (e) => {
    e.preventDefault();
    if (pwForm.new_password !== pwForm.confirm_password) { setPwError('Passwords do not match'); return; }
    setSavingPw(true); setPwMsg(''); setPwError('');
    try {
      await apiFetch('/auth/change-password', { method: 'POST', body: JSON.stringify({
        current_password: pwForm.current_password,
        new_password: pwForm.new_password,
      })});
      setPwMsg('Password changed!');
      setPwForm({ current_password: '', new_password: '', confirm_password: '' });
    } catch (err) { setPwError(err.message || 'Failed to change password'); }
    finally { setSavingPw(false); }
  };

  const inputClass = 'w-full bg-white/4 border border-white/10 rounded-xl px-3 py-2.5 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-cyan/50 transition-colors';
  const level = Math.floor((user?.xp || 0) / 100) + 1;
  const xpPct = (user?.xp || 0) % 100;

  return (
    <AppLayout title="Profile">
      <div className="max-w-2xl mx-auto space-y-6 animate-fadeInUp">
        <h1 className="text-xl font-hero font-extrabold text-white flex items-center gap-2">
          <User className="w-5 h-5 text-cyan" /> Your Profile
        </h1>

        {/* Avatar + stats */}
        <div className="glass card-3d p-6 flex flex-col sm:flex-row items-center gap-6">
          <div 
            className="relative flex-shrink-0 cursor-pointer group"
            onClick={() => !saving && setShowAvatarModal(true)}
          >
            <div className="w-20 h-20 rounded-2xl bg-cyan overflow-hidden flex items-center justify-center text-3xl font-black text-black transition-all">
              {user?.avatar && user.avatar.startsWith('avatar') ? (
                <img src={`/avatars/${user.avatar}.jpg`} alt="Avatar" className="w-full h-full object-cover" />
              ) : (
                (user?.name || user?.username || 'U').charAt(0).toUpperCase()
              )}
            </div>
            <div className="absolute -bottom-1 -right-1 w-7 h-7 rounded-xl bg-carbon border border-white/10 flex items-center justify-center group-hover:scale-110 group-hover:bg-cyan transition-all">
              <Camera className="w-3.5 h-3.5 text-gray-400 group-hover:text-black transition-colors" />
            </div>
          </div>
          <div className="flex-1 text-center sm:text-left">
            <h2 className="text-xl font-black text-white">{user?.name || user?.username}</h2>
            <p className="text-sm text-gray-400">{user?.email}</p>
            <div className="flex items-center gap-2 mt-2 flex-wrap justify-center sm:justify-start">
              <span className="text-xs font-semibold text-cyan">Level {level}</span>
              <div className="flex-1 h-1.5 rounded-full bg-white/5 overflow-hidden max-w-[120px]">
                <div className="h-full rounded-full bg-cyan transition-all duration-700" style={{ width: `${xpPct}%` }} />
              </div>
              <span className="text-[10px] text-gray-500">{xpPct}/100 XP</span>
            </div>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          <StatCard label="Streak" value={`${user?.streak || 0}d`} icon={Flame} color="#F59E0B" gradient="from-orange-500/5" />
          <StatCard label="XP" value={user?.xp || 0} icon={Trophy} color="#BF5AF2" gradient="from-plasma/5" />
          <StatCard label="Level" value={level} icon={Trophy} color="#00FFFF" gradient="from-cyan/5" />
          <StatCard label="Focus" value="—" icon={Timer} color="#14B8A6" gradient="from-teal-500/5" />
        </div>

        {/* Edit profile */}
        <div className="glass card-3d p-6 space-y-4">
          <h3 className="font-bold text-white flex items-center gap-2"><User className="w-4 h-4 text-cyan" /> Edit Profile</h3>
          {msg && <p className="text-xs text-green-400 bg-green-500/10 border border-green-500/20 rounded-lg px-3 py-2">{msg}</p>}
          {error && <p className="text-xs text-rose-400 bg-rose-500/10 border border-rose-500/20 rounded-lg px-3 py-2">{error}</p>}
          <form onSubmit={handleSaveProfile} className="space-y-4">
            <div>
              <label className="text-xs font-semibold text-gray-400 mb-1.5 block">Display Name</label>
              <input className={inputClass} value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} placeholder="Your name" />
            </div>
            <div>
              <label className="text-xs font-semibold text-gray-400 mb-1.5 block">Email</label>
              <input className={`${inputClass} opacity-60`} value={form.email} disabled />
            </div>
            <Button type="submit" loading={saving} icon={Save}>Save Changes</Button>
          </form>
        </div>

        {/* Change password */}
        <div className="glass card-3d p-6 space-y-4">
          <h3 className="font-bold text-white flex items-center gap-2"><Lock className="w-4 h-4 text-plasma" /> Change Password</h3>
          {pwMsg && <p className="text-xs text-green-400 bg-green-500/10 border border-green-500/20 rounded-lg px-3 py-2">{pwMsg}</p>}
          {pwError && <p className="text-xs text-rose-400 bg-rose-500/10 border border-rose-500/20 rounded-lg px-3 py-2">{pwError}</p>}
          <form onSubmit={handleChangePassword} className="space-y-4">
            <div>
              <label className="text-xs font-semibold text-gray-400 mb-1.5 block">Current Password</label>
              <input type="password" className={inputClass} value={pwForm.current_password}
                onChange={e => setPwForm(f => ({ ...f, current_password: e.target.value }))} placeholder="Current password" />
            </div>
            <div>
              <label className="text-xs font-semibold text-gray-400 mb-1.5 block">New Password</label>
              <input type="password" className={inputClass} value={pwForm.new_password}
                onChange={e => setPwForm(f => ({ ...f, new_password: e.target.value }))} placeholder="New password" />
            </div>
            <div>
              <label className="text-xs font-semibold text-gray-400 mb-1.5 block">Confirm Password</label>
              <input type="password" className={inputClass} value={pwForm.confirm_password}
                onChange={e => setPwForm(f => ({ ...f, confirm_password: e.target.value }))} placeholder="Confirm new password" />
            </div>
            <Button type="submit" loading={savingPw} variant="secondary" icon={Lock}>Change Password</Button>
          </form>
        </div>
      </div>

      <AnimatePresence>
        {showAvatarModal && (
          <motion.div 
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4"
          >
            <motion.div 
              initial={{ scale: 0.9, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.9, opacity: 0 }}
              className="glass card-3d w-full max-w-2xl p-6 relative"
            >
              <button 
                onClick={() => setShowAvatarModal(false)}
                className="absolute top-4 right-4 p-2 rounded-xl hover:bg-white/10 transition-colors text-gray-400 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
              
              <h2 className="text-xl font-bold text-white mb-1">Choose Your Avatar</h2>
              <p className="text-sm text-gray-400 mb-6">Select one of your available avatars</p>
              
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                {AVATARS.map(avatarId => (
                  <button
                    key={avatarId}
                    onClick={() => handleSaveAvatar(avatarId)}
                    disabled={saving}
                    className={`relative aspect-square rounded-2xl overflow-hidden border-2 transition-all duration-300 ${
                      user?.avatar === avatarId 
                        ? 'border-cyan shadow-[0_0_20px_rgba(0,255,255,0.3)] scale-105' 
                        : 'border-transparent hover:border-white/20 hover:scale-105'
                    }`}
                  >
                    <img 
                      src={`/avatars/${avatarId}.jpg`} 
                      alt={avatarId} 
                      className="w-full h-full object-cover"
                    />
                    {user?.avatar === avatarId && (
                      <div className="absolute inset-0 bg-cyan/20 flex items-center justify-center">
                        <div className="bg-cyan text-black rounded-full p-1">
                          <CheckSquare className="w-5 h-5" />
                        </div>
                      </div>
                    )}
                  </button>
                ))}
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </AppLayout>
  );
}
