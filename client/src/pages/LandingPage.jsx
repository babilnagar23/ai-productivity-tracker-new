import React from 'react';
import { Link } from 'react-router-dom';
import { Zap, Shield, Sparkles, CheckCircle, ArrowRight, BarChart3, Clock, Smartphone } from 'lucide-react';

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-void text-white overflow-hidden selection:bg-cyan/30">
      {/* Background Effects */}
      <div className="fixed inset-0 pointer-events-none">
        <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] rounded-full bg-cyan/10 blur-[120px]" />
        <div className="absolute bottom-[-10%] right-[-10%] w-[40%] h-[40%] rounded-full bg-plasma/10 blur-[120px]" />
        <div className="absolute top-[40%] left-[60%] w-[30%] h-[30%] rounded-full bg-cyan/10 blur-[120px]" />
        <div className="absolute inset-0 bg-grid-pattern opacity-30" />
      </div>

      {/* Navbar */}
      <nav className="relative z-10 flex items-center justify-between px-6 py-4 max-w-7xl mx-auto">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-xl bg-cyan flex items-center justify-center shadow-glow-cyan">
            <Zap className="w-4 h-4 text-black" />
          </div>
          <span className="font-black text-lg tracking-tight">Productive<span className="text-cyan">AI</span></span>
        </div>
        <div className="flex items-center gap-4 text-sm font-semibold">
          <Link to="/login" className="text-gray-300 hover:text-white transition-colors">Sign In</Link>
          <Link to="/signup" className="px-5 py-2.5 rounded-full bg-white/10 hover:bg-white/15 border border-white/10 transition-all backdrop-blur-md">
            Get Started
          </Link>
        </div>
      </nav>

      <main className="relative z-10 max-w-7xl mx-auto px-6 pt-24 pb-32">
        {/* Hero Section */}
        <div className="text-center max-w-3xl mx-auto space-y-8 animate-fadeInUp">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-white/5 border border-white/10 text-xs font-semibold text-cyan mx-auto">
            <Sparkles className="w-3.5 h-3.5" /> Introducing Offline-First Mode
          </div>
          <h1 className="text-5xl md:text-7xl font-hero font-black tracking-tight leading-[1.1]">
            Your Second Brain for <span className="text-cyan">Peak Performance</span>
          </h1>
          <p className="text-lg md:text-xl text-gray-400 max-w-2xl mx-auto leading-relaxed">
            AI-powered task management, Pomodoro timers, and daily routines all in one unified ecosystem.
          </p>
          <div className="flex flex-col sm:flex-row items-center justify-center gap-4 pt-4">
            <Link to="/signup" className="w-full sm:w-auto px-8 py-4 rounded-xl bg-cyan text-black font-bold shadow-glow-cyan hover:opacity-90 transition-all flex items-center justify-center gap-2">
              Start For Free <ArrowRight className="w-4 h-4" />
            </Link>
            <Link to="/login" className="w-full sm:w-auto px-8 py-4 rounded-xl bg-white/5 border border-white/10 text-white font-bold hover:bg-white/10 transition-all flex items-center justify-center">
              Sign In
            </Link>
          </div>
        </div>

        {/* Feature Grid */}
        <div className="mt-32 grid md:grid-cols-3 gap-6">
          <FeatureCard 
            icon={<Clock className="w-6 h-6 text-cyan" />}
            title="Deep Focus"
            desc="Built-in Pomodoro timers and distraction blocking to keep you in the flow state."
            bg="bg-cyan/10" border="border-cyan/20"
          />
          <FeatureCard 
            icon={<BarChart3 className="w-6 h-6 text-cyan" />}
            title="Smart Analytics"
            desc="Track your productivity scores, focus hours, and task completion rates over time."
            bg="bg-cyan/10" border="border-cyan/20"
          />
          <FeatureCard 
            icon={<Smartphone className="w-6 h-6 text-plasma" />}
            title="Seamless Sync"
            desc="Use it on Web or Mobile. Everything syncs perfectly in real-time."
            bg="bg-plasma/10" border="border-plasma/20"
          />
        </div>

      </main>
    </div>
  );
}

function FeatureCard({ icon, title, desc, bg, border }) {
  return (
    <div className="glass card-3d p-8 group hover:-translate-y-1 transition-all duration-300">
      <div className={`w-12 h-12 rounded-2xl ${bg} border ${border} flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-300`}>
        {icon}
      </div>
      <h3 className="text-xl font-bold text-white mb-3">{title}</h3>
      <p className="text-gray-400 leading-relaxed text-sm">{desc}</p>
    </div>
  );
}
