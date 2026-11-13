import { useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { ShieldAlert } from 'lucide-react';
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
  const { completeOTPRegistration } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const email = location.state?.email || sessionStorage.getItem('otpVerified');

  const [form, setForm] = useState({ password: '', confirm: '' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [isSuccess, setIsSuccess] = useState(false);

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
      const res = await completeOTPRegistration(email, form.password, form.confirm);
      if (res?.success) {
        sessionStorage.removeItem('otpVerified');
        setIsSuccess(true);
        setTimeout(() => {
          navigate('/dashboard');
        }, 2200);
      } else {
        setError(res?.error || 'Registration failed. Please try again.');
      }
    } catch (err) {
      setError(err.message || 'Registration failed. Please try again.');
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
                Verification Expired
              </h2>
              <p className="text-sm text-[#526179] max-w-sm mx-auto">
                No verified session was found. Please start by verifying your email address.
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
            subtitle="Secure your new account with a strong password"
            step={3}
            totalSteps={3}
            stepLabel="Set password"
          />
        )}

        <AuthCard>
          {isSuccess ? (
            /* Screen 8: Account Creation Success */
            <AuthSuccessState
              title="Account Created!"
              message="Welcome to Productivity Tracker. Your account is ready and you are now being redirected to your dashboard."
              primaryActionLabel="Go to Dashboard"
              onPrimaryAction={() => navigate('/dashboard')}
              redirectHint="Redirecting automatically in a moment..."
            />
          ) : (
            <>
              {error && <AuthAlert type="error" message={error} />}

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
                    if (error) setError('');
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
                    if (error) setError('');
                  }}
                />

                {/* Primary Button */}
                <div className="pt-2">
                  <AuthPrimaryButton
                    type="submit"
                    loading={loading}
                    loadingText="Finishing setup..."
                    disabled={!isAllValid || !isMatch}
                  >
                    Create Account
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
