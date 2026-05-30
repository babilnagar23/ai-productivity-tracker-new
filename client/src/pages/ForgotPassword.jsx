import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { forgotPassword } from '../services/api';
import { Zap, Mail, ArrowRight, Loader2, ShieldCheck, AlertCircle } from 'lucide-react';

const ForgotPassword = () => {
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [successMessage, setSuccessMessage] = useState('');
  const [errorMessage, setErrorMessage] = useState('');
  const [cooldown, setCooldown] = useState(0);

  useEffect(() => {
    let timer;
    if (cooldown > 0) {
      timer = setInterval(() => {
        setCooldown((prev) => prev - 1);
      }, 1000);
    }
    return () => clearInterval(timer);
  }, [cooldown]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (cooldown > 0) return;

    setLoading(true);
    setSuccessMessage('');
    setErrorMessage('');

    try {
      const res = await forgotPassword(email);
      if (res.success || res.message) {
        setSuccessMessage(res.message || 'If an account exists, a reset link has been sent.');
        setCooldown(60); // Start 60s cooldown timer
      } else {
        setErrorMessage(res.error || 'System anomaly. Reset transmission aborted.');
      }
    } catch (err) {
      setErrorMessage(err.message || 'Transmission error. Neural link unavailable.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-background bg-grid-pattern flex items-center justify-center py-12 px-6 relative overflow-hidden">
      {/* Cyberpunk Neon Background Orbs */}
      <div className="absolute top-1/4 left-1/4 w-80 h-80 bg-blue-500/10 rounded-full blur-[100px] -z-10 animate-pulse"></div>
      <div className="absolute bottom-1/4 right-1/4 w-80 h-80 bg-purple-500/10 rounded-full blur-[100px] -z-10 animate-pulse"></div>

      <div className="w-full max-w-md glass-card p-8 space-y-8 border border-white/10 shadow-glass">
        {/* Brand logo & header */}
        <div className="text-center space-y-2">
          <Link to="/" className="inline-flex items-center gap-2 mb-4">
            <div className="bg-gradient-to-r from-blue-500 to-purple-600 p-2 rounded-xl text-white shadow-neon">
              <Zap className="h-5 w-5" />
            </div>
            <span className="font-extrabold text-lg text-white">ProductiveAI</span>
          </Link>
          <h2 className="text-2xl font-bold text-white tracking-tight">Key Bypass Protocol</h2>
          <p className="text-sm text-gray-400">Initialize security override transmission</p>
        </div>

        {successMessage && (
          <div className="bg-blue-950/40 border border-blue-500/30 text-blue-300 p-4 rounded-xl text-xs font-semibold flex items-start gap-3 animate-fade-in shadow-[0_0_15px_rgba(59,130,246,0.15)]">
            <ShieldCheck className="h-5 w-5 text-blue-400 shrink-0 mt-0.5" />
            <div>
              <p className="font-bold text-white uppercase tracking-wider mb-1">Transmission Success</p>
              <p className="text-gray-300 leading-relaxed">{successMessage}</p>
            </div>
          </div>
        )}

        {errorMessage && (
          <div className="bg-red-950/40 border border-red-500/30 text-red-400 p-4 rounded-xl text-xs font-semibold flex items-start gap-3 animate-shake shadow-[0_0_15px_rgba(239,68,68,0.15)]">
            <AlertCircle className="h-5 w-5 text-red-500 shrink-0 mt-0.5" />
            <div>
              <p className="font-bold text-white uppercase tracking-wider mb-1">Protocol Anomaly</p>
              <p className="text-gray-300 leading-relaxed">{errorMessage}</p>
            </div>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Email input */}
          <div className="space-y-2">
            <label className="text-xs font-semibold uppercase tracking-wider text-gray-400">Security Email Address</label>
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
                disabled={loading}
                className="w-full pl-10 pr-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-gray-500 text-sm focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500/20 transition-all duration-300 disabled:opacity-50"
              />
            </div>
          </div>

          {/* Submit Button with loader & cooldown */}
          <button
            type="submit"
            disabled={loading || cooldown > 0}
            className="w-full py-3.5 rounded-xl bg-gradient-to-r from-blue-600 to-purple-600 font-semibold text-sm shadow-neon hover:opacity-90 transition-all duration-300 text-white flex items-center justify-center gap-2 disabled:opacity-55 disabled:cursor-not-allowed"
          >
            {loading ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin text-white" />
                <span>Broadcasting Override Link...</span>
              </>
            ) : cooldown > 0 ? (
              <span>Resend Cooldown ({cooldown}s)</span>
            ) : (
              <>
                <span>Transmit Override Sequence</span>
                <ArrowRight className="h-4 w-4" />
              </>
            )}
          </button>
        </form>

        <div className="text-center pt-2">
          <p className="text-xs text-gray-400">
            Remembered your access key?{' '}
            <Link to="/login" className="text-blue-400 font-semibold hover:underline">
              Decrypt Operator
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
};

export default ForgotPassword;
