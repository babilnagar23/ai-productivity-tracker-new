import  { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Zap, Mail, Lock, Eye, EyeOff, ArrowRight } from 'lucide-react';

export default function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ email: '', password: '', rememberMe: false });
  const [showPw, setShowPw] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [fieldErrors, setFieldErrors] = useState({});

  useEffect(() => {
    const savedEmail = localStorage.getItem('rememberedEmail');
    if (savedEmail) {
      setForm(f => ({ ...f, email: savedEmail, rememberMe: true }));
    }
  }, []);

  const validate = () => {
    const errors = {};
    if (!form.email) errors.email = 'Email is required';
    else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) errors.email = 'Invalid email address';
    
    if (!form.password) errors.password = 'Password required';

    setFieldErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const mapError = (errMessage) => {
    const msg = errMessage.toLowerCase();
    if (msg.includes('invalid credentials') || msg.includes('wrong email') || msg.includes('wrong password') || msg.includes('wrong username')) return 'Wrong email or password';
    if (msg.includes('not verified')) return 'Email not verified';
    if (msg.includes('rate limit') || msg.includes('too many') || msg.includes('locked')) return 'Account temporarily locked';
    if (msg.includes('network') || msg.includes('server')) return 'Server unavailable';
    return errMessage || 'Login failed';
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    
    if (!validate()) return;
    
    setLoading(true);
    try {
      const res = await login(form.email, form.password);
      if (res?.success) {
        if (form.rememberMe) {
          localStorage.setItem('rememberedEmail', form.email);
        } else {
          localStorage.removeItem('rememberedEmail');
        }
        navigate('/dashboard');
      } else {
        setError(mapError(res?.error || 'Invalid credentials'));
      }
    } catch (err) {
      setError(mapError(err.message || 'Login failed'));
    } finally {
      setLoading(false);
    }
  };

  const inputClass = `w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-sm text-white
    placeholder-gray-500 focus:outline-none focus:border-cyan/50 focus:bg-white/8 transition-all disabled:opacity-50 disabled:cursor-not-allowed`;

  return (
    <div className="min-h-screen bg-void flex items-center justify-center p-4 relative overflow-hidden">
      {/* Glow orbs */}
      <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-cyan/10 rounded-full blur-3xl pointer-events-none animate-float" />
      <div className="absolute bottom-1/4 right-1/4 w-80 h-80 bg-plasma/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute inset-0 bg-grid-pattern opacity-30" />

      <div className="relative w-full max-w-md animate-fadeInUp">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="w-14 h-14 rounded-2xl bg-cyan flex items-center justify-center mx-auto mb-4 shadow-xl shadow-glow-cyan animate-float">
            <Zap className="w-7 h-7 text-black" />
          </div>
          <h1 className="text-3xl font-hero font-black text-white">Welcome back</h1>
          <p className="text-gray-400 mt-2 text-sm">Sign in to your productivity command center</p>
        </div>

        {/* Card */}
        <div className="glass card-3d p-8 space-y-5">
          {error && (
            <div className="p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-sm text-center">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Email */}
            <div className="space-y-1.5">
              <label className="text-xs font-semibold text-gray-400">Email</label>
              <div className="relative">
                <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none" />
                <input
                  type="email"
                  disabled={loading}
                  className={`${inputClass} pl-10 ${fieldErrors.email ? 'border-rose-500/50 focus:border-rose-500' : ''}`}
                  placeholder="you@example.com"
                  value={form.email}
                  onChange={e => {
                    setForm(f => ({ ...f, email: e.target.value }));
                    if (fieldErrors.email) setFieldErrors(fe => ({ ...fe, email: null }));
                  }}
                />
              </div>
              {fieldErrors.email && <p className="text-rose-400 text-xs mt-1">{fieldErrors.email}</p>}
            </div>

            {/* Password */}
            <div className="space-y-1.5">
              <div className="flex items-center justify-between">
                <label className="text-xs font-semibold text-gray-400">Password</label>
                <Link to="/forgot-password" className="text-xs text-cyan hover:opacity-80 transition-colors">
                  Forgot password?
                </Link>
              </div>
              <div className="relative">
                <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-500 pointer-events-none" />
                <input
                  type={showPw ? 'text' : 'password'}
                  disabled={loading}
                  className={`${inputClass} pl-10 pr-10 ${fieldErrors.password ? 'border-rose-500/50 focus:border-rose-500' : ''}`}
                  placeholder="Your password"
                  value={form.password}
                  onChange={e => {
                    setForm(f => ({ ...f, password: e.target.value }));
                    if (fieldErrors.password) setFieldErrors(fe => ({ ...fe, password: null }));
                  }}
                />
                <button type="button" onClick={() => setShowPw(!showPw)}
                  disabled={loading}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-300 transition-colors disabled:opacity-50">
                  {showPw ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
              {fieldErrors.password && <p className="text-rose-400 text-xs mt-1">{fieldErrors.password}</p>}
            </div>

            {/* Remember Me */}
            <div className="flex items-center gap-2 pt-1">
              <input
                type="checkbox"
                id="rememberMe"
                disabled={loading}
                checked={form.rememberMe}
                onChange={e => setForm(f => ({ ...f, rememberMe: e.target.checked }))}
                className="w-4 h-4 rounded border-gray-600 bg-white/5 text-cyan focus:ring-cyan focus:ring-offset-gray-900"
              />
              <label htmlFor="rememberMe" className="text-xs text-gray-400 cursor-pointer">
                Remember Me
              </label>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 rounded-xl bg-cyan text-black font-bold text-sm
                hover:opacity-90 transition-all shadow-glow-cyan disabled:opacity-60 disabled:cursor-not-allowed flex items-center justify-center gap-2 mt-2"
            >
              {loading ? (
                <div className="w-4 h-4 rounded-full border-2 border-black/30 border-t-black animate-spin" />
              ) : (
                <>Sign In <ArrowRight className="w-4 h-4" /></>
              )}
            </button>
          </form>

          <p className="text-center text-sm text-gray-500">
            Don't have an account?{' '}
            <Link to="/signup" className="text-cyan font-semibold hover:opacity-80 transition-colors">
              Create one →
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}
