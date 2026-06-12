import React, { useState, useEffect } from 'react';
import Sidebar from '../Sidebar';
import Topbar from '../Topbar';
import { notificationsApi } from '../../services/api';

export default function AppLayout({ children, title }) {
  const [collapsed, setCollapsed] = useState(false);
  const [unreadCount, setUnreadCount] = useState(0);

  useEffect(() => {
    const fetchUnread = async () => {
      try {
        const data = await notificationsApi.list();
        const items = data?.data || data?.results || data || [];
        const unread = Array.isArray(items) ? items.filter(n => !n.read && !n.read_at).length : 0;
        setUnreadCount(unread);
      } catch {
        // Silently fail — not critical
      }
    };
    fetchUnread();
    const interval = setInterval(fetchUnread, 60000); // Refresh every minute
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
