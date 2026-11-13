import { AlertCircle, CheckCircle2, Info, AlertTriangle } from 'lucide-react';

export default function AuthAlert({ type = 'error', message, children, className = '' }) {
  const content = message || children;
  if (!content) return null;

  const configs = {
    error: {
      bg: 'bg-[#FFF5F6]',
      border: 'border-[#E45D70]/30',
      text: 'text-[#E45D70]',
      icon: <AlertCircle className="w-4 h-4 text-[#E45D70] flex-shrink-0 mt-0.5" />,
    },
    success: {
      bg: 'bg-[#E5F7F2]',
      border: 'border-[#0DAD83]/35',
      text: 'text-[#0DAD83]',
      icon: <CheckCircle2 className="w-4 h-4 text-[#0DAD83] flex-shrink-0 mt-0.5" />,
    },
    info: {
      bg: 'bg-[#F0FAF8]',
      border: 'border-[#4A9EDB]/30',
      text: 'text-[#526179]',
      icon: <Info className="w-4 h-4 text-[#4A9EDB] flex-shrink-0 mt-0.5" />,
    },
    warning: {
      bg: 'bg-[#FFF9F0]',
      border: 'border-[#F3A64A]/30',
      text: 'text-[#B46B18]',
      icon: <AlertTriangle className="w-4 h-4 text-[#F3A64A] flex-shrink-0 mt-0.5" />,
    },
  };

  const current = configs[type] || configs.error;

  return (
    <div
      role="alert"
      className={`p-3.5 sm:p-4 rounded-xl border flex items-start gap-2.5 text-xs sm:text-sm leading-relaxed ${current.bg} ${current.border} ${current.text} ${className}`}
    >
      {current.icon}
      <div className="flex-1 font-medium">{content}</div>
    </div>
  );
}
