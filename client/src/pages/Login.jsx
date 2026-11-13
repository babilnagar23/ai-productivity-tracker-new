import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Mail } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import {
  AuthLayout,
  AuthCard,
  AuthHeader,
  AuthInput,
  AuthPasswordInput,
  AuthPrimaryButton,
  AuthSecondaryLink,
  AuthAlert,
} from '../components/auth';

export default function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [form, setForm] = useState({ email: '', password: '', rememberMe: false });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [fieldErrors, setFieldErrors] = useState({});

  useEffect(() => {
    const savedEmail = localStorage.getItem('rememberedEmail');
    if (savedEmail) {
      setForm((f) => ({ ...f, email: savedEmail, rememberMe: true }));
    }
  }, []);

  const validate = () => {
    const errors = {};
    if (!form.email) {
      errors.email = 'Email is required';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.email)) {
      errors.email = 'Please enter a valid email address';
    }

    if (!form.password) {
      errors.password = 'Password is required';
    }

    setFieldErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const mapError = (errMessage) => {
    if (!errMessage) return 'Login failed. Please try again.';
    const msg = String(errMessage).toLowerCase();
    if (
      msg.includes('invalid credentials') ||
      msg.includes('wrong email') ||
      msg.includes('wrong password') ||
      msg.includes('wrong username') ||
      msg.includes('no active account')
    ) {
      return 'Wrong email or password. Please check your credentials.';
    }
    if (msg.includes('not verified')) {
      return 'Email not verified. Please verify your email first.';
    }
    if (msg.includes('rate limit') || msg.includes('too many') || msg.includes('locked')) {
      return 'Account temporarily locked. Please try again later.';
    }
    if (msg.includes('network') || msg.includes('server') || msg.includes('unavailable')) {
      return 'Server is currently unavailable. Please try again in a moment.';
    }
    return errMessage;
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

  return (
    <AuthLayout>
      <div className="w-full flex flex-col items-center">
        <AuthHeader
          title="Welcome back"
          subtitle="Sign in to your productivity command center"
        />

        <AuthCard>
          {error && <AuthAlert type="error" message={error} />}

          <form onSubmit={handleSubmit} className="space-y-4" noValidate>
            {/* Email Input */}
            <AuthInput
              id="login-email"
              label="Email Address"
              type="email"
              icon={Mail}
              placeholder="you@example.com"
              value={form.email}
              autoComplete="email"
              disabled={loading}
              error={fieldErrors.email}
              onChange={(e) => {
                setForm((f) => ({ ...f, email: e.target.value }));
                if (fieldErrors.email) setFieldErrors((fe) => ({ ...fe, email: null }));
              }}
            />

            {/* Password Input with Forgot Password Link */}
            <div className="space-y-1.5">
              <div className="flex items-center justify-between">
                <label
                  htmlFor="login-password"
                  className="block text-xs sm:text-sm font-semibold text-[#111C34]"
                >
                  Password
                </label>
                <AuthSecondaryLink to="/forgot-password" className="text-xs">
                  Forgot password?
                </AuthSecondaryLink>
              </div>

              <AuthPasswordInput
                id="login-password"
                placeholder="Enter your password"
                value={form.password}
                disabled={loading}
                error={fieldErrors.password}
                autoComplete="current-password"
                onChange={(e) => {
                  setForm((f) => ({ ...f, password: e.target.value }));
                  if (fieldErrors.password) setFieldErrors((fe) => ({ ...fe, password: null }));
                }}
              />
            </div>

            {/* Remember Me Checkbox */}
            <div className="flex items-center justify-between pt-1">
              <label className="flex items-center gap-2.5 cursor-pointer select-none">
                <input
                  type="checkbox"
                  id="rememberMe"
                  disabled={loading}
                  checked={form.rememberMe}
                  onChange={(e) => setForm((f) => ({ ...f, rememberMe: e.target.checked }))}
                  className="w-4 h-4 rounded border-[#E4ECEF] text-[#00BFAE] accent-[#00BFAE] focus:ring-[#00BFAE]/30 cursor-pointer"
                />
                <span className="text-xs sm:text-sm text-[#526179]">Remember Me</span>
              </label>
            </div>

            {/* Primary Action Button */}
            <div className="pt-2">
              <AuthPrimaryButton loading={loading} loadingText="Signing in...">
                Sign In
              </AuthPrimaryButton>
            </div>
          </form>

          {/* Footer: Create Account Link */}
          <div className="pt-3 border-t border-[#E4ECEF] text-center">
            <p className="text-xs sm:text-sm text-[#526179]">
              Don&apos;t have an account?{' '}
              <AuthSecondaryLink to="/signup">
                Create one →
              </AuthSecondaryLink>
            </p>
          </div>
        </AuthCard>
      </div>
    </AuthLayout>
  );
}
