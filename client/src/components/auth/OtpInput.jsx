import { useRef, useEffect } from 'react';

export default function OtpInput({
  value = ['', '', '', '', '', ''],
  onChange,
  onComplete,
  error = false,
  disabled = false,
  autoFocus = true,
  className = '',
}) {
  const inputRefs = useRef([]);

  useEffect(() => {
    if (autoFocus && inputRefs.current[0] && !disabled) {
      inputRefs.current[0].focus();
    }
  }, [autoFocus, disabled]);

  const handleChange = (e, index) => {
    const val = e.target.value;
    // Allow only single digits
    const cleaned = val.replace(/\D/g, '');

    const newOtp = [...value];
    if (cleaned.length > 0) {
      // Pick the last entered digit
      newOtp[index] = cleaned[cleaned.length - 1];
      onChange(newOtp);

      // Auto advance to next box
      if (index < 5 && inputRefs.current[index + 1]) {
        inputRefs.current[index + 1].focus();
      }

      // Check if all 6 filled
      if (newOtp.every((digit) => digit !== '') && onComplete) {
        onComplete(newOtp.join(''));
      }
    } else {
      newOtp[index] = '';
      onChange(newOtp);
    }
  };

  const handleKeyDown = (e, index) => {
    if (e.key === 'Backspace') {
      if (!value[index] && index > 0 && inputRefs.current[index - 1]) {
        // Current is empty, backspace moves to previous
        inputRefs.current[index - 1].focus();
      }
    } else if (e.key === 'ArrowLeft' && index > 0) {
      inputRefs.current[index - 1].focus();
    } else if (e.key === 'ArrowRight' && index < 5) {
      inputRefs.current[index + 1].focus();
    }
  };

  const handlePaste = (e) => {
    e.preventDefault();
    const pasted = e.clipboardData.getData('text').trim().replace(/\D/g, '').slice(0, 6);
    if (!pasted) return;

    const newOtp = [...value];
    for (let i = 0; i < 6; i++) {
      newOtp[i] = pasted[i] || '';
    }
    onChange(newOtp);

    // Focus appropriate input or the last one
    const targetIndex = Math.min(pasted.length, 5);
    if (inputRefs.current[targetIndex]) {
      inputRefs.current[targetIndex].focus();
    }

    if (pasted.length === 6 && onComplete) {
      onComplete(pasted);
    }
  };

  return (
    <div
      className={`flex items-center justify-center gap-2 sm:gap-3 w-full max-w-sm mx-auto ${className}`}
      onPaste={handlePaste}
    >
      {Array.from({ length: 6 }).map((_, idx) => (
        <input
          key={idx}
          ref={(el) => (inputRefs.current[idx] = el)}
          type="text"
          inputMode="numeric"
          pattern="[0-9]*"
          maxLength={1}
          autoComplete="one-time-code"
          value={value[idx] || ''}
          onChange={(e) => handleChange(e, idx)}
          onKeyDown={(e) => handleKeyDown(e, idx)}
          onFocus={(e) => e.target.select()}
          disabled={disabled}
          aria-label={`Verification digit ${idx + 1}`}
          className={`auth-otp-box w-11 h-13 sm:w-12 sm:h-14 text-center text-xl sm:text-2xl font-black rounded-[14px] bg-white border transition-all duration-200 outline-none
            ${
              error
                ? 'border-[#E45D70] text-[#E45D70] bg-[#FFF5F6] focus:border-[#E45D70] focus:ring-3 focus:ring-[#E45D70]/15'
                : 'border-[#E4ECEF] text-[#101A32] hover:border-[#CBD5E1] focus:border-[#00BFAE] focus:ring-3 focus:ring-[#00BFAE]/15'
            }
            ${disabled ? 'opacity-50 cursor-not-allowed bg-[#F1F5F9]' : ''}
          `}
        />
      ))}
    </div>
  );
}
