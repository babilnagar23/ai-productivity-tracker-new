import React from 'react';

export default function Badge({ children, variant = 'blue', size = 'sm', dot = false }) {
  const variants = {
    blue:   'bg-blue-500/15 text-blue-400 border-blue-500/20',
    purple: 'bg-purple-500/15 text-purple-400 border-purple-500/20',
    green:  'bg-green-500/15 text-green-400 border-green-500/20',
    teal:   'bg-teal-500/15 text-teal-400 border-teal-500/20',
    orange: 'bg-orange-500/15 text-orange-400 border-orange-500/20',
    rose:   'bg-rose-500/15 text-rose-400 border-rose-500/20',
    gray:   'bg-white/5 text-gray-400 border-white/10',
    yellow: 'bg-yellow-500/15 text-yellow-400 border-yellow-500/20',
  };

  const dotColors = {
    blue: 'bg-blue-400', purple: 'bg-purple-400', green: 'bg-green-400',
    teal: 'bg-teal-400', orange: 'bg-orange-400', rose: 'bg-rose-400',
    gray: 'bg-gray-400', yellow: 'bg-yellow-400',
  };

  const sizes = {
    xs: 'text-[10px] px-1.5 py-0.5',
    sm: 'text-xs px-2 py-0.5',
    md: 'text-sm px-2.5 py-1',
  };

  return (
    <span className={`inline-flex items-center gap-1.5 rounded-full border font-semibold ${variants[variant]} ${sizes[size]}`}>
      {dot && <span className={`w-1.5 h-1.5 rounded-full ${dotColors[variant]}`} />}
      {children}
    </span>
  );
}
