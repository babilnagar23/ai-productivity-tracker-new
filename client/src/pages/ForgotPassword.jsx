import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import { Mail, ArrowRight, LockKeyhole } from 'lucide-react';
import { forgotPassword } from '../services/api';

export default function ForgotPassword() {
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true); setError('');
    try {
      await forgotPassword(email);
      setSuccess(true);
    } catch (err) {
      setError(err.message || 'Failed to send reset link');
    } finally {
      setLoading(false);
    }
  };

  const inputClass = `w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-sm text-white
    placeholder-gray-500 focus:outline-none focus:border-cyan/50 focus:bg-white/8 transition-all disabled:opacity-50`;

  return (
    <div className="min-h-screen bg-void flex items-center justify-center p-4 relative overflow-hidden">
      <div className="absolute top-1/4 right-1/4 w-96 h-96 bg-cyan/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute inset-0 bg-grid-pattern opacity-30" />

      <div className="relative w-full max-w-md animate-fadeInUp">
        <div className="text-center mb-8">
          <div className="w-14 h-14 rounded-2xl bg-cyan flex items-center justify-center mx-auto mb-4 shadow-xl shadow-glow-cyan">
            <LockKeyhole className="w-7 h-7 text-black" />
          </div>
          <h1 className="text-3xl font-hero font-black text-white">Reset Password</h1>
          <p className="text-gray-400 mt-2 text-sm">Enter your email to receive a reset link</p>
        </div>

        <div className="glass card-3d p-8 space-y-5">
          {error && <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-sm text-center">{error}</div>}
          
          {success ? (
            <div className="text-center space-y-4">
              <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-sm">
                If an account exists with {email}, you will receive a password reset link shortly.
              </div>
              <Link to="/login" className="block w-full py-3 rounded-xl bg-white/5 text-white font-bold text-sm hover:bg-white/10 transition-all">
                Return to Login
              </Link>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-gray-400">Email Address</label>
                <div className="relative">
                  <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none" />
                  <input type="email" required className={`${inputClass} pl-10`} placeholder="you@example.com"
                    value={email} onChange={e => setEmail(e.target.value)} disabled={loading} />
                </div>
              </div>

              <button type="submit" disabled={loading || !email}
                className="w-full py-3 rounded-xl bg-cyan text-black font-bold text-sm hover:opacity-90 transition-all shadow-glow-cyan disabled:opacity-60 flex items-center justify-center gap-2">
                {loading ? <div className="w-4 h-4 rounded-full border-2 border-black/30 border-t-black animate-spin" /> : <>Send Reset Link <ArrowRight className="w-4 h-4" /></>}
              </button>
            </form>
          )}

          <p className="text-center text-sm text-gray-500">
            Remember your password?{' '}
            <Link to="/login" className="text-cyan font-semibold hover:opacity-80 transition-colors">Sign in →</Link>
          </p>
        </div>
      </div>
    </div>
  );
}
