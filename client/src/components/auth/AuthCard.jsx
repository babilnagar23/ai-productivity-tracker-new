export default function AuthCard({ children, className = '' }) {
  return (
    <div
      className={`w-full max-w-[480px] bg-white border border-[#E4ECEF] rounded-[24px] shadow-[0_16px_50px_rgba(16,26,50,0.07)] p-6 sm:p-9 space-y-6 relative z-10 transition-shadow duration-300 ${className}`}
    >
      {children}
    </div>
  );
}
