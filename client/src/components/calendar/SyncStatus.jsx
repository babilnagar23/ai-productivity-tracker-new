import { motion } from 'framer-motion';
import { Wifi, WifiOff, RefreshCw, Clock } from 'lucide-react';
import { format, parseISO } from 'date-fns';

const SyncStatus = ({ connected, googleEmail, lastSynced, isSyncing, onSync, onConnect }) => {
  const getStatusColor = () => {
    if (!connected) return '#EF4444';
    if (isSyncing) return '#F59E0B';
    return '#10B981';
  };

  const getStatusText = () => {
    if (!connected) return 'Not Connected';
    if (isSyncing) return 'Syncing...';
    return 'Connected';
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      className="rounded-2xl border border-white/10 overflow-hidden"
      style={{ background: 'rgba(255,255,255,0.03)' }}
    >
      {/* Header */}
      <div className="px-4 pt-4 pb-2 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <motion.div
            animate={{ scale: isSyncing ? [1, 1.2, 1] : 1 }}
            transition={{ repeat: isSyncing ? Infinity : 0, duration: 1 }}
          >
            {connected ? (
              <Wifi className="w-4 h-4" style={{ color: getStatusColor() }} />
            ) : (
              <WifiOff className="w-4 h-4 text-red-400" />
            )}
          </motion.div>
          <span className="text-xs font-semibold text-gray-300 uppercase tracking-wider">
            Google Sync
          </span>
        </div>

        {/* Live pulse indicator */}
        <div className="flex items-center gap-1.5">
          <motion.div
            animate={{
              opacity: connected ? [1, 0.3, 1] : 1,
              scale: connected ? [1, 1.3, 1] : 1,
            }}
            transition={{ repeat: Infinity, duration: 2 }}
            className="w-2 h-2 rounded-full"
            style={{ backgroundColor: getStatusColor() }}
          />
          <span className="text-xs font-medium" style={{ color: getStatusColor() }}>
            {getStatusText()}
          </span>
        </div>
      </div>

      <div className="px-4 pb-4 space-y-3">
        {/* Google account email */}
        {connected && googleEmail && (
          <div className="flex items-center gap-2 py-2 px-3 rounded-xl bg-white/5">
            <div className="w-5 h-5 rounded-full bg-gradient-to-br from-blue-400 to-purple-500 flex items-center justify-center text-xs font-bold text-white">
              {googleEmail[0]?.toUpperCase()}
            </div>
            <span className="text-xs text-gray-300 truncate">{googleEmail}</span>
          </div>
        )}

        {/* Last synced */}
        {lastSynced && (
          <div className="flex items-center gap-2 text-xs text-gray-500">
            <Clock className="w-3 h-3" />
            <span>
              Last synced: {format(parseISO(lastSynced), 'MMM d, h:mm a')}
            </span>
          </div>
        )}

        {/* Action buttons */}
        <div className="flex gap-2">
          {connected ? (
            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              onClick={onSync}
              disabled={isSyncing}
              className="flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-xl text-xs font-semibold transition-all disabled:opacity-50"
              style={{
                background: 'linear-gradient(135deg, rgba(59,130,246,0.2), rgba(139,92,246,0.2))',
                border: '1px solid rgba(59,130,246,0.3)',
                color: '#93C5FD',
              }}
            >
              <motion.div
                animate={{ rotate: isSyncing ? 360 : 0 }}
                transition={{ repeat: isSyncing ? Infinity : 0, duration: 1, ease: 'linear' }}
              >
                <RefreshCw className="w-3 h-3" />
              </motion.div>
              {isSyncing ? 'Syncing...' : 'Sync Now'}
            </motion.button>
          ) : (
            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              onClick={onConnect}
              className="flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-xl text-xs font-semibold"
              style={{
                background: 'linear-gradient(135deg, #3B82F6, #8B5CF6)',
                color: 'white',
              }}
            >
              <Wifi className="w-3 h-3" />
              Connect Google
            </motion.button>
          )}
        </div>
      </div>
    </motion.div>
  );
};

export default SyncStatus;
