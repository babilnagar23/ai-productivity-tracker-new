import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { sendOTP } from '../services/api';
import { Zap, Mail, ArrowRight } from 'lucide-react';

const Signup = () => {
  const [email, setEmail] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const res = await sendOTP(email);
      if (res.success) {
        // Navigate to verification page and pass the email in state
        navigate('/verify-otp', { state: { email } });
      } else {
        setError(res.error || 'Failed to send verification code. Please try again.');
      }
    } catch (err) {
      setError(err.message || 'An unexpected error occurred. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-background bg-grid-pattern flex items-center justify-center py-12 px-6 relative overflow-hidden">
      {/* Background Orbs */}
      <div className="absolute top-1/4 left-1/4 w-80 h-80 bg-blue-500/10 rounded-full blur-[100px] -z-10 animate-pulse"></div>
      <div className="absolute bottom-1/4 right-1/4 w-80 h-80 bg-purple-500/10 rounded-full blur-[100px] -z-10 animate-pulse"></div>

      <div className="w-full max-w-md glass-card p-8 space-y-8 border border-white/10 shadow-glass animate-fade-in">
        {/* Brand logo & header */}
        <div className="text-center space-y-2">
          <Link to="/" className="inline-flex items-center gap-2 mb-4">
            <div className="bg-gradient-to-r from-blue-500 to-purple-600 p-2 rounded-xl text-white shadow-neon">
              <Zap className="h-5 w-5" />
            </div>
            <span className="font-extrabold text-lg text-white">Productivity Tracker</span>
          </Link>
          <h2 className="text-2xl font-bold text-white tracking-tight">Create Operator Profile</h2>
          <p className="text-sm text-gray-400">Initialize your email verification sequence</p>
        </div>

        {error && (
          <div className="bg-red-500/10 border border-red-500/20 text-red-400 p-3.5 rounded-xl text-xs font-semibold text-center animate-shake">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-5">
          {/* Email input */}
          <div className="space-y-2">
            <label className="text-xs font-semibold uppercase tracking-wider text-gray-400">Security Email</label>
            <div className="relative">
              <span className="absolute inset-y-0 left-0 pl-3.5 flex items-center text-gray-500">
                <Mail className="h-4 w-4" />
              </span>
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="operator@productive.ai"
                className="w-full pl-10 pr-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-gray-500 text-sm focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500/20 transition-all duration-300"
              />
            </div>
          </div>

          {/* Submit Button */}
          <button
            type="submit"
            disabled={loading}
            className="w-full py-3.5 rounded-xl bg-gradient-to-r from-blue-600 to-purple-600 font-semibold text-sm shadow-neon hover:opacity-90 transition-all duration-300 text-white flex items-center justify-center gap-2 disabled:opacity-55 cursor-pointer"
          >
            {loading ? 'Initializing Verification...' : 'Initialize Verification Sequence'}
            {!loading && <ArrowRight className="h-4 w-4" />}
          </button>
        </form>

        <div className="text-center pt-2">
          <p className="text-xs text-gray-400">
            Already registered?{' '}
            <Link to="/login" className="text-blue-400 font-semibold hover:underline">
              Decrypt Operator
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
};

export default Signup;
