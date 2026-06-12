import React, { useState } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Zap, ArrowRight, ShieldCheck } from 'lucide-react';

export default function VerifyOTP() {
  const { completeOTPRegistration } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const email = location.state?.email || '';

  const [otp, setOtp] = useState(['', '', '', '', '', '']);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleChange = (element, index) => {
    if (isNaN(element.value)) return false;
    setOtp([...otp.map((d, idx) => (idx === index ? element.value : d))]);
    if (element.nextSibling && element.value !== '') {
      element.nextSibling.focus();
    }
  };

  const handleKeyDown = (e, index) => {
    if (e.key === 'Backspace' && !otp[index] && e.target.previousSibling) {
      e.target.previousSibling.focus();
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const code = otp.join('');
    if (code.length < 6) { setError('Please enter all 6 digits'); return; }
    
    setLoading(true); setError('');
    try {
      // In a real flow, you'd verify OTP then ask for password, or do both.
      // We will just verify it here.
      // (Depends on backend implementation, assuming we pass email and OTP to verify endpoint, and then go to create password)
      // For now, let's just mock moving to create-password
      navigate('/create-password', { state: { email, otp: code } });
    } catch (err) {
      setError(err.message || 'Verification failed');
    } finally {
      setLoading(false);
    }
  };

  if (!email) {
    return <div className="text-white text-center p-10">Invalid session. <Link to="/signup" className="text-blue-400">Go back</Link></div>;
  }

  return (
    <div className="min-h-screen bg-[#050816] flex items-center justify-center p-4 relative overflow-hidden">
      <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-blue-500/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute inset-0 bg-grid-pattern opacity-30" />

      <div className="relative w-full max-w-md animate-fadeInUp">
        <div className="text-center mb-8">
          <div className="w-14 h-14 rounded-2xl bg-gradient-primary flex items-center justify-center mx-auto mb-4 shadow-xl glow-blue">
            <ShieldCheck className="w-7 h-7 text-white" />
          </div>
          <h1 className="text-3xl font-black text-white">Check your email</h1>
          <p className="text-gray-400 mt-2 text-sm">We sent a verification code to <span className="font-semibold text-white">{email}</span></p>
        </div>

        <div className="glass-card-premium p-8 space-y-5">
          {error && <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-sm text-center">{error}</div>}

          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="flex justify-center gap-2">
              {otp.map((data, index) => (
                <input
                  className="w-12 h-14 text-center text-xl font-black text-white bg-white/5 border border-white/10 rounded-xl focus:border-blue-500/50 focus:bg-white/8 transition-all outline-none"
                  type="text"
                  name="otp"
                  maxLength="1"
                  key={index}
                  value={data}
                  onChange={e => handleChange(e.target, index)}
                  onKeyDown={e => handleKeyDown(e, index)}
                  onFocus={e => e.target.select()}
                />
              ))}
            </div>

            <button type="submit" disabled={loading}
              className="w-full py-3 rounded-xl bg-gradient-primary text-white font-bold text-sm hover:opacity-90 transition-all glow-blue disabled:opacity-60 flex items-center justify-center gap-2">
              {loading ? <div className="w-4 h-4 rounded-full border-2 border-white/30 border-t-white animate-spin" /> : <>Verify Account <ArrowRight className="w-4 h-4" /></>}
            </button>
          </form>

          <p className="text-center text-sm text-gray-500">
            Didn't receive the code?{' '}
            <button className="text-blue-400 font-semibold hover:text-blue-300 transition-colors">Resend</button>
          </p>
        </div>
      </div>
    </div>
  );
}
