import { Check, X } from 'lucide-react';

export default function PasswordStrengthMeter({ password = '', className = '' }) {
  const rules = [
    { id: 'length', label: 'At least 8 characters', valid: password.length >= 8 },
    { id: 'upper', label: '1 uppercase letter', valid: /[A-Z]/.test(password) },
    { id: 'lower', label: '1 lowercase letter', valid: /[a-z]/.test(password) },
    { id: 'number', label: '1 number', valid: /[0-9]/.test(password) },
    { id: 'special', label: '1 special character (!@#$%^&*)', valid: /[!@#$%^&*(),.?":{}|<>]/.test(password) },
  ];

  const validCount = rules.filter((r) => r.valid).length;

  let strengthLabel = '';
  let strengthColor = 'bg-[#E4ECEF]';
  let textColor = 'text-[#8290A5]';

  if (password.length > 0) {
    if (validCount <= 2) {
      strengthLabel = 'Weak';
      strengthColor = 'bg-[#E45D70]';
      textColor = 'text-[#E45D70]';
    } else if (validCount <= 4) {
      strengthLabel = 'Medium';
      strengthColor = 'bg-[#F3A64A]';
      textColor = 'text-[#F3A64A]';
    } else {
      strengthLabel = 'Strong';
      strengthColor = 'bg-[#0DAD83]';
      textColor = 'text-[#0DAD83]';
    }
  }

  return (
    <div className={`space-y-3 py-1 ${className}`}>
      {/* 3-segment progress meter */}
      <div className="space-y-1.5">
        <div className="flex items-center justify-between text-xs">
          <span className="font-medium text-[#526179]">Password strength</span>
          {strengthLabel && (
            <span className={`font-bold transition-colors ${textColor}`}>
              {strengthLabel}
            </span>
          )}
        </div>

        <div className="flex gap-1.5 h-1.5 w-full">
          {[1, 2, 3].map((segment) => {
            const isActive =
              (segment === 1 && validCount >= 1) ||
              (segment === 2 && validCount >= 3) ||
              (segment === 3 && validCount === 5);

            return (
              <div
                key={segment}
                className={`flex-1 h-full rounded-full transition-all duration-300 ${
                  isActive ? strengthColor : 'bg-[#E4ECEF]'
                }`}
              />
            );
          })}
        </div>
      </div>

      {/* 5 requirement checklist items */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 pt-1">
        {rules.map((rule) => (
          <div
            key={rule.id}
            className={`flex items-center gap-2 text-xs transition-colors duration-200 ${
              rule.valid ? 'text-[#0DAD83] font-medium' : 'text-[#8290A5]'
            }`}
          >
            <div
              className={`w-4 h-4 rounded-full flex items-center justify-center flex-shrink-0 transition-colors ${
                rule.valid
                  ? 'bg-[#E5F7F2] text-[#0DAD83]'
                  : 'bg-[#F1F5F9] text-[#8290A5]'
              }`}
            >
              {rule.valid ? (
                <Check className="w-2.5 h-2.5 stroke-[3]" />
              ) : (
                <X className="w-2.5 h-2.5 stroke-[2.5]" />
              )}
            </div>
            <span>{rule.label}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
