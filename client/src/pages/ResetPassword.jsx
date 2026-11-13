import { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { resetPassword } from '../services/api';
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

export default function ResetPassword() {
  const { uid, token } = useParams();
  const navigate = useNavigate();

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
      await resetPassword(uid, token, form.password);
      setIsSuccess(true);
      setTimeout(() => {
        navigate('/login');
      }, 2500);
    } catch (err) {
      setError(
        err.message || 'Failed to reset password. This link may be invalid or expired.'
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthLayout>
      <div className="w-full flex flex-col items-center">
        {!isSuccess && (
          <AuthHeader
            title="Reset your password"
            subtitle="Create a new secure password for your account"
          />
        )}

        <AuthCard>
          {isSuccess ? (
            /* Screen 7: Password Reset Success */
            <AuthSuccessState
              title="Password Reset!"
              message="Your password has been reset successfully. You can now sign in with your new credentials."
              primaryActionLabel="Sign In to Your Account"
              onPrimaryAction={() => navigate('/login')}
              redirectHint="Redirecting to sign in automatically..."
            />
          ) : (
            <>
              {error && <AuthAlert type="error" message={error} />}

              <form onSubmit={handleSubmit} className="space-y-4" noValidate>
                {/* New Password */}
                <AuthPasswordInput
                  id="reset-password"
                  label="New Password"
                  placeholder="Enter new password"
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

                {/* Confirm New Password */}
                <AuthPasswordInput
                  id="reset-password-confirm"
                  label="Confirm New Password"
                  placeholder="Re-enter new password"
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
                    loadingText="Resetting password..."
                    disabled={!isAllValid || !isMatch}
                  >
                    Reset Password
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
