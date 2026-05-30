import React from 'react';
import { motion } from 'framer-motion';
import { Zap, Brain, Moon, Flame, Heart, Clock, TrendingUp, AlertTriangle, Sparkles } from 'lucide-react';

const ICON_MAP = {
  zap: Zap,
  brain: Brain,
  moon: Moon,
  flame: Flame,
  heart: Heart,
  clock: Clock,
  'trending-up': TrendingUp,
  'alert-triangle': AlertTriangle,
  sparkles: Sparkles,
};

const TYPE_GRADIENTS = {
  peak_hours:     'linear-gradient(135deg, rgba(245,158,11,0.15), rgba(239,68,68,0.08))',
  burnout_risk:   'linear-gradient(135deg, rgba(239,68,68,0.15), rgba(139,92,246,0.08))',
  consistency:    'linear-gradient(135deg, rgba(16,185,129,0.15), rgba(6,182,212,0.08))',
  sleep_impact:   'linear-gradient(135deg, rgba(99,102,241,0.15), rgba(139,92,246,0.08))',
  exercise_impact:'linear-gradient(135deg, rgba(16,185,129,0.15), rgba(245,158,11,0.08))',
  screen_time:    'linear-gradient(135deg, rgba(239,68,68,0.15), rgba(245,158,11,0.08))',
  focus_pattern:  'linear-gradient(135deg, rgba(59,130,246,0.15), rgba(139,92,246,0.08))',
  general:        'linear-gradient(135deg, rgba(139,92,246,0.15), rgba(59,130,246,0.08))',
};

const TYPE_BORDERS = {
  peak_hours:     'rgba(245,158,11,0.3)',
  burnout_risk:   'rgba(239,68,68,0.3)',
  consistency:    'rgba(16,185,129,0.3)',
  sleep_impact:   'rgba(99,102,241,0.3)',
  exercise_impact:'rgba(16,185,129,0.3)',
  screen_time:    'rgba(239,68,68,0.3)',
  focus_pattern:  'rgba(59,130,246,0.3)',
  general:        'rgba(139,92,246,0.3)',
};

const TYPE_ICON_COLORS = {
  peak_hours:     '#F59E0B',
  burnout_risk:   '#EF4444',
  consistency:    '#10B981',
  sleep_impact:   '#818CF8',
  exercise_impact:'#10B981',
  screen_time:    '#F87171',
  focus_pattern:  '#3B82F6',
  general:        '#8B5CF6',
};

const AIInsightCard = ({ insight, index }) => {
  const IconComponent = ICON_MAP[insight.icon] || Sparkles;
  const gradient = TYPE_GRADIENTS[insight.type] || TYPE_GRADIENTS.general;
  const borderColor = TYPE_BORDERS[insight.type] || TYPE_BORDERS.general;
  const iconColor = TYPE_ICON_COLORS[insight.type] || '#8B5CF6';

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.08, type: 'spring', stiffness: 200 }}
      whileHover={{ scale: 1.02, y: -2 }}
      className="rounded-2xl p-4 cursor-default"
      style={{
        background: gradient,
        border: `1px solid ${borderColor}`,
        backdropFilter: 'blur(12px)',
      }}
    >
      <div className="flex items-start gap-3">
        <div
          className="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0 mt-0.5"
          style={{ background: `${iconColor}20`, border: `1px solid ${iconColor}40` }}
        >
          <IconComponent className="w-4 h-4" style={{ color: iconColor }} />
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold text-white leading-tight mb-1">
            {insight.title}
          </p>
          <p className="text-xs text-gray-400 leading-relaxed">
            {insight.body}
          </p>
        </div>
      </div>

      {insight.score !== null && insight.score !== undefined && (
        <div className="mt-3 flex items-center gap-2">
          <div className="flex-1 h-1 rounded-full bg-white/10 overflow-hidden">
            <motion.div
              initial={{ width: 0 }}
              animate={{ width: `${insight.score}%` }}
              transition={{ delay: index * 0.08 + 0.3, duration: 0.8, ease: 'easeOut' }}
              className="h-full rounded-full"
              style={{ background: `linear-gradient(90deg, ${iconColor}, ${iconColor}80)` }}
            />
          </div>
          <span className="text-xs font-bold" style={{ color: iconColor }}>
            {insight.score}%
          </span>
        </div>
      )}
    </motion.div>
  );
};

export default AIInsightCard;
