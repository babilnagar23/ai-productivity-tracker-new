import React, { useState, useEffect, useRef } from 'react';
import Sidebar from '../Sidebar';
import Topbar from '../Topbar';
import { notificationsApi } from '../../services/api';

// Module-level cache so navigating between pages doesn't re-fetch
let _cachedUnreadCount = 0;
let _lastFetchTime = 0;
const CACHE_TTL = 30_000; // 30 seconds

export default function AppLayout({ children, title }) {
  const [collapsed, setCollapsed] = useState(false);
  const [unreadCount, setUnreadCount] = useState(_cachedUnreadCount);
  const fetchGuard = useRef(false);

  useEffect(() => {
    // Prevent StrictMode double-fetch
    if (fetchGuard.current) return;
    fetchGuard.current = true;

    const fetchUnread = async (force = false) => {
      const now = Date.now();
      // Skip if cache is still fresh and not forced
      if (!force && now - _lastFetchTime < CACHE_TTL) {
        setUnreadCount(_cachedUnreadCount);
        return;
      }
      try {
        const data = await notificationsApi.list();
        const items = data?.data || data?.results || data || [];
        const unread = Array.isArray(items) ? items.filter(n => !n.read && !n.read_at).length : 0;
        _cachedUnreadCount = unread;
        _lastFetchTime = Date.now();
        setUnreadCount(unread);
      } catch {
        // Silently fail — not critical
      }
    };

    fetchUnread();
    const interval = setInterval(() => fetchUnread(true), 60000); // Force refresh every minute
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="flex h-screen overflow-hidden bg-[#050816]">
      {/* Sidebar */}
      <Sidebar
        collapsed={collapsed}
        onToggle={() => setCollapsed(!collapsed)}
        unreadCount={unreadCount}
      />

      {/* Main content area */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        <Topbar title={title} unreadCount={unreadCount} />

        <main className="flex-1 overflow-y-auto bg-[#050816]">
          <div className="min-h-full p-6">
            {children}
          </div>
        </main>
      </div>
    </div>
  );
}
