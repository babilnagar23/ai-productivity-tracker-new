import React, { useEffect, useState, useRef } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { calendarApi } from '../services/api';
import { RefreshCw } from 'lucide-react';

export default function GoogleCallback() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [error, setError] = useState(null);
  const processed = useRef(false);

  useEffect(() => {
    const code = searchParams.get('code');
    
    if (!code) {
      setError('No authorization code provided by Google.');
      console.error('Google Callback Error: No auth code in URL.');
      return;
    }

    if (processed.current) return;
    processed.current = true;

    const processCode = async () => {
      try {
        console.log("OAuth callback triggered with code:", code);
        await calendarApi.googleCallback(code);
        console.log("Token exchange successful, connection saved.");
        
        // Slight delay to allow backend to persist and ensure smooth redirect
        setTimeout(() => navigate('/calendar'), 500);
      } catch (err) {
        console.error("Token exchange failed:", err);
        setError(err.message || 'Failed to authenticate with Google Calendar.');
      }
    };

    processCode();
  }, [searchParams, navigate]);

  return (
    <div className="min-h-screen flex items-center justify-center bg-[#0a0d1c] p-4">
      <div className="glass card-3d p-8 max-w-md w-full text-center">
        {error ? (
          <div>
            <h2 className="text-xl font-bold text-red-500 mb-4">OAuth Failed</h2>
            <p className="text-sm text-gray-400 mb-6">{error}</p>
            <button 
              onClick={() => navigate('/calendar')}
              className="bg-white/10 hover:bg-white/20 text-white px-6 py-2 rounded-xl transition-colors font-semibold"
            >
              Return to Calendar
            </button>
          </div>
        ) : (
          <div className="flex flex-col items-center gap-4">
            <RefreshCw className="w-10 h-10 text-plasma animate-spin" />
            <h2 className="text-xl font-bold text-white">Connecting Google Calendar...</h2>
            <p className="text-sm text-gray-400">Please wait while we secure your connection.</p>
          </div>
        )}
      </div>
    </div>
  );
}
