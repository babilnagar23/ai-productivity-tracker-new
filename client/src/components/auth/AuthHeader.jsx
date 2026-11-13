import AuthLogo from './AuthLogo';

export default function AuthHeader({
  title,
  subtitle,
  step,
  totalSteps,
  stepLabel,
  className = '',
}) {
  return (
    <div className={`text-center mb-6 sm:mb-8 ${className}`}>
      {/* Brand Logo Presentation */}
      <div className="mb-4">
        <AuthLogo />
      </div>

      {/* Step Indicator (for multi-step flows like signup) */}
      {step && totalSteps && (
        <div className="inline-flex items-center gap-2 px-3 py-1 mb-3 rounded-full bg-[#E5F7F2] border border-[#00BFAE]/20 text-xs font-semibold text-[#00BFAE]">
          <span>Step {step} of {totalSteps}</span>
          {stepLabel && <span className="text-[#526179]">· {stepLabel}</span>}
        </div>
      )}

      {/* Heading */}
      <h1 className="text-2xl sm:text-3xl md:text-[34px] font-hero font-extrabold text-[#111C34] tracking-tight leading-tight">
        {title}
      </h1>

      {/* Subtitle */}
      {subtitle && (
        <p className="mt-2 text-sm sm:text-base text-[#526179] max-w-sm mx-auto leading-relaxed">
          {subtitle}
        </p>
      )}
    </div>
  );
}
