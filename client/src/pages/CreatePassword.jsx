import { useState, useEffect } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { ShieldAlert, Clock } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import {
  AuthLayout,
  AuthCard,
  AuthHeader,
  AuthPasswordInput,
  AuthPrimaryButton,
  AuthAlert,
  PasswordStrengthMeter,
  AuthSuccessState,
} from '../components/auth';

export default function CreatePassword() {
  const { register } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const email =
    location.state?.email ||
    sessionStorage.getItem('pendingSignupEmail') ||
    sessionStorage.getItem('otpVerified');

  const [form, setForm] = useState({ password: '', confirm: '' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [cooldownSeconds, setCooldownSeconds] = useState(0);
  const [isSuccess, setIsSuccess] = useState(false);

  // Active countdown timer for IP cooldown
  useEffect(() => {
    if (cooldownSeconds <= 0) return;
    const timer = setInterval(() => {
      setCooldownSeconds((prev) => {
        if (prev <= 1) {
          clearInterval(timer);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => clearInterval(timer);
  }, [cooldownSeconds]);

  // Validation rules
  const rules = {
    length: form.password.length >= 8,
    upper: /[A-Z]/.test(form.password),
    lower: /[a-z]/.test(form.password),
    number: /[0-9]/.test(form.password),
    special: /[!@#$%^&*(),.?":{}|<>]/.test(form.password),
  };
  const validCount = Object.values(rules).filter(Boolean).length;
  const isAllValid = validCount === 5;
  const isMatch = form.password && form.confirm && form.password === form.confirm;

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (cooldownSeconds > 0) {
      return;
    }

    if (!isAllValid) {
      setError('Please satisfy all password strength requirements.');
      return;
    }

    if (form.password !== form.confirm) {
      setError('Passwords do not match. Please verify both fields.');
      return;
    }

    setLoading(true);
    try {
      const res = await register(email, form.password, form.confirm);
      if (res?.success) {
        sessionStorage.removeItem('pendingSignupEmail');
        sessionStorage.removeItem('otpVerified');
        setIsSuccess(true);
        setTimeout(() => {
          navigate('/dashboard');
        }, 2200);
      } else {
        if (res?.code === 'SIGNUP_IP_COOLDOWN' || res?.retry_after_seconds) {
          const seconds = Number(res.retry_after_seconds) || 60;
          setCooldownSeconds(seconds);
          setError(
            res.error ||
              `Only one account may be created every 60 seconds from this network. Please wait ${seconds}s.`
          );
        } else {
          setError(res?.error || 'Registration failed. Please try again.');
        }
      }
    } catch (err) {
      if (err?.code === 'SIGNUP_IP_COOLDOWN' || err?.retry_after_seconds) {
        const seconds = Number(err.retry_after_seconds) || 60;
        setCooldownSeconds(seconds);
        setError(
          err.message ||
            `Only one account may be created every 60 seconds from this network. Please wait ${seconds}s.`
        );
      } else {
        setError(err.message || 'Registration failed. Please try again.');
      }
    } finally {
      setLoading(false);
    }
  };

  // If no email session exists, show a clean expired session card
  if (!email) {
    return (
      <AuthLayout>
        <div className="w-full flex flex-col items-center">
          <AuthCard>
            <div className="text-center space-y-4 py-4">
              <div className="w-14 h-14 rounded-2xl bg-[#FFF5F6] border border-[#E45D70]/20 flex items-center justify-center mx-auto text-[#E45D70]">
                <ShieldAlert className="w-7 h-7" />
              </div>
              <h2 className="text-xl sm:text-2xl font-hero font-extrabold text-[#111C34]">
                Session Expired
              </h2>
              <p className="text-sm text-[#526179] max-w-sm mx-auto">
                No active signup session was found. Please start by entering your email address.
              </p>
              <div className="pt-2">
                <AuthPrimaryButton onClick={() => navigate('/signup')}>
                  Return to Sign Up
                </AuthPrimaryButton>
              </div>
            </div>
          </AuthCard>
        </div>
      </AuthLayout>
    );
  }

  return (
    <AuthLayout>
      <div className="w-full flex flex-col items-center">
        {!isSuccess && (
          <AuthHeader
            title="Create your password"
            subtitle={`Setting up account for ${email}`}
            step={2}
            totalSteps={2}
            stepLabel="Set password"
          />
        )}

        <AuthCard>
          {isSuccess ? (
            <AuthSuccessState
              title="Account Created!"
              message="Welcome to Productivity Tracker. Your account is ready and you are now being redirected to your dashboard."
              primaryActionLabel="Go to Dashboard"
              onPrimaryAction={() => navigate('/dashboard')}
              redirectHint="Redirecting automatically in a moment..."
            />
          ) : (
            <>
              {cooldownSeconds > 0 ? (
                <div className="mb-4 p-3.5 rounded-xl bg-[#FFF8EB] border border-[#F3A64A]/30 text-[#8F5500] text-sm flex items-start gap-2.5">
                  <Clock className="w-5 h-5 flex-shrink-0 text-[#F3A64A] mt-0.5" />
                  <div className="flex-1">
                    <p className="font-semibold text-[#8F5500]">Network Signup Cooldown Active</p>
                    <p className="mt-0.5 text-xs text-[#8F5500]/90">
                      To prevent abuse, only one account may be created per 60 seconds from this network. You can submit again in{' '}
                      <span className="font-mono font-bold text-[#8F5500] text-sm underline decoration-[#F3A64A]">
                        {cooldownSeconds}s
                      </span>
                      .
                    </p>
                  </div>
                </div>
              ) : error ? (
                <AuthAlert type="error" message={error} />
              ) : null}

              <form onSubmit={handleSubmit} className="space-y-4" noValidate>
                {/* New Password */}
                <AuthPasswordInput
                  id="create-password"
                  label="New Password"
                  placeholder="Create a strong password"
                  value={form.password}
                  disabled={loading}
                  autoComplete="new-password"
                  autoFocus
                  onChange={(e) => {
                    setForm((f) => ({ ...f, password: e.target.value }));
                    if (error && cooldownSeconds === 0) setError('');
                  }}
                />

                {/* Password Strength Meter & Requirement Checklist */}
                <PasswordStrengthMeter password={form.password} />

                {/* Confirm Password */}
                <AuthPasswordInput
                  id="create-password-confirm"
                  label="Confirm Password"
                  placeholder="Re-enter your password"
                  value={form.confirm}
                  disabled={loading}
                  autoComplete="new-password"
                  error={
                    form.confirm && form.password !== form.confirm
                      ? 'Passwords do not match'
                      : undefined
                  }
                  onChange={(e) => {
                    setForm((f) => ({ ...f, confirm: e.target.value }));
                    if (error && cooldownSeconds === 0) setError('');
                  }}
                />

                {/* Primary Button */}
                <div className="pt-2">
                  <AuthPrimaryButton
                    type="submit"
                    loading={loading}
                    loadingText="Finishing setup..."
                    disabled={!isAllValid || !isMatch || cooldownSeconds > 0}
                  >
                    {cooldownSeconds > 0
                      ? `Please wait (${cooldownSeconds}s)`
                      : 'Create Account'}
                  </AuthPrimaryButton>
                </div>
              </form>
            </>
          )}
        </AuthCard>
      </div>
    </AuthLayout>
  );
}
