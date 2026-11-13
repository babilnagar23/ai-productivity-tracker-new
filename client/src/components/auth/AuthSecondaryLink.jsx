import { Link } from 'react-router-dom';

export default function AuthSecondaryLink({
  to,
  children,
  className = '',
  onClick,
}) {
  return (
    <Link
      to={to}
      onClick={onClick}
      className={`text-xs sm:text-sm font-semibold text-[#00BFAE] hover:text-[#12B8B0] transition-colors focus:outline-none focus-visible:underline ${className}`}
    >
      {children}
    </Link>
  );
}
