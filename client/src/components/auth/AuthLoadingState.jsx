export default function AuthLoadingState({
  message = 'Loading...',
  size = 'md',
  className = '',
}) {
  const sizeClasses = {
    sm: 'w-6 h-6 border-2',
    md: 'w-10 h-10 border-3',
    lg: 'w-14 h-14 border-4',
  };

  return (
    <div className={`flex flex-col items-center justify-center gap-4 py-8 text-center ${className}`}>
      <div
        className={`${sizeClasses[size] || sizeClasses.md} rounded-full border-[#00BFAE]/20 border-t-[#00BFAE] animate-spin`}
      />
      {message && <p className="text-sm font-medium text-[#526179]">{message}</p>}
    </div>
  );
}
