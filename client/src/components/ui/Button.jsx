import React from 'react';

export default function Button({
  children, onClick, type = 'button', variant = 'primary',
  size = 'md', disabled = false, loading = false, className = '', icon: Icon, fullWidth = false
}) {
  const base = 'inline-flex items-center justify-center gap-2 font-semibold rounded-xl transition-all duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500/60 disabled:opacity-50 disabled:cursor-not-allowed';

  const variants = {
    primary:   'bg-gradient-primary text-white hover:opacity-90 glow-blue shadow-lg',
    secondary: 'bg-white/5 border border-white/10 text-gray-300 hover:bg-white/10 hover:text-white',
    ghost:     'text-gray-400 hover:text-white hover:bg-white/5',
    danger:    'bg-rose-500/15 border border-rose-500/20 text-rose-400 hover:bg-rose-500/25',
    success:   'bg-green-500/15 border border-green-500/20 text-green-400 hover:bg-green-500/25',
    teal:      'bg-teal-500/15 border border-teal-500/20 text-teal-400 hover:bg-teal-500/25',
  };

  const sizes = {
    xs: 'px-2.5 py-1.5 text-xs',
    sm: 'px-3.5 py-2 text-sm',
    md: 'px-4 py-2.5 text-sm',
    lg: 'px-6 py-3 text-base',
  };

  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled || loading}
      className={`${base} ${variants[variant]} ${sizes[size]} ${fullWidth ? 'w-full' : ''} ${className}`}
    >
      {loading ? (
        <svg className="animate-spin w-4 h-4" viewBox="0 0 24 24" fill="none">
          <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
          <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
        </svg>
      ) : Icon ? (
        <Icon className="w-4 h-4" />
      ) : null}
      {children}
    </button>
  );
}
