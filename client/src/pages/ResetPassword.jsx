import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { resetPassword } from '../services/api';
import { Zap, Lock, ArrowRight, Loader2, Eye, EyeOff, ShieldCheck, AlertCircle, RefreshCw } from 'lucide-react';

const ResetPassword = () => {
  const { uid, token } = useParams();
  const navigate = useNavigate();

  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState('');
  const [redirectCount, setRedirectCount] = useState(5);

  // Password strength calculation
  const [strength, setStrength] = useState({ score: 0, label: 'No Key Entered', color: 'bg-white/10' });

  useEffect(() => {
    if (!password) {
      setStrength({ score: 0, label: 'No Key Entered', color: 'bg-white/10' });
      return;
    }

    let score = 0;
    if (password.length >= 6) score += 1;
    if (password.length >= 10) score += 1;
    if (/[A-Z]/.test(password)) score += 1;
    if (/[0-9]/.test(password)) score += 1;
    if (/[^A-Za-z0-9]/.test(password)) score += 1;

    let label = 'Extremely Weak';
    let color = 'bg-red-500 shadow-[0_0_10px_rgba(239,68,68,0.5)]';

    if (score === 2) {
      label = 'Weak Decryption Key';
      color = 'bg-orange-500 shadow-[0_0_10px_rgba(249,115,22,0.5)]';
    } else if (score === 3) {
      label = 'Moderate Security';
      color = 'bg-yellow-500 shadow-[0_0_10px_rgba(234,179,8,0.5)]';
    } else if (score === 4) {
      label = 'Strong Authentication';
      color = 'bg-green-500 shadow-[0_0_10px_rgba(34,197,94,0.5)]';
    } else if (score >= 5) {
      label = 'Military Grade Mainframe Key';
      color = 'bg-cyan-500 shadow-[0_0_10px_rgba(6,182,212,0.5)]';
    }

    setStrength({ score, label, color });
  }, [password]);

  // Redirect countdown
  useEffect(() => {
    let timer;
    if (success && redirectCount > 0) {
      timer = setTimeout(() => {
        setRedirectCount((prev) => prev - 1);
      }, 1000);
    } else if (success && redirectCount === 0) {
      navigate('/login');
    }
    return () => clearTimeout(timer);
  }, [success, redirectCount, navigate]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    // Pre-validations
    if (password.length < 6) {
      setError('Key length must be at least 6 characters.');
      return;
    }
    if (password !== confirmPassword) {
      setError('Authentication key mismatch. Please verify confirmation key.');
      return;
    }

    setLoading(true);

    try {
      const res = await resetPassword(uid, token, password);
      if (res.success) {
        setSuccess(true);
      } else {
        setError(res.error || 'Decryption key sync failure.');
      }
    } catch (err) {
      setError(err.message || 'Key override failed. Link may have expired or been used.');
    } finally {
      setLoading(false);
    }
  };

  if (success) {
    return (
      <div className="min-h-screen bg-background bg-grid-pattern flex items-center justify-center py-12 px-6 relative overflow-hidden">
        {/* Animated Cyber success screen */}
        <div className="absolute top-1/4 left-1/4 w-80 h-80 bg-green-500/10 rounded-full blur-[100px] -z-10 animate-pulse"></div>
        
        <div className="w-full max-w-md glass-card p-8 space-y-8 border border-green-500/30 shadow-[0_0_50px_rgba(34,197,94,0.15)] text-center relative overflow-hidden">
          <div className="absolute inset-0 bg-gradient-to-t from-green-500/5 to-transparent pointer-events-none"></div>
          
          <div className="inline-flex bg-gradient-to-r from-green-500 to-emerald-600 p-4 rounded-full text-white shadow-[0_0_20px_rgba(34,197,94,0.4)] mb-2 animate-bounce">
            <ShieldCheck className="h-8 w-8" />
          </div>

          <h2 className="text-2xl font-black text-white tracking-wider uppercase">Key Configured</h2>
          
          <div className="space-y-4 font-mono text-sm bg-black/40 border border-green-500/20 rounded-xl p-5 text-green-400 text-left">
            <p className="flex justify-between"><span>[STATUS]</span> <span className="text-white">SUCCESS</span></p>
            <p className="flex justify-between"><span>[CIPHER]</span> <span className="text-white">RE-ENCRYPTED</span></p>
            <p className="flex justify-between"><span>[AUTHS]</span> <span className="text-white">VALIDATED</span></p>
            <p className="border-t border-green-500/20 pt-2 text-center text-xs text-gray-400 font-sans">
              System access fully restored. Redirecting to mainframe terminal in:
            </p>
            <p className="text-center font-bold text-2xl text-white font-sans mt-1 animate-pulse">
              {redirectCount}s
            </p>
          </div>

          <button
            onClick={() => navigate('/login')}
            className="w-full py-3.5 rounded-xl bg-gradient-to-r from-green-600 to-emerald-600 font-semibold text-sm shadow-[0_0_15px_rgba(34,197,94,0.3)] hover:opacity-90 transition-all duration-300 text-white flex items-center justify-center gap-2"
          >
            <span>Decrypt Immediately</span>
            <ArrowRight className="h-4 w-4" />
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background bg-grid-pattern flex items-center justify-center py-12 px-6 relative overflow-hidden">
      {/* Background Orbs */}
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
          <h2 className="text-2xl font-bold text-white tracking-tight">Overwrite Access Key</h2>
          <p className="text-sm text-gray-400">Establish a new security decryption profile</p>
        </div>

        {error && (
          <div className="bg-red-950/40 border border-red-500/30 text-red-400 p-4 rounded-xl text-xs font-semibold flex items-start gap-3 animate-shake shadow-[0_0_15px_rgba(239,68,68,0.15)]">
            <AlertCircle className="h-5 w-5 text-red-500 shrink-0 mt-0.5" />
            <div>
              <p className="font-bold text-white uppercase tracking-wider mb-1">Key Generation Blocked</p>
              <p className="text-gray-300 leading-relaxed">{error}</p>
            </div>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-6">
          {/* New Password input */}
          <div className="space-y-2">
            <label className="text-xs font-semibold uppercase tracking-wider text-gray-400">New Authentication Key</label>
            <div className="relative">
              <span className="absolute inset-y-0 left-0 pl-3.5 flex items-center text-gray-500">
                <Lock className="h-4 w-4" />
              </span>
              <input
                type={showPassword ? 'text' : 'password'}
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                disabled={loading}
                className="w-full pl-10 pr-10 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-gray-500 text-sm focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500/20 transition-all duration-300 disabled:opacity-50"
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-500 hover:text-white transition-colors"
              >
                {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
              </button>
            </div>

            {/* Strength meter UI */}
            <div className="mt-2.5 space-y-1.5">
              <div className="flex justify-between items-center text-[10px] uppercase font-bold tracking-widest text-gray-400">
                <span>Key Complexity</span>
                <span className="text-gray-300">{strength.label}</span>
              </div>
              <div className="h-1 w-full bg-white/5 rounded-full overflow-hidden flex gap-1">
                {[1, 2, 3, 4, 5].map((step) => (
                  <div
                    key={step}
                    className={`h-full flex-1 rounded-full transition-all duration-500 ${
                      step <= strength.score ? strength.color : 'bg-white/10'
                    }`}
                  ></div>
                ))}
              </div>
            </div>
          </div>

          {/* Confirm Password input */}
          <div className="space-y-2">
            <label className="text-xs font-semibold uppercase tracking-wider text-gray-400">Confirm Authentication Key</label>
            <div className="relative">
              <span className="absolute inset-y-0 left-0 pl-3.5 flex items-center text-gray-500">
                <Lock className="h-4 w-4" />
              </span>
              <input
                type={showConfirmPassword ? 'text' : 'password'}
                required
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                placeholder="••••••••"
                disabled={loading}
                className="w-full pl-10 pr-10 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-gray-500 text-sm focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500/20 transition-all duration-300 disabled:opacity-50"
              />
              <button
                type="button"
                onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                className="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-500 hover:text-white transition-colors"
              >
                {showConfirmPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
              </button>
            </div>
          </div>

          {/* Submit Button */}
          <button
            type="submit"
            disabled={loading}
            className="w-full py-3.5 rounded-xl bg-gradient-to-r from-blue-600 to-purple-600 font-semibold text-sm shadow-neon hover:opacity-90 transition-all duration-300 text-white flex items-center justify-center gap-2 disabled:opacity-55 disabled:cursor-not-allowed"
          >
            {loading ? (
              <>
                <Loader2 className="h-4 w-4 animate-spin text-white" />
                <span>Synchronizing Override Sequence...</span>
              </>
            ) : (
              <>
                <span>Commit Key Overwrite</span>
                <ArrowRight className="h-4 w-4" />
              </>
            )}
          </button>
        </form>

        <div className="text-center pt-2">
          <p className="text-xs text-gray-400">
            Cancel bypass sequence?{' '}
            <Link to="/login" className="text-blue-400 font-semibold hover:underline">
              Return to Decrypt Terminal
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
};

export default ResetPassword;
