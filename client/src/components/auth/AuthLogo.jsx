import { Link } from 'react-router-dom';
import { Zap } from 'lucide-react';

export default function AuthLogo({ linkTo = '/', showText = true, className = '' }) {
  return (
    <Link
      to={linkTo}
      className={`inline-flex flex-col items-center gap-3 group focus:outline-none focus-visible:ring-2 focus-visible:ring-[#00BFAE] rounded-2xl ${className}`}
      aria-label="ProductiveAI Home"
    >
      {/* Brand Icon: Teal rounded-square with dark navy lightning symbol */}
      <div className="w-13 h-13 sm:w-14 sm:h-14 rounded-2xl bg-gradient-to-br from-[#00BFAE] to-[#12B8B0] flex items-center justify-center shadow-md shadow-[#00BFAE]/25 transition-transform duration-200 group-hover:scale-105">
        <Zap className="w-7 h-7 text-[#101A32] fill-[#101A32]" />
      </div>

      {showText && (
        <span className="font-hero font-black text-xl tracking-tight text-[#101A32]">
          Productive<span className="text-[#00BFAE]">AI</span>
        </span>
      )}
    </Link>
  );
}
