import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Zap, Mail, Lock, User, Eye, EyeOff, ArrowRight } from 'lucide-react';
import { sendOTP } from '../services/api';

export default function Signup() {
  const { register } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ name: '', email: '', password: '' });
  const [showPw, setShowPw] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [mode, setMode] = useState('direct'); // 'direct' | 'otp'

  const handleDirectSignup = async (e) => {
    e.preventDefault();
    setError(''); setLoading(true);
    try {
      const res = await register(form.name, form.email, form.password);
      if (res?.success) navigate('/dashboard');
      else setError(res?.error || 'Registration failed');
    } catch (err) { setError(err.message || 'Registration failed'); }
    finally { setLoading(false); }
  };

  const handleOTPSignup = async (e) => {
    e.preventDefault();
    setError(''); setLoading(true);
    try {
      await sendOTP(form.email);
      navigate('/verify-otp', { state: { email: form.email } });
    } catch (err) { setError(err.message || 'Failed to send OTP'); }
    finally { setLoading(false); }
  };

  const handleSubmit = mode === 'direct' ? handleDirectSignup : handleOTPSignup;

  const inputClass = `w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-sm text-white
    placeholder-gray-500 focus:outline-none focus:border-cyan/50 focus:bg-white/8 transition-all`;

  return (
    <div className="min-h-screen bg-void flex items-center justify-center p-4 relative overflow-hidden">
      <div className="absolute top-1/3 right-1/4 w-96 h-96 bg-plasma/10 rounded-full blur-3xl pointer-events-none animate-float" />
      <div className="absolute bottom-1/3 left-1/4 w-80 h-80 bg-cyan/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute inset-0 bg-grid-pattern opacity-30" />

      <div className="relative w-full max-w-md animate-fadeInUp">
        <div className="text-center mb-8">
          <div className="w-14 h-14 rounded-2xl bg-cyan flex items-center justify-center mx-auto mb-4 shadow-xl shadow-glow-cyan">
            <Zap className="w-7 h-7 text-black" />
          </div>
          <h1 className="text-3xl font-hero font-black text-white">Create account</h1>
          <p className="text-gray-400 mt-2 text-sm">Start your productivity journey today</p>
        </div>

        <div className="glass card-3d p-8 space-y-5">
          {error && (
            <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-sm text-center">{error}</div>
          )}

          {/* Mode toggle */}
          <div className="flex gap-1 p-1 bg-white/5 rounded-xl border border-white/5">
            {[['direct', 'Direct'], ['otp', 'With OTP']].map(([m, l]) => (
              <button key={m} type="button" onClick={() => setMode(m)}
                className={`flex-1 py-2 rounded-lg text-xs font-bold transition-all
                  ${mode === m ? 'bg-cyan/20 text-cyan border border-cyan/30' : 'text-gray-500 hover:text-white'}`}>
                {l}
              </button>
            ))}
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-400">Full Name</label>
              <div className="relative">
                <User className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none" />
                <input type="text" required className={`${inputClass} pl-10`} placeholder="Your name"
                  value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
              </div>
            </div>

            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-400">Email</label>
              <div className="relative">
                <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none" />
                <input type="email" required className={`${inputClass} pl-10`} placeholder="you@example.com"
                  value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))} />
              </div>
            </div>

            {mode === 'direct' && (
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-gray-400">Password</label>
                <div className="relative">
                  <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none" />
                  <input type={showPw ? 'text' : 'password'} required className={`${inputClass} pl-10 pr-10`}
                    placeholder="Create a strong password"
                    value={form.password} onChange={e => setForm(f => ({ ...f, password: e.target.value }))} />
                  <button type="button" onClick={() => setShowPw(!showPw)}
                    className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-300 transition-colors">
                    {showPw ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>
            )}

            <button type="submit" disabled={loading}
              className="w-full py-3 rounded-xl bg-cyan text-black font-bold text-sm hover:opacity-90 transition-all shadow-glow-cyan disabled:opacity-60 flex items-center justify-center gap-2">
              {loading ? (
                <div className="w-4 h-4 rounded-full border-2 border-white/30 border-t-white animate-spin" />
              ) : (
                <>{mode === 'otp' ? 'Send OTP →' : 'Create Account'} <ArrowRight className="w-4 h-4" /></>
              )}
            </button>
          </form>

          <p className="text-center text-sm text-gray-500">
            Already have an account?{' '}
            <Link to="/login" className="text-cyan font-semibold hover:opacity-80 transition-colors">Sign in →</Link>
          </p>
        </div>
      </div>
    </div>
  );
}
