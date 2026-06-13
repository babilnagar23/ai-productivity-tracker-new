import  { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Plus, Calendar, CheckSquare, Sparkles, X } from 'lucide-react';

const FloatingActionButton = ({ onAddEvent, onAddTask, onAIGenerate }) => {
  const [isOpen, setIsOpen] = useState(false);

  const actions = [
    {
      id: 'ai',
      label: 'AI Generate',
      icon: Sparkles,
      gradient: 'linear-gradient(135deg, #8B5CF6, #EC4899)',
      glow: 'rgba(139,92,246,0.5)',
      onClick: () => { onAIGenerate(); setIsOpen(false); },
    },
    {
      id: 'task',
      label: 'Add Task',
      icon: CheckSquare,
      gradient: 'linear-gradient(135deg, #10B981, #06B6D4)',
      glow: 'rgba(16,185,129,0.5)',
      onClick: () => { onAddTask(); setIsOpen(false); },
    },
    {
      id: 'event',
      label: 'Add Event',
      icon: Calendar,
      gradient: 'linear-gradient(135deg, #3B82F6, #8B5CF6)',
      glow: 'rgba(59,130,246,0.5)',
      onClick: () => { onAddEvent(); setIsOpen(false); },
    },
  ];

  return (
    <div className="fixed bottom-8 right-8 z-50 flex flex-col items-end gap-3">
      <AnimatePresence>
        {isOpen && actions.map((action, i) => (
          <motion.div
            key={action.id}
            initial={{ opacity: 0, x: 20, scale: 0.8 }}
            animate={{ opacity: 1, x: 0, scale: 1 }}
            exit={{ opacity: 0, x: 20, scale: 0.8 }}
            transition={{ delay: i * 0.06, type: 'spring', stiffness: 300, damping: 20 }}
            className="flex items-center gap-3"
          >
            {/* Label */}
            <motion.div
              className="px-3 py-1.5 rounded-xl text-xs font-semibold text-white whitespace-nowrap"
              style={{ background: 'rgba(13,17,38,0.9)', border: '1px solid rgba(255,255,255,0.1)', backdropFilter: 'blur(12px)' }}
            >
              {action.label}
            </motion.div>
            {/* Button */}
            <motion.button
              whileHover={{ scale: 1.1 }}
              whileTap={{ scale: 0.9 }}
              onClick={action.onClick}
              className="w-12 h-12 rounded-2xl flex items-center justify-center shadow-lg"
              style={{
                background: action.gradient,
                boxShadow: `0 0 20px ${action.glow}`,
              }}
            >
              <action.icon className="w-5 h-5 text-white" />
            </motion.button>
          </motion.div>
        ))}
      </AnimatePresence>

      {/* Main FAB */}
      <motion.button
        whileHover={{ scale: 1.08 }}
        whileTap={{ scale: 0.92 }}
        onClick={() => setIsOpen(!isOpen)}
        className="w-16 h-16 rounded-2xl flex items-center justify-center relative"
        style={{
          background: 'linear-gradient(135deg, #3B82F6, #8B5CF6)',
          boxShadow: isOpen
            ? '0 0 40px rgba(139,92,246,0.7), 0 0 80px rgba(59,130,246,0.3)'
            : '0 0 25px rgba(59,130,246,0.5), 0 0 50px rgba(139,92,246,0.2)',
        }}
        animate={{ rotate: isOpen ? 45 : 0 }}
        transition={{ type: 'spring', stiffness: 300, damping: 20 }}
      >
        {/* Pulsing glow ring */}
        <motion.div
          className="absolute inset-0 rounded-2xl"
          animate={{ scale: [1, 1.15, 1], opacity: [0.5, 0, 0.5] }}
          transition={{ repeat: Infinity, duration: 2 }}
          style={{ background: 'linear-gradient(135deg, #3B82F6, #8B5CF6)', zIndex: -1 }}
        />
        <AnimatePresence mode="wait">
          {isOpen ? (
            <motion.div key="close" initial={{ rotate: -45, opacity: 0 }} animate={{ rotate: 0, opacity: 1 }} exit={{ rotate: 45, opacity: 0 }}>
              <X className="w-7 h-7 text-white" />
            </motion.div>
          ) : (
            <motion.div key="plus" initial={{ rotate: 45, opacity: 0 }} animate={{ rotate: 0, opacity: 1 }} exit={{ rotate: -45, opacity: 0 }}>
              <Plus className="w-7 h-7 text-white" />
            </motion.div>
          )}
        </AnimatePresence>
      </motion.button>
    </div>
  );
};

export default FloatingActionButton;
