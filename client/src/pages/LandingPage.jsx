import React from 'react';
import { Link } from 'react-router-dom';
import { motion } from 'framer-motion';
import { Zap, Sparkles, BrainCircuit, Activity, BarChart3 } from 'lucide-react';

const LandingPage = () => {
  return (
    <div className="min-h-screen bg-background bg-grid-pattern relative overflow-hidden flex flex-col items-center justify-between py-12 px-6">
      
      {/* Decorative Orbs */}
      <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-blue-500/10 rounded-full blur-[120px] -z-10 animate-pulse"></div>
      <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-purple-500/10 rounded-full blur-[120px] -z-10 animate-pulse"></div>

      {/* Header */}
      <header className="w-full max-w-6xl flex justify-between items-center mb-12">
        <div className="flex items-center gap-3">
          <div className="bg-gradient-to-r from-blue-500 to-purple-600 p-2.5 rounded-2xl shadow-neon">
            <Zap className="h-6 w-6 text-white" />
          </div>
          <span className="font-extrabold text-xl tracking-wider text-white">Productivity Tracker</span>
        </div>
        <div className="flex gap-4">
          <Link to="/login" className="px-5 py-2.5 rounded-xl border border-white/10 hover:bg-white/5 font-semibold text-sm transition-all duration-300">
            Sign In
          </Link>
          <Link to="/signup" className="px-5 py-2.5 rounded-xl bg-gradient-to-r from-blue-600 to-purple-600 font-semibold text-sm shadow-neon hover:opacity-90 transition-all duration-300">
            Get Started
          </Link>
        </div>
      </header>

      {/* Hero Section */}
      <main className="max-w-4xl text-center space-y-8 flex-1 flex flex-col justify-center items-center">
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="flex items-center gap-2 px-4 py-1.5 rounded-full border border-blue-500/30 bg-blue-500/10 text-blue-400 text-xs font-semibold uppercase tracking-widest"
        >
          <Sparkles className="h-4 w-4 animate-spin" /> Hyper-Personalized AI Optimization
        </motion.div>

        <motion.h1
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.1 }}
          className="text-5xl md:text-7xl font-extrabold tracking-tight leading-tight"
        >
          Optimize Your Life. <br />

        </motion.h1>

        <motion.p
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 1, delay: 0.3 }}
          className="text-gray-400 text-lg md:text-xl max-w-2xl leading-relaxed"
        >
          Track routines, optimize sleep patterns, earn XP points, build consistent habit streaks, and generate personalized, hyper-optimized schedules with advanced AI models.
        </motion.p>

        {/* Feature Cards Grid */}
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.4 }}
          className="grid grid-cols-1 md:grid-cols-3 gap-6 w-full max-w-5xl mt-12"
        >
          <div className="glass-card p-6 space-y-4 text-left">
            <div className="bg-blue-500/10 p-3 rounded-xl w-fit">
              <BrainCircuit className="h-6 w-6 text-blue-400" />
            </div>
            <h3 className="font-semibold text-lg text-white">AI Assistant</h3>
            <p className="text-sm text-gray-400">Generate schedules, receive feedback, and study smarter using AI.</p>
          </div>

          <div className="glass-card p-6 space-y-4 text-left">
            <div className="bg-purple-500/10 p-3 rounded-xl w-fit">
              <Activity className="h-6 w-6 text-purple-400" />
            </div>
            <h3 className="font-semibold text-lg text-white">Routine Tracking</h3>
            <p className="text-sm text-gray-400">Log workout, sleep, mobile usage, and custom study sessions daily.</p>
          </div>

          <div className="glass-card p-6 space-y-4 text-left">
            <div className="bg-orange-500/10 p-3 rounded-xl w-fit">
              <BarChart3 className="h-6 w-6 text-orange-400" />
            </div>
            <h3 className="font-semibold text-lg text-white">Advanced Analytics</h3>
            <p className="text-sm text-gray-400">Inspect interactive graphs matching weekly routine consistency.</p>
          </div>
        </motion.div>

        {/* Main CTA */}
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ duration: 1, delay: 0.6 }}
          className="pt-8"
        >
          <Link
            to="/signup"
            className="px-8 py-4 rounded-2xl bg-gradient-to-r from-blue-600 to-purple-600 font-bold text-lg shadow-neon hover:shadow-[0_0_30px_rgba(59,130,246,0.6)] hover:scale-105 transition-all duration-300 text-white"
          >
            Deploy Your AI Coach
          </Link>
        </motion.div>
      </main>

      {/* Footer */}
      <footer className="w-full text-center text-xs text-gray-500 mt-12 border-t border-white/5 pt-6 max-w-6xl">
        &copy; {new Date().getFullYear()} Productivity Tracker Platform. Built for peak potential.
      </footer>
    </div>
  );
};

export default LandingPage;
