import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { Zap, Mail, ArrowRight } from 'lucide-react';
import { sendOTP, checkEmail } from '../services/api';

export default function Signup() {
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [fieldError, setFieldError] = useState('');

  const validate = () => {
    if (!email) {
      setFieldError('Email is required');
      return false;
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      setFieldError('Invalid email address');
      return false;
    }
    setFieldError('');
    return true;
  };

  const handleOTPSignup = async (e) => {
    e.preventDefault();
    setError(''); 
    
    if (!validate()) return;
    
    setLoading(true);
    try {
      const emailCheck = await checkEmail(email);
      if (!emailCheck.data?.available) {
        setFieldError('This email already has an account');
        setLoading(false);
        return;
      }

      await sendOTP(email);
      navigate('/verify-otp', { state: { email } });
    } catch (err) { 
      setError(err.message || 'Failed to send OTP'); 
    } finally { 
      setLoading(false); 
    }
  };

  const inputClass = `w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-sm text-white
    placeholder-gray-500 focus:outline-none focus:border-cyan/50 focus:bg-white/8 transition-all disabled:opacity-50 disabled:cursor-not-allowed`;

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
          <h1 className="text-3xl font-hero font-black text-white">Create Account</h1>
          <p className="text-gray-400 mt-2 text-sm">Enter your email to begin verification</p>
        </div>

        <div className="glass card-3d p-8 space-y-5">
          {error && (
            <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-sm text-center">{error}</div>
          )}

          <form onSubmit={handleOTPSignup} className="space-y-4">
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-400">Email</label>
              <div className="relative">
                <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none" />
                <input 
                  type="email" 
                  disabled={loading}
                  className={`${inputClass} pl-10 ${fieldError ? 'border-rose-500/50 focus:border-rose-500' : ''}`} 
                  placeholder="you@example.com"
                  value={email} 
                  onChange={e => {
                    setEmail(e.target.value);
                    if (fieldError) setFieldError('');
                  }} 
                />
              </div>
              {fieldError && (
                <div className="flex items-center justify-between mt-1">
                  <p className="text-rose-400 text-xs">{fieldError}</p>
                  {fieldError.includes('already has an account') && (
                    <Link to="/login" className="text-xs text-cyan hover:opacity-80 transition-colors">
                      Login Instead
                    </Link>
                  )}
                </div>
              )}
            </div>

            <button type="submit" disabled={loading}
              className="w-full py-3 rounded-xl bg-cyan text-black font-bold text-sm hover:opacity-90 transition-all shadow-glow-cyan disabled:opacity-60 disabled:cursor-not-allowed flex items-center justify-center gap-2">
              {loading ? (
                <div className="w-4 h-4 rounded-full border-2 border-black/30 border-t-black animate-spin" />
              ) : (
                <>Continue <ArrowRight className="w-4 h-4" /></>
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
