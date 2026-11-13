import { Link } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';

export default function AuthLayout({
  children,
  showBackHome = true,
  className = '',
}) {
  return (
    <div className={`auth-page min-h-screen flex flex-col justify-between p-4 sm:p-6 lg:p-8 relative selection:bg-[#00BFAE]/20 selection:text-[#101A32] ${className}`}>
      {/* Background radial glow accents */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden z-0" aria-hidden="true">
        {/* Soft turquoise radial glow behind card */}
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[520px] h-[520px] rounded-full bg-[#00BFAE]/8 blur-[120px]" />
        {/* Top-left subtle mint accent */}
        <div className="absolute -top-[10%] -left-[10%] w-[45%] h-[45%] rounded-full bg-[#12B8B0]/8 blur-[100px]" />
        {/* Bottom-right subtle accent */}
        <div className="absolute -bottom-[10%] -right-[10%] w-[45%] h-[45%] rounded-full bg-[#00BFAE]/6 blur-[100px]" />
        {/* Extremely subtle dot grid pattern */}
        <div className="absolute inset-0 bg-grid-pattern-light opacity-30" />
      </div>

      {/* Top minimal bar with Home link */}
      <header className="relative z-10 max-w-5xl mx-auto w-full flex items-center justify-between py-2">
        {showBackHome ? (
          <Link
            to="/"
            className="inline-flex items-center gap-1.5 text-xs sm:text-sm font-semibold text-[#526179] hover:text-[#00BFAE] transition-colors px-3 py-1.5 rounded-full hover:bg-[#E5F7F2]/60 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#00BFAE]"
          >
            <ArrowLeft className="w-3.5 h-3.5" />
            <span>Back to Home</span>
          </Link>
        ) : (
          <div />
        )}
      </header>

      {/* Centered Main Authentication Content */}
      <main className="relative z-10 flex-1 flex flex-col items-center justify-center my-auto py-6 sm:py-10 w-full">
        {children}
      </main>

      {/* Minimal Footer */}
      <footer className="relative z-10 text-center py-4 text-xs text-[#8290A5]">
        <p>© {new Date().getFullYear()} ProductiveAI. All rights reserved.</p>
      </footer>
    </div>
  );
}
