import { useState, forwardRef } from 'react';
import { Lock, Eye, EyeOff } from 'lucide-react';
import AuthInput from './AuthInput';

const AuthPasswordInput = forwardRef(function AuthPasswordInput(
  {
    id,
    label = 'Password',
    value,
    onChange,
    placeholder = 'Enter your password',
    error,
    disabled = false,
    required = false,
    autoComplete = 'current-password',
    className = '',
    ...rest
  },
  ref
) {
  const [showPassword, setShowPassword] = useState(false);

  const toggleButton = (
    <button
      type="button"
      onClick={() => setShowPassword((prev) => !prev)}
      disabled={disabled}
      aria-label={showPassword ? 'Hide password' : 'Show password'}
      className="p-1.5 text-[#8290A5] hover:text-[#101A32] focus:outline-none focus:text-[#00BFAE] transition-colors rounded-lg disabled:opacity-50"
    >
      {showPassword ? (
        <EyeOff className="w-4 h-4 sm:w-[18px] sm:h-[18px]" />
      ) : (
        <Eye className="w-4 h-4 sm:w-[18px] sm:h-[18px]" />
      )}
    </button>
  );

  return (
    <AuthInput
      ref={ref}
      id={id}
      label={label}
      type={showPassword ? 'text' : 'password'}
      value={value}
      onChange={onChange}
      placeholder={placeholder}
      icon={Lock}
      rightElement={toggleButton}
      error={error}
      disabled={disabled}
      required={required}
      autoComplete={autoComplete}
      className={className}
      {...rest}
    />
  );
});

export default AuthPasswordInput;
