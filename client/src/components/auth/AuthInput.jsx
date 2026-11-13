import { forwardRef } from 'react';

const AuthInput = forwardRef(function AuthInput(
  {
    id,
    label,
    type = 'text',
    value,
    onChange,
    placeholder,
    icon: Icon,
    rightElement,
    error,
    disabled = false,
    required = false,
    className = '',
    autoComplete,
    autoFocus = false,
    ...rest
  },
  ref
) {
  const inputId = id || (label ? label.toLowerCase().replace(/\s+/g, '-') : undefined);

  return (
    <div className={`space-y-1.5 w-full ${className}`}>
      {label && (
        <label
          htmlFor={inputId}
          className="block text-xs sm:text-sm font-semibold text-[#111C34]"
        >
          {label} {required && <span className="text-[#E45D70]">*</span>}
        </label>
      )}

      <div className="relative flex items-center">
        {Icon && (
          <div className="absolute left-3.5 pointer-events-none text-[#8290A5] flex items-center justify-center">
            <Icon className="w-4 h-4 sm:w-[18px] sm:h-[18px]" />
          </div>
        )}

        <input
          ref={ref}
          id={inputId}
          type={type}
          value={value}
          onChange={onChange}
          disabled={disabled}
          placeholder={placeholder}
          required={required}
          autoComplete={autoComplete}
          autoFocus={autoFocus}
          className={`auth-input w-full h-[52px] bg-[#F7FAFC] border text-sm sm:text-base text-[#101A32] placeholder-[#8290A5] rounded-[14px] transition-all duration-200 outline-none
            ${Icon ? 'pl-10 sm:pl-11' : 'pl-4'}
            ${rightElement ? 'pr-11 sm:pr-12' : 'pr-4'}
            ${
              error
                ? 'border-[#E45D70] bg-[#FFF9FA] focus:border-[#E45D70] focus:ring-3 focus:ring-[#E45D70]/15'
                : 'border-[#E4ECEF] hover:border-[#CBD5E1] focus:bg-white focus:border-[#00BFAE] focus:ring-3 focus:ring-[#00BFAE]/15'
            }
            ${disabled ? 'opacity-60 cursor-not-allowed bg-[#F1F5F9]' : ''}
          `}
          {...rest}
        />

        {rightElement && (
          <div className="absolute right-3 flex items-center justify-center">
            {rightElement}
          </div>
        )}
      </div>

      {error && (
        <p className="text-xs text-[#E45D70] font-medium mt-1 animate-fadeIn flex items-center gap-1">
          <span>{error}</span>
        </p>
      )}
    </div>
  );
});

export default AuthInput;
