import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Mail } from 'lucide-react';
import { checkEmail } from '../services/api';
import {
  AuthLayout,
  AuthCard,
  AuthHeader,
  AuthInput,
  AuthPrimaryButton,
  AuthSecondaryLink,
  AuthAlert,
} from '../components/auth';

export default function Signup() {
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [fieldError, setFieldError] = useState('');

  const validate = () => {
    if (!email.trim()) {
      setFieldError('Email is required');
      return false;
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())) {
      setFieldError('Please enter a valid email address');
      return false;
    }
    setFieldError('');
    return true;
  };

  const handleSignupSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (!validate()) return;

    const trimmedEmail = email.trim().toLowerCase();
    setLoading(true);
    try {
      // Check if email is already registered
      const emailCheck = await checkEmail(trimmedEmail);
      if (!emailCheck.data?.available) {
        setFieldError('This email is already registered.');
        setLoading(false);
        return;
      }

      // Email is available — store temporarily and proceed directly to password creation (OTP-free)
      sessionStorage.setItem('pendingSignupEmail', trimmedEmail);
      navigate('/create-password', { state: { email: trimmedEmail } });
    } catch (err) {
      setError(err.message || 'Failed to verify email availability. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthLayout>
      <div className="w-full flex flex-col items-center">
        <AuthHeader
          title="Create your account"
          subtitle="Start building better habits today."
          step={1}
          totalSteps={2}
          stepLabel="Enter email"
        />

        <AuthCard>
          {error && <AuthAlert type="error" message={error} />}

          <form onSubmit={handleSignupSubmit} className="space-y-4" noValidate>
            <div className="space-y-1.5">
              <AuthInput
                id="signup-email"
                label="Email Address"
                type="email"
                icon={Mail}
                placeholder="you@example.com"
                value={email}
                disabled={loading}
                autoComplete="email"
                autoFocus
                error={fieldError}
                onChange={(e) => {
                  setEmail(e.target.value);
                  if (fieldError) setFieldError('');
                }}
              />

              {fieldError && fieldError.toLowerCase().includes('already') && (
                <div className="pt-1 text-right">
                  <AuthSecondaryLink to="/login" className="text-xs">
                    Sign in to your existing account →
                  </AuthSecondaryLink>
                </div>
              )}
            </div>

            <div className="pt-2">
              <AuthPrimaryButton loading={loading} loadingText="Checking email...">
                Continue
              </AuthPrimaryButton>
            </div>
          </form>

          {/* Footer: Already have an account */}
          <div className="pt-3 border-t border-[#E4ECEF] text-center">
            <p className="text-xs sm:text-sm text-[#526179]">
              Already have an account?{' '}
              <AuthSecondaryLink to="/login">
                Sign in
              </AuthSecondaryLink>
            </p>
          </div>
        </AuthCard>
      </div>
    </AuthLayout>
  );
}
