import { useState, useEffect, useCallback } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { MailCheck, RefreshCw, ArrowLeft } from 'lucide-react';
import { verifyOTP, sendOTP } from '../services/api';
import {
  AuthLayout,
  AuthCard,
  AuthHeader,
  AuthPrimaryButton,
  AuthSecondaryLink,
  AuthAlert,
  OtpInput,
} from '../components/auth';

const RESEND_COOLDOWN_SECONDS = 60;

export default function VerifyOTP() {
  const navigate = useNavigate();
  const location = useLocation();
  const email = location.state?.email || '';

  const [otp, setOtp] = useState(['', '', '', '', '', '']);
  const [loading, setLoading] = useState(false);
  const [resending, setResending] = useState(false);
  const [error, setError] = useState('');
  const [resendSuccess, setResendSuccess] = useState('');
  const [countdown, setCountdown] = useState(RESEND_COOLDOWN_SECONDS);

  // Countdown timer for resend cooldown
  useEffect(() => {
    if (countdown <= 0) return;
    const timer = setInterval(() => {
      setCountdown((prev) => (prev > 0 ? prev - 1 : 0));
    }, 1000);
    return () => clearInterval(timer);
  }, [countdown]);

  const submitOTP = useCallback(
    async (code) => {
      if (code.length < 6) {
        setError('Please enter all 6 digits of your verification code.');
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
        if (msg.includes('expired')) {
          setError('Your code has expired. Please request a new one.');
        } else if (msg.includes('Invalid OTP') || msg.includes('invalid')) {
          setError(msg || 'Invalid verification code. Please check and try again.');
        } else if (msg.includes('Too many') || msg.includes('attempts')) {
          setError('Too many failed attempts. Please request a new code.');
        } else {
          setError(msg || 'Verification failed. Please check the code and try again.');
        }
      } finally {
        setLoading(false);
      }
    },
    [email, navigate]
  );

  const handleSubmit = (e) => {
    e.preventDefault();
    submitOTP(otp.join(''));
  };

  const handleResend = async () => {
    if (countdown > 0 || resending || loading) return;

    setResending(true);
    setError('');
    setResendSuccess('');

    try {
      await sendOTP(email);
      setResendSuccess(`A new verification code has been sent to ${email}`);
      setCountdown(RESEND_COOLDOWN_SECONDS);
      setOtp(['', '', '', '', '', '']);
    } catch (err) {
      setError(err.message || 'Failed to resend code. Please try again.');
    } finally {
      setResending(false);
    }
  };

  // If no email in session, render a clean error/expired session card
  if (!email) {
    return (
      <AuthLayout>
        <div className="w-full flex flex-col items-center">
          <AuthCard>
            <div className="text-center space-y-4 py-4">
              <div className="w-14 h-14 rounded-2xl bg-[#FFF5F6] border border-[#E45D70]/20 flex items-center justify-center mx-auto text-[#E45D70]">
                <MailCheck className="w-7 h-7" />
              </div>
              <h2 className="text-xl sm:text-2xl font-hero font-extrabold text-[#111C34]">
                Session Expired
              </h2>
              <p className="text-sm text-[#526179] max-w-sm mx-auto">
                No email address found for this verification session. Please enter your email to get started.
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

  const isComplete = otp.join('').length === 6;

  return (
    <AuthLayout>
      <div className="w-full flex flex-col items-center">
        <AuthHeader
          title="Verify your email"
          subtitle={
            <span>
              We sent a 6-digit verification code to{' '}
              <strong className="text-[#111C34] font-semibold break-all">{email}</strong>
            </span>
          }
          step={2}
          totalSteps={3}
          stepLabel="Verify email"
        />

        <AuthCard>
          {error && <AuthAlert type="error" message={error} />}
          {resendSuccess && <AuthAlert type="success" message={resendSuccess} />}

          <form onSubmit={handleSubmit} className="space-y-6">
            {/* 6 OTP Boxes */}
            <div className="space-y-2">
              <OtpInput
                value={otp}
                onChange={setOtp}
                onComplete={submitOTP}
                error={Boolean(error)}
                disabled={loading}
              />
              <p className="text-xs text-center text-[#8290A5]">
                Enter the 6-digit code from your email
              </p>
            </div>

            {/* Verify CTA */}
            <AuthPrimaryButton
              type="submit"
              loading={loading}
              loadingText="Verifying code..."
              disabled={!isComplete}
            >
              Verify Account
            </AuthPrimaryButton>
          </form>

          {/* Resend / Actions */}
          <div className="pt-3 border-t border-[#E4ECEF] space-y-3 text-center">
            <div className="text-xs sm:text-sm text-[#526179]">
              Didn&apos;t receive the code?{' '}
              {countdown > 0 ? (
                <span className="font-semibold text-[#8290A5]">
                  Resend in {Math.floor(countdown / 60)}:
                  {String(countdown % 60).padStart(2, '0')}
                </span>
              ) : (
                <button
                  type="button"
                  onClick={handleResend}
                  disabled={resending || loading}
                  className="font-semibold text-[#00BFAE] hover:text-[#12B8B0] transition-colors inline-flex items-center gap-1 focus:outline-none focus-visible:underline disabled:opacity-50"
                >
                  {resending ? (
                    <>
                      <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                      Sending...
                    </>
                  ) : (
                    'Resend code'
                  )}
                </button>
              )}
            </div>

            <div>
              <AuthSecondaryLink
                to="/signup"
                className="text-xs text-[#8290A5] hover:text-[#526179] inline-flex items-center gap-1"
              >
                <ArrowLeft className="w-3 h-3" />
                Change email address
              </AuthSecondaryLink>
            </div>
          </div>
        </AuthCard>
      </div>
    </AuthLayout>
  );
}
