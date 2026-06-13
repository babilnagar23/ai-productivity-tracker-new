import  { useState } from 'react';
import {  useParams, useNavigate } from 'react-router-dom';
import { Lock, Eye, EyeOff, ArrowRight, CheckCircle2, XCircle } from 'lucide-react';
import { resetPassword } from '../services/api';

export default function ResetPassword() {
  const { uid, token } = useParams();
  const navigate = useNavigate();
  const [form, setForm] = useState({ password: '', confirm: '' });
  const [showPw, setShowPw] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  // Rules
  const rules = {
    length: form.password.length >= 8,
    upper: /[A-Z]/.test(form.password),
    lower: /[a-z]/.test(form.password),
    number: /[0-9]/.test(form.password),
    special: /[!@#$%^&*(),.?":{}|<>]/.test(form.password),
  };
  const validCount = Object.values(rules).filter(Boolean).length;
  
  // Strength calculation
  let strength = 'Weak';
  let strengthColor = 'bg-rose-500';
  if (validCount >= 3) { strength = 'Medium'; strengthColor = 'bg-yellow-500'; }
  if (validCount === 5) { strength = 'Strong'; strengthColor = 'bg-emerald-500'; }
  if (form.password.length === 0) { strength = ''; strengthColor = 'bg-white/10'; }

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (validCount !== 5) { setError('Please meet all password requirements'); return; }
    if (form.password !== form.confirm) { setError('Passwords do not match'); return; }
    
    setLoading(true); setError('');
    try {
      await resetPassword(uid, token, form.password);
      setSuccess(true);
      setTimeout(() => navigate('/login'), 3000);
    } catch (err) {
      setError(err.message || 'Failed to reset password. Link may be invalid or expired.');
    } finally {
      setLoading(false);
    }
  };

  const inputClass = `w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-sm text-white
    placeholder-gray-500 focus:outline-none focus:border-cyan/50 focus:bg-white/8 transition-all disabled:opacity-50`;

  const RuleItem = ({ valid, label }) => (
    <div className={`flex items-center gap-2 text-xs transition-colors ${valid ? 'text-emerald-400' : 'text-gray-500'}`}>
      {valid ? <CheckCircle2 className="w-3.5 h-3.5" /> : <XCircle className="w-3.5 h-3.5" />}
      <span>{label}</span>
    </div>
  );

  return (
    <div className="min-h-screen bg-void flex items-center justify-center p-4 relative overflow-hidden">
      <div className="absolute top-1/4 right-1/4 w-96 h-96 bg-cyan/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute inset-0 bg-grid-pattern opacity-30" />

      <div className="relative w-full max-w-md animate-fadeInUp">
        <div className="text-center mb-8">
          <div className="w-14 h-14 rounded-2xl bg-cyan flex items-center justify-center mx-auto mb-4 shadow-xl shadow-glow-cyan">
            <Lock className="w-7 h-7 text-black" />
          </div>
          <h1 className="text-3xl font-hero font-black text-white">New Password</h1>
          <p className="text-gray-400 mt-2 text-sm">Create a new secure password</p>
        </div>

        <div className="glass card-3d p-8 space-y-5">
          {error && <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-sm text-center">{error}</div>}
          
          {success ? (
            <div className="text-center space-y-4">
              <div className="p-4 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-sm">
                Password reset successfully! Redirecting to login...
              </div>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-gray-400">New Password</label>
                <div className="relative">
                  <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none" />
                  <input type={showPw ? 'text' : 'password'} required className={`${inputClass} pl-10 pr-10`}
                    placeholder="Create new password"
                    value={form.password} onChange={e => setForm(f => ({ ...f, password: e.target.value }))} disabled={loading} />
                  <button type="button" onClick={() => setShowPw(!showPw)} disabled={loading} className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-300">
                    {showPw ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                  </button>
                </div>
              </div>

              {/* Strength Meter */}
              <div className="space-y-2 py-1">
                <div className="flex gap-1 h-1">
                  {[1, 2, 3].map(i => (
                    <div key={i} className={`flex-1 rounded-full transition-all duration-300 ${
                      i === 1 && validCount > 0 ? strengthColor :
                      i === 2 && validCount >= 3 ? strengthColor :
                      i === 3 && validCount === 5 ? strengthColor : 'bg-white/10'
                    }`} />
                  ))}
                </div>
                <p className={`text-xs text-right font-semibold ${strength === 'Strong' ? 'text-emerald-400' : strength === 'Medium' ? 'text-yellow-500' : strength === 'Weak' ? 'text-rose-500' : 'text-gray-500'}`}>
                  {strength}
                </p>
                
                <div className="grid grid-cols-2 gap-2 mt-2">
                  <RuleItem valid={rules.length} label="Minimum 8 characters" />
                  <RuleItem valid={rules.upper} label="1 uppercase letter" />
                  <RuleItem valid={rules.lower} label="1 lowercase letter" />
                  <RuleItem valid={rules.number} label="1 number" />
                  <RuleItem valid={rules.special} label="1 special character" />
                </div>
              </div>

              <div className="space-y-1.5">
                <label className="text-xs font-semibold text-gray-400">Confirm Password</label>
                <div className="relative">
                  <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none" />
                  <input type={showPw ? 'text' : 'password'} required className={`${inputClass} pl-10`}
                    placeholder="Confirm new password"
                    value={form.confirm} onChange={e => setForm(f => ({ ...f, confirm: e.target.value }))} disabled={loading} />
                </div>
              </div>

              <button type="submit" disabled={loading || validCount !== 5 || form.password !== form.confirm}
                className="w-full py-3 rounded-xl bg-cyan text-black font-bold text-sm hover:opacity-90 transition-all shadow-glow-cyan disabled:opacity-60 disabled:cursor-not-allowed flex items-center justify-center gap-2 mt-4">
                {loading ? <div className="w-4 h-4 rounded-full border-2 border-black/30 border-t-black animate-spin" /> : <>Reset Password <ArrowRight className="w-4 h-4" /></>}
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}
