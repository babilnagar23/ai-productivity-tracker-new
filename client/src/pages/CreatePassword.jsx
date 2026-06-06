import React, { useState, useEffect } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Zap, Lock, ShieldAlert, CheckCircle, XCircle, ArrowRight, Eye, EyeOff } from 'lucide-react';

const CreatePassword = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const email = location.state?.email || '';

  // Redirect if email is not present in state
  useEffect(() => {
    if (!email) {
      navigate('/signup');
    }
  }, [email, navigate]);

  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { completeOTPRegistration } = useAuth();

  // Password requirements state
  const [requirements, setRequirements] = useState({
    length: false,
    uppercase: false,
    number: false,
    special: false,
  });

  // Calculate requirements and strength level
  useEffect(() => {
    setRequirements({
      length: password.length >= 8,
      uppercase: /[A-Z]/.test(password),
      number: /[0-9]/.test(password),
      special: /[^A-Za-z0-9]/.test(password),
    });
  }, [password]);

  const getStrengthScore = () => {
    let score = 0;
    if (requirements.length) score++;
    if (requirements.uppercase) score++;
    if (requirements.number) score++;
    if (requirements.special) score++;
    return score;
  };

  const strengthScore = getStrengthScore();

  const getStrengthDetails = () => {
    switch (strengthScore) {
      case 0:
        return { label: 'CRITICAL WEAKNESS', color: 'bg-red-500/30 border-red-500', text: 'text-red-400', width: 'w-0' };
      case 1:
        return { label: 'VULNERABLE KEY', color: 'bg-red-500/20 border-red-500/40', text: 'text-red-400', width: 'w-1/4 bg-red-500 shadow-[0_0_10px_rgba(239,68,68,0.5)]' };
      case 2:
        return { label: 'ADEQUATE ENCRYPTION', color: 'bg-yellow-500/10 border-yellow-500/30', text: 'text-yellow-400', width: 'w-2/4 bg-yellow-500 shadow-[0_0_10px_rgba(234,179,8,0.5)]' };
      case 3:
        return { label: 'HIGH LEVEL SECURITY', color: 'bg-blue-500/10 border-blue-500/30', text: 'text-blue-400', width: 'w-3/4 bg-blue-500 shadow-[0_0_10px_rgba(59,130,246,0.5)]' };
      case 4:
        return { label: 'MILITARY-GRADE COMPLIANT', color: 'bg-emerald-500/10 border-emerald-500/30', text: 'text-emerald-400', width: 'w-full bg-emerald-500 shadow-[0_0_10px_rgba(16,185,129,0.5)]' };
      default:
        return { label: 'SECURE', color: 'bg-gray-500/10 border-gray-500/30', text: 'text-gray-400', width: 'w-0' };
    }
  };

  const strength = getStrengthDetails();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (strengthScore < 4) {
      setError('Password must meet all security protocols before system provisioning.');
      return;
    }

    if (password !== confirmPassword) {
      setError('Passwords do not match. Verify encryption keys.');
      return;
    }

    setLoading(true);

    try {
      const res = await completeOTPRegistration(email, password, confirmPassword);
      if (res.success) {
        navigate('/dashboard');
      } else {
        setError(res.error || 'Account provisioning failed.');
      }
    } catch (err) {
      setError(err.message || 'An unexpected error occurred during account provisioning.');
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
          <h2 className="text-2xl font-bold text-white tracking-tight">Provision Profile</h2>
          <p className="text-sm text-gray-400">Establish your neural authorization keys</p>
          <p className="text-xs font-mono text-blue-400 break-all">{email}</p>
        </div>

        {error && (
          <div className="bg-red-500/10 border border-red-500/20 text-red-400 p-3.5 rounded-xl text-xs font-semibold text-center animate-shake">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-5">
          {/* Password input */}
          <div className="space-y-2">
            <label className="text-xs font-semibold uppercase tracking-wider text-gray-400">Authentication Key</label>
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
                className="w-full pl-10 pr-10 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-gray-500 text-sm focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500/20 transition-all duration-300"
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute inset-y-0 right-0 pr-3 flex items-center text-gray-500 hover:text-white transition-colors"
              >
                {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
              </button>
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
                className="w-full pl-10 pr-10 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-gray-500 text-sm focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500/20 transition-all duration-300"
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

          {/* Password strength meter */}
          <div className="space-y-3 pt-2">
            <div className="flex items-center justify-between text-xs font-semibold">
              <span className="text-gray-400">KEY SECURITY LEVEL:</span>
              <span className={`font-mono tracking-wider ${strength.text}`}>
                {strength.label}
              </span>
            </div>
            {/* Strength Bar */}
            <div className="h-1.5 w-full bg-white/5 rounded-full overflow-hidden border border-white/5">
              <div className={`h-full transition-all duration-500 ${strength.width}`}></div>
            </div>

            {/* Checklist of security requirements */}
            <div className="grid grid-cols-2 gap-2 pt-1 text-[11px]">
              <div className="flex items-center gap-1.5 text-gray-400">
                {requirements.length ? (
                  <CheckCircle className="h-3.5 w-3.5 text-emerald-400 shrink-0" />
                ) : (
                  <XCircle className="h-3.5 w-3.5 text-gray-600 shrink-0" />
                )}
                <span>8+ Characters</span>
              </div>
              <div className="flex items-center gap-1.5 text-gray-400">
                {requirements.uppercase ? (
                  <CheckCircle className="h-3.5 w-3.5 text-emerald-400 shrink-0" />
                ) : (
                  <XCircle className="h-3.5 w-3.5 text-gray-600 shrink-0" />
                )}
                <span>Uppercase Letter</span>
              </div>
              <div className="flex items-center gap-1.5 text-gray-400">
                {requirements.number ? (
                  <CheckCircle className="h-3.5 w-3.5 text-emerald-400 shrink-0" />
                ) : (
                  <XCircle className="h-3.5 w-3.5 text-gray-600 shrink-0" />
                )}
                <span>Numeric Digit</span>
              </div>
              <div className="flex items-center gap-1.5 text-gray-400">
                {requirements.special ? (
                  <CheckCircle className="h-3.5 w-3.5 text-emerald-400 shrink-0" />
                ) : (
                  <XCircle className="h-3.5 w-3.5 text-gray-600 shrink-0" />
                )}
                <span>Special Character</span>
              </div>
            </div>
          </div>

          {/* Submit Button */}
          <button
            type="submit"
            disabled={loading || strengthScore < 4}
            className="w-full mt-4 py-3.5 rounded-xl bg-gradient-to-r from-blue-600 to-purple-600 font-semibold text-sm shadow-neon hover:opacity-90 transition-all duration-300 text-white flex items-center justify-center gap-2 disabled:opacity-40 disabled:cursor-not-allowed cursor-pointer"
          >
            {loading ? 'Provisioning Account...' : 'Provision Operator Profile'}
            {!loading && <ArrowRight className="h-4 w-4" />}
          </button>
        </form>

        <div className="text-center pt-2">
          <Link to="/signup" className="text-xs text-gray-500 hover:text-white transition-colors">
            Abort Provisioning Sequence
          </Link>
        </div>
      </div>
    </div>
  );
};

export default CreatePassword;
