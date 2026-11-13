import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Mail, ArrowLeft } from 'lucide-react';
import { forgotPassword } from '../services/api';
import {
  AuthLayout,
  AuthCard,
  AuthHeader,
  AuthInput,
  AuthPrimaryButton,
  AuthSecondaryLink,
  AuthAlert,
  AuthSuccessState,
} from '../components/auth';

export default function ForgotPassword() {
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [fieldError, setFieldError] = useState('');
  const [isSubmitted, setIsSubmitted] = useState(false);

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

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (!validate()) return;

    setLoading(true);
    try {
      await forgotPassword(email.trim().toLowerCase());
      setIsSubmitted(true);
    } catch (err) {
      setError(err.message || 'Failed to send reset link. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthLayout>
      <div className="w-full flex flex-col items-center">
        {!isSubmitted && (
          <AuthHeader
            title="Forgot your password?"
            subtitle="Don't worry. Enter your email and we'll help you reset your password."
          />
        )}

        <AuthCard>
          {isSubmitted ? (
            /* Success Feedback State */
            <AuthSuccessState
              title="Check your inbox"
              message={`If an account exists with ${email}, you will receive a password reset link shortly. Please check your inbox and spam folder.`}
              primaryActionLabel="Return to Sign In"
              onPrimaryAction={() => navigate('/login')}
            />
          ) : (
            <>
              {error && <AuthAlert type="error" message={error} />}

              <form onSubmit={handleSubmit} className="space-y-4" noValidate>
                <AuthInput
                  id="forgot-email"
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

                <div className="pt-2">
                  <AuthPrimaryButton loading={loading} loadingText="Sending link...">
                    Send Reset Link
                  </AuthPrimaryButton>
                </div>
              </form>

              {/* Footer: Back to Sign In */}
              <div className="pt-3 border-t border-[#E4ECEF] text-center">
                <p className="text-xs sm:text-sm text-[#526179]">
                  Remember your password?{' '}
                  <AuthSecondaryLink to="/login" className="inline-flex items-center gap-1">
                    <ArrowLeft className="w-3 h-3" />
                    Sign in
                  </AuthSecondaryLink>
                </p>
              </div>
            </>
          )}
        </AuthCard>
      </div>
    </AuthLayout>
  );
}
