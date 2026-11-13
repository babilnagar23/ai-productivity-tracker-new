import { CheckCircle2 } from 'lucide-react';
import AuthPrimaryButton from './AuthPrimaryButton';

export default function AuthSuccessState({
  title = 'Success!',
  message,
  primaryActionLabel = 'Continue',
  onPrimaryAction,
  redirectHint,
  className = '',
}) {
  return (
    <div className={`text-center space-y-6 py-4 animate-fadeIn ${className}`}>
      {/* Success Badge */}
      <div className="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-[#E5F7F2] border-2 border-[#0DAD83]/20 flex items-center justify-center mx-auto shadow-sm">
        <CheckCircle2 className="w-9 h-9 sm:w-11 sm:h-11 text-[#0DAD83] stroke-[2.2]" />
      </div>

      {/* Headings */}
      <div className="space-y-2">
        <h2 className="text-2xl sm:text-3xl font-hero font-extrabold text-[#111C34] tracking-tight">
          {title}
        </h2>
        {message && (
          <p className="text-sm sm:text-base text-[#526179] max-w-sm mx-auto leading-relaxed">
            {message}
          </p>
        )}
      </div>

      {/* Action Button */}
      {primaryActionLabel && onPrimaryAction && (
        <div className="pt-2">
          <AuthPrimaryButton onClick={onPrimaryAction}>
            {primaryActionLabel}
          </AuthPrimaryButton>
        </div>
      )}

      {/* Redirect hint */}
      {redirectHint && (
        <p className="text-xs text-[#8290A5] pt-1">
          {redirectHint}
        </p>
      )}
    </div>
  );
}
