import { ArrowRight } from 'lucide-react';

export default function AuthPrimaryButton({
  children,
  type = 'submit',
  loading = false,
  loadingText,
  disabled = false,
  icon: Icon = ArrowRight,
  showIcon = true,
  onClick,
  className = '',
}) {
  const isDisabled = disabled || loading;

  return (
    <button
      type={type}
      disabled={isDisabled}
      onClick={onClick}
      className={`auth-primary-button w-full h-[52px] min-h-[52px] rounded-[14px] font-bold text-sm sm:text-base text-white flex items-center justify-center gap-2 px-6 transition-all duration-200 select-none
        ${
          isDisabled
            ? 'opacity-60 cursor-not-allowed shadow-none'
            : 'hover:shadow-lg hover:shadow-[#00BFAE]/25 active:scale-[0.99]'
        }
        ${className}
      `}
    >
      {loading ? (
        <div className="flex items-center gap-2.5">
          <svg
            className="animate-spin h-5 w-5 text-white"
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
          >
            <circle
              className="opacity-25"
              cx="12"
              cy="12"
              r="10"
              stroke="currentColor"
              strokeWidth="3"
            />
            <path
              className="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
            />
          </svg>
          <span>{loadingText || 'Please wait...'}</span>
        </div>
      ) : (
        <>
          <span>{children}</span>
          {showIcon && Icon && <Icon className="w-4 h-4 sm:w-[18px] sm:h-[18px]" />}
        </>
      )}
    </button>
  );
}
