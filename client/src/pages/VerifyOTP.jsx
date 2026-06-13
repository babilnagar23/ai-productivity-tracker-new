import React, { useState, useEffect } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { Zap, ArrowRight, ShieldCheck } from 'lucide-react';
import { verifyOTP } from '../services/api';

export default function VerifyOTP() {
  const navigate = useNavigate();
  const location = useLocation();
  const email = location.state?.email || '';

  const [otp, setOtp] = useState(['', '', '', '', '', '']);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const submitOTP = async (code) => {
    if (code.length < 6) {
      setError('Please enter all 6 digits');
      return;
    }
    
    setLoading(true);
    setError('');
    
    try {
      await verifyOTP(email, code);
      sessionStorage.setItem('otpVerified', email);
      navigate('/create-password', { state: { email } });
    } catch (err) {
      const msg = err.message || '';
      if (msg.includes('expired')) setError('Code has expired. Please request a new one.');
      else if (msg.includes('Invalid OTP')) setError(msg);
      else if (msg.includes('Too many')) setError('Too many attempts. Please request a new code.');
      else setError('Verification failed. Please check the code and try again.');
    } finally {
      setLoading(false);
    }
  };

  const handleChange = (element, index) => {
    if (isNaN(element.value)) return;
    
    const newOtp = [...otp];
    newOtp[index] = element.value;
    setOtp(newOtp);

    // Auto focus next
    if (element.nextSibling && element.value !== '') {
      element.nextSibling.focus();
    }

    // Auto submit if all 6 digits filled
    const code = newOtp.join('');
    if (code.length === 6 && !newOtp.includes('')) {
      submitOTP(code);
    }
  };

  const handleKeyDown = (e, index) => {
    if (e.key === 'Backspace' && !otp[index] && e.target.previousSibling) {
      e.target.previousSibling.focus();
    }
  };

  const handlePaste = (e) => {
    e.preventDefault();
    const pastedData = e.clipboardData.getData('text').slice(0, 6).replace(/\D/g, '');
    if (pastedData) {
      const newOtp = [...otp];
      for (let i = 0; i < pastedData.length; i++) {
        newOtp[i] = pastedData[i];
      }
      setOtp(newOtp);
      
      if (pastedData.length === 6) {
        submitOTP(pastedData);
      } else {
        const nextInput = document.querySelector(`input[name="otp"]:nth-child(${pastedData.length + 1})`);
        if (nextInput) nextInput.focus();
      }
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    submitOTP(otp.join(''));
  };

  if (!email) {
    return <div className="text-white text-center p-10">Invalid session. <Link to="/signup" className="text-cyan font-semibold hover:underline">Go back</Link></div>;
  }

  return (
    <div className="min-h-screen bg-void flex items-center justify-center p-4 relative overflow-hidden">
      <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-cyan/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute inset-0 bg-grid-pattern opacity-30" />

      <div className="relative w-full max-w-md animate-fadeInUp">
        <div className="text-center mb-8">
          <div className="w-14 h-14 rounded-2xl bg-cyan flex items-center justify-center mx-auto mb-4 shadow-xl shadow-glow-cyan">
            <ShieldCheck className="w-7 h-7 text-black" />
          </div>
          <h1 className="text-3xl font-hero font-black text-white">Check your email</h1>
          <p className="text-gray-400 mt-2 text-sm">We sent a verification code to <span className="font-semibold text-white">{email}</span></p>
        </div>

        <div className="glass card-3d p-8 space-y-5">
          {error && <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-sm text-center">{error}</div>}

          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="flex justify-center gap-2">
              {otp.map((data, index) => (
                <input
                  className="w-12 h-14 text-center text-xl font-black text-white bg-white/5 border border-white/10 rounded-xl focus:border-cyan/50 focus:bg-white/8 transition-all outline-none"
                  type="text"
                  name="otp"
                  maxLength="1"
                  key={index}
                  value={data}
                  onChange={e => handleChange(e.target, index)}
                  onKeyDown={e => handleKeyDown(e, index)}
                  onPaste={handlePaste}
                  onFocus={e => e.target.select()}
                  disabled={loading}
                />
              ))}
            </div>

            <button type="submit" disabled={loading || otp.join('').length < 6}
              className="w-full py-3 rounded-xl bg-cyan text-black font-bold text-sm hover:opacity-90 transition-all shadow-glow-cyan disabled:opacity-60 disabled:cursor-not-allowed flex items-center justify-center gap-2">
              {loading ? <div className="w-4 h-4 rounded-full border-2 border-black/30 border-t-black animate-spin" /> : <>Verify Account <ArrowRight className="w-4 h-4" /></>}
            </button>
          </form>

          <p className="text-center text-sm text-gray-500">
            Didn't receive the code?{' '}
            <button className="text-cyan font-semibold hover:opacity-80 transition-colors">Resend</button>
          </p>
        </div>
      </div>
    </div>
  );
}
