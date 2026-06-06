import React, { useState, useEffect, useRef } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { verifyOTP, sendOTP } from '../services/api';
import { Zap, ShieldCheck, ArrowRight, RefreshCw } from 'lucide-react';

const VerifyOTP = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const email = location.state?.email || '';

  // Redirect if email is not present in state
  useEffect(() => {
    if (!email) {
      navigate('/signup');
    }
  }, [email, navigate]);

  const [otp, setOtp] = useState(['', '', '', '', '', '']);
  const [error, setError] = useState('');
  const [successMsg, setSuccessMsg] = useState('Verification code sent to your email.');
  const [loading, setLoading] = useState(false);
  const [resending, setResending] = useState(false);
  const [countdown, setCountdown] = useState(60);

  const inputRefs = useRef([]);

  // Countdown timer for resending OTP
  useEffect(() => {
    if (countdown === 0) return;
    const timer = setTimeout(() => {
      setCountdown((prev) => prev - 1);
    }, 1000);
    return () => clearTimeout(timer);
  }, [countdown]);

  const handleChange = (index, value) => {
    // Only allow numbers
    if (value && !/^\d$/.test(value)) return;

    const newOtp = [...otp];
    newOtp[index] = value;
    setOtp(newOtp);
    setError('');

    // Auto-focus next input
    if (value && index < 5) {
      inputRefs.current[index + 1].focus();
    }
  };

  const handleKeyDown = (index, e) => {
    // Backspace: clear and go back
    if (e.key === 'Backspace') {
      if (!otp[index] && index > 0) {
        const newOtp = [...otp];
        newOtp[index - 1] = '';
        setOtp(newOtp);
        inputRefs.current[index - 1].focus();
      } else {
        const newOtp = [...otp];
        newOtp[index] = '';
        setOtp(newOtp);
      }
    }
  };

  const handlePaste = (e) => {
    e.preventDefault();
    const pastedData = e.clipboardData.getData('text').trim();
    if (!/^\d{6}$/.test(pastedData)) {
      setError('Please paste a valid 6-digit verification code.');
      return;
    }

    const digits = pastedData.split('');
    setOtp(digits);
    setError('');

    // Focus last input after pasting
    inputRefs.current[5].focus();
  };

  const handleResend = async () => {
    if (countdown > 0 || resending) return;
    setResending(true);
    setError('');
    setSuccessMsg('');

    try {
      const res = await sendOTP(email);
      if (res.success) {
        setSuccessMsg('A fresh verification code has been dispatched.');
        setCountdown(60);
      } else {
        setError(res.error || 'Failed to resend code.');
      }
    } catch (err) {
      setError(err.message || 'An error occurred during resending.');
    } finally {
      setResending(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const otpCode = otp.join('');
    if (otpCode.length !== 6) {
      setError('Please enter all 6 digits of the authentication code.');
      return;
    }

    setError('');
    setSuccessMsg('');
    setLoading(true);

    try {
      const res = await verifyOTP(email, otpCode);
      if (res.success) {
        navigate('/create-password', { state: { email } });
      } else {
        setError(res.error || 'Invalid verification code.');
      }
    } catch (err) {
      setError(err.message || 'Verification failed. Please try again.');
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
          <h2 className="text-2xl font-bold text-white tracking-tight">Security Validation</h2>
          <p className="text-sm text-gray-400">Enter the 6-digit authentication code sent to</p>
          <p className="text-xs font-mono text-blue-400 break-all">{email}</p>
        </div>

        {error && (
          <div className="bg-red-500/10 border border-red-500/20 text-red-400 p-3.5 rounded-xl text-xs font-semibold text-center animate-shake">
            {error}
          </div>
        )}

        {successMsg && (
          <div className="bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 p-3.5 rounded-xl text-xs font-semibold text-center">
            {successMsg}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-6">
          {/* OTP Digit Box inputs */}
          <div className="space-y-2">
            <label className="text-xs font-semibold uppercase tracking-wider text-gray-400 block text-center">
              Authentication Code
            </label>
            <div className="flex justify-between gap-2" onPaste={handlePaste}>
              {otp.map((digit, index) => (
                <input
                  key={index}
                  type="text"
                  maxLength={1}
                  value={digit}
                  ref={(el) => (inputRefs.current[index] = el)}
                  onChange={(e) => handleChange(index, e.target.value)}
                  onKeyDown={(e) => handleKeyDown(index, e)}
                  className="w-12 h-14 text-center text-xl font-bold font-mono rounded-xl bg-white/5 border border-white/10 text-white placeholder-gray-500 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500/20 transition-all duration-300"
                />
              ))}
            </div>
          </div>

          {/* Submit Button */}
          <button
            type="submit"
            disabled={loading}
            className="w-full py-3.5 rounded-xl bg-gradient-to-r from-blue-600 to-purple-600 font-semibold text-sm shadow-neon hover:opacity-90 transition-all duration-300 text-white flex items-center justify-center gap-2 disabled:opacity-55 cursor-pointer"
          >
            {loading ? 'Verifying Code...' : 'Verify Code'}
            {!loading && <ShieldCheck className="h-4 w-4" />}
          </button>
        </form>

        {/* Resend and Actions */}
        <div className="space-y-4 pt-2 text-center">
          <div className="text-xs text-gray-400">
            {countdown > 0 ? (
              <span>Resend available in <strong className="text-blue-400 font-mono">{countdown}s</strong></span>
            ) : (
              <button
                type="button"
                onClick={handleResend}
                disabled={resending}
                className="text-blue-400 font-semibold hover:underline flex items-center justify-center gap-1 mx-auto disabled:opacity-50 cursor-pointer"
              >
                <RefreshCw className={`h-3 w-3 ${resending ? 'animate-spin' : ''}`} />
                Resend Authentication Code
              </button>
            )}
          </div>

          <div className="text-xs">
            <Link to="/signup" className="text-gray-500 hover:text-white transition-colors">
              Abort Protocol & Start Over
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
};

export default VerifyOTP;
