import React from 'react';

export function Spinner({ size = 'md', color = 'blue' }) {
  const sizes = { xs: 'w-3 h-3', sm: 'w-4 h-4', md: 'w-6 h-6', lg: 'w-8 h-8', xl: 'w-12 h-12' };
  const colors = { blue: 'border-blue-500', purple: 'border-purple-500', teal: 'border-teal-500', white: 'border-white' };
  return (
    <div className={`${sizes[size]} rounded-full border-2 border-transparent ${colors[color]} border-t-current animate-spin`} />
  );
}

export function SpinnerPage() {
  return (
    <div className="flex items-center justify-center min-h-screen bg-[#050816]">
      <div className="text-center space-y-4">
        <Spinner size="xl" color="blue" />
        <p className="text-gray-400 text-sm animate-pulse">Loading...</p>
      </div>
    </div>
  );
}
