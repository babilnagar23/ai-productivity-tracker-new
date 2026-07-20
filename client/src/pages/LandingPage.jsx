import React from 'react';
import { Link } from 'react-router-dom';
import { Zap, ArrowRight, BarChart3, Clock, Smartphone, Check, LayoutDashboard, Target, Flame } from 'lucide-react';
import { motion } from 'framer-motion';
import logoImg from '../assets/logo.png';

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-white text-slate-900 overflow-hidden font-sans selection:bg-teal-500/30">
      {/* Background Effects */}
      <div className="fixed inset-0 pointer-events-none">
        <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-teal-500/10 blur-[120px]" />
        <div className="absolute bottom-[-10%] right-[-10%] w-[50%] h-[50%] rounded-full bg-cyan-500/10 blur-[120px]" />
        <div className="absolute top-[40%] left-[60%] w-[40%] h-[40%] rounded-full bg-emerald-500/10 blur-[120px]" />
        <div className="absolute inset-0 bg-grid-pattern-light opacity-50" />
      </div>

      {/* Navbar */}
      <nav className="relative z-50 flex items-center justify-between px-6 py-4 max-w-7xl mx-auto sticky top-0 bg-white/70 backdrop-blur-md border-b border-slate-200/50">
        <div className="flex items-center gap-2">
          <img src={logoImg} alt="ProductiveAI Logo" className="w-8 h-8 object-contain rounded-xl" />
          <span className="font-black text-xl tracking-tight text-slate-900">Productive<span className="text-teal-500">AI</span></span>
        </div>
        <div className="flex items-center gap-4 text-sm font-semibold">
          <Link to="/login" className="text-slate-600 hover:text-slate-900 transition-colors">Sign In</Link>
          <Link to="/signup" className="px-5 py-2.5 rounded-full bg-teal-500 hover:bg-teal-600 text-white shadow-md shadow-teal-500/20 transition-all">
            Get Started
          </Link>
        </div>
      </nav>

      <main className="relative z-10 max-w-7xl mx-auto px-6 pt-16 pb-32">
        {/* Hero Section */}
        <div className="grid lg:grid-cols-2 gap-12 items-center min-h-[70vh]">
          {/* Left Side: Copy */}
          <div className="space-y-8 animate-fadeInUp z-20">
            
            <h1 className="text-5xl md:text-7xl font-hero font-black tracking-tight leading-[1.1] text-slate-900">
              Your Second Brain for <br/>
              <span className="text-transparent bg-clip-text bg-gradient-to-r from-teal-500 to-cyan-500">Peak Performance</span>
            </h1>
            <p className="text-lg md:text-xl text-slate-600 max-w-xl leading-relaxed">
              AI-powered task management, Pomodoro timers, analytics and routines in one intelligent productivity platform.
            </p>
            <div className="flex flex-col sm:flex-row items-center gap-4 pt-4">
              <Link to="/signup" className="w-full sm:w-auto px-8 py-4 rounded-xl bg-teal-500 text-white font-bold shadow-lg shadow-teal-500/30 hover:-translate-y-1 hover:shadow-teal-500/40 transition-all flex items-center justify-center gap-2">
                Start For Free <ArrowRight className="w-4 h-4" />
              </Link>
            </div>
          </div>

          {/* Right Side: Mockup */}
          <div className="relative w-full h-[600px] hidden lg:flex items-center justify-center">
             <MobileMockup />
          </div>
        </div>

        {/* Feature Strip */}
        <div className="mt-24 max-w-4xl mx-auto">
           <div className="glass-card-light py-6 px-8 flex flex-wrap justify-between items-center gap-6">
              <FeatureStripItem icon={<Zap className="w-5 h-5 text-teal-500"/>} title="AI Powered" desc="Smart insights that improve you" />
              <div className="w-px h-12 bg-slate-200 hidden md:block"></div>
              <FeatureStripItem icon={<Check className="w-5 h-5 text-emerald-500"/>} title="Secure & Private" desc="Your data is always safe" />
              <div className="w-px h-12 bg-slate-200 hidden md:block"></div>
              <FeatureStripItem icon={<Smartphone className="w-5 h-5 text-cyan-500"/>} title="Cross Platform" desc="Sync across all your devices" />
           </div>
        </div>
        
        {/* Features Header */}
        <div className="mt-32 text-center max-w-2xl mx-auto space-y-4">
            <h2 className="text-3xl md:text-4xl font-bold tracking-tight text-slate-900">
              Everything you need to <br/> stay <span className="text-teal-500">productive</span>
            </h2>
            <p className="text-slate-600">Powerful tools designed to help you focus, track, and achieve more.</p>
        </div>

        {/* Features Grid */}
        <div className="mt-16 grid md:grid-cols-3 gap-8">
          <FeatureCard 
            icon={<Clock className="w-8 h-8 text-emerald-500" />}
            title="Deep Focus"
            desc="Built-in Pomodoro timers and distraction blocking to keep you in the flow state."
            bg="bg-emerald-50" border="border-emerald-100"
            color="emerald"
          />
          <FeatureCard 
            icon={<BarChart3 className="w-8 h-8 text-cyan-500" />}
            title="Smart Analytics"
            desc="Track your productivity scores, focus hours, and task completion rates over time."
            bg="bg-cyan-50" border="border-cyan-100"
            color="cyan"
          />
          <FeatureCard 
            icon={<Smartphone className="w-8 h-8 text-teal-500" />}
            title="Seamless Sync"
            desc="Use it on Web or Mobile. Everything syncs perfectly in real-time."
            bg="bg-teal-50" border="border-teal-100"
            badge="Coming Soon"
            color="teal"
          />
        </div>

      </main>
    </div>
  );
}

function FeatureStripItem({ icon, title, desc }) {
  return (
    <div className="flex items-center gap-4">
       <div className="w-10 h-10 rounded-full bg-slate-50 border border-slate-100 flex items-center justify-center">
         {icon}
       </div>
       <div>
         <h4 className="font-bold text-slate-900 text-sm">{title}</h4>
         <p className="text-xs text-slate-500">{desc}</p>
       </div>
    </div>
  );
}

function FeatureCard({ icon, title, desc, bg, border, badge, color }) {
  const colorMap = {
      'emerald': 'text-emerald-500',
      'cyan': 'text-cyan-500',
      'teal': 'text-teal-500'
  }
  const textColor = colorMap[color] || 'text-teal-500';

  return (
    <div className="relative glass-card-light p-8 group flex flex-col items-start h-full">
      {badge && (
        <span className="absolute top-6 right-6 px-3 py-1 rounded-full bg-slate-100 text-slate-600 text-[10px] font-bold uppercase tracking-wider">
          {badge}
        </span>
      )}
      <div className={`w-16 h-16 rounded-2xl ${bg} border ${border} flex items-center justify-center mb-6 group-hover:scale-110 transition-transform duration-300`}>
        {icon}
      </div>
      <h3 className="text-xl font-bold text-slate-900 mb-3">{title}</h3>
      <p className="text-slate-600 leading-relaxed text-sm flex-grow mb-6">{desc}</p>
      
      <button className={`mt-auto text-sm font-bold ${textColor} flex items-center gap-2 group/btn`}>
         Learn More <ArrowRight className="w-4 h-4 group-hover/btn:translate-x-1 transition-transform" />
      </button>
    </div>
  );
}

function MobileMockup() {
  return (
    <div className="relative w-full h-full flex justify-center items-center">
      {/* Phone Frame */}
      <motion.div 
        initial={{ y: 20, opacity: 0 }}
        animate={{ y: 0, opacity: 1 }}
        transition={{ duration: 0.8, ease: "easeOut" }}
        className="relative z-10 w-[280px] h-[580px] bg-white rounded-[3rem] shadow-2xl shadow-teal-900/10 border-8 border-slate-50 flex flex-col overflow-hidden"
      >
        {/* Dynamic Island / Notch */}
        <div className="absolute top-2 left-1/2 -translate-x-1/2 w-24 h-6 bg-slate-900 rounded-full z-20"></div>

        {/* Mockup Content */}
        <div className="flex-1 w-full bg-slate-50 pt-12 px-5 pb-6 flex flex-col gap-4 relative overflow-hidden">
           {/* Header */}
           <div className="flex justify-between items-center mb-2">
             <div>
               <div className="text-[10px] text-slate-400 font-bold uppercase tracking-wider">Good Morning,</div>
               <div className="text-lg font-black text-slate-900">Babil 👋</div>
             </div>
             <div className="w-10 h-10 rounded-full bg-teal-100 border border-teal-200 flex items-center justify-center overflow-hidden">
                 <img src="https://api.dicebear.com/7.x/avataaars/svg?seed=Babil&backgroundColor=c0aede" alt="avatar" className="w-full h-full object-cover" />
             </div>
           </div>

           {/* Focus Session Widget */}
           <div className="bg-white rounded-2xl p-4 shadow-sm border border-slate-100 flex flex-col items-center justify-center relative overflow-hidden">
             <div className="absolute top-0 right-0 w-24 h-24 bg-teal-500/10 rounded-full blur-xl -mr-10 -mt-10"></div>
             <div className="text-xs font-bold text-slate-400 mb-2">Focus Session</div>
             <div className="text-4xl font-black text-slate-800 mb-1">25:00</div>
             <div className="text-[10px] text-slate-400 mb-4">Pomodoro</div>
             <button className="w-12 h-12 rounded-full bg-teal-500 text-white flex items-center justify-center shadow-lg shadow-teal-500/30 hover:scale-105 transition-transform cursor-default">
               <svg className="w-5 h-5 ml-1" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z" /></svg>
             </button>
           </div>

           {/* Progress */}
           <div className="space-y-2">
             <div className="flex justify-between text-xs font-bold">
               <span className="text-slate-600">Today's Progress</span>
               <span className="text-teal-600">85%</span>
             </div>
             <div className="h-2 w-full bg-slate-200 rounded-full overflow-hidden">
               <div className="h-full bg-teal-500 rounded-full w-[85%]"></div>
             </div>
           </div>

           {/* Stats Row */}
           <div className="grid grid-cols-3 gap-2 mt-2">
             <div className="bg-white p-2 rounded-xl border border-slate-100 text-center">
               <div className="text-[10px] text-slate-400 font-semibold mb-1">Tasks Done</div>
               <div className="font-bold text-slate-800">12</div>
             </div>
             <div className="bg-white p-2 rounded-xl border border-slate-100 text-center">
               <div className="text-[10px] text-slate-400 font-semibold mb-1">Focus Time</div>
               <div className="font-bold text-slate-800">4.2h</div>
             </div>
             <div className="bg-white p-2 rounded-xl border border-slate-100 text-center">
               <div className="text-[10px] text-slate-400 font-semibold mb-1">Streak</div>
               <div className="font-bold text-slate-800 flex items-center justify-center gap-1">7<Flame className="w-3 h-3 text-orange-500" fill="currentColor" /></div>
             </div>
           </div>
           
           {/* Up Next List */}
           <div className="mt-2">
              <div className="text-xs font-bold text-slate-800 mb-2">Up Next</div>
              <div className="bg-white p-3 rounded-xl border border-slate-100 flex items-center gap-3">
                 <div className="w-4 h-4 rounded-full border-2 border-teal-500"></div>
                 <div>
                   <div className="text-sm font-bold text-slate-800">Design landing page</div>
                   <div className="text-[10px] text-slate-400">10:00 AM</div>
                 </div>
              </div>
           </div>

           {/* Mock Bottom Nav */}
           <div className="absolute bottom-0 left-0 right-0 h-16 bg-white border-t border-slate-100 flex items-center justify-around px-4">
              <div className="flex flex-col items-center text-teal-500"><LayoutDashboard className="w-5 h-5" /><div className="text-[8px] font-bold mt-1">Home</div></div>
              <div className="flex flex-col items-center text-slate-400"><Target className="w-5 h-5" /><div className="text-[8px] font-bold mt-1">Tasks</div></div>
              <div className="flex flex-col items-center text-slate-400"><Clock className="w-5 h-5" /><div className="text-[8px] font-bold mt-1">Focus</div></div>
              <div className="flex flex-col items-center text-slate-400"><BarChart3 className="w-5 h-5" /><div className="text-[8px] font-bold mt-1">Analytics</div></div>
           </div>
        </div>
      </motion.div>

      {/* Floating Cards around Mockup */}
      <motion.div 
        animate={{ y: [-10, 10, -10] }}
        transition={{ duration: 6, repeat: Infinity, ease: "easeInOut" }}
        className="absolute top-10 -left-12 z-20 glass-card-light p-4 rounded-2xl flex flex-col items-center shadow-lg w-32"
      >
        <div className="text-xs font-bold text-slate-500 mb-1">Focus Time</div>
        <div className="text-2xl font-black text-slate-900">4.2h</div>
        <div className="text-[10px] text-slate-400 mb-2">Today</div>
        <div className="flex items-end h-8 gap-1 w-full justify-center opacity-60">
           <div className="w-1.5 h-[30%] bg-teal-500 rounded-sm"></div>
           <div className="w-1.5 h-[60%] bg-teal-500 rounded-sm"></div>
           <div className="w-1.5 h-[40%] bg-teal-500 rounded-sm"></div>
           <div className="w-1.5 h-[90%] bg-teal-500 rounded-sm"></div>
           <div className="w-1.5 h-[70%] bg-teal-500 rounded-sm"></div>
        </div>
      </motion.div>

      <motion.div 
        animate={{ y: [10, -10, 10] }}
        transition={{ duration: 5, repeat: Infinity, ease: "easeInOut", delay: 1 }}
        className="absolute top-20 -right-12 z-20 glass-card-light p-4 rounded-2xl flex flex-col items-center shadow-lg w-32"
      >
        <div className="text-xs font-bold text-slate-500 mb-1">Daily Streak</div>
        <div className="flex items-baseline gap-1">
          <span className="text-3xl font-black text-slate-900">7</span>
          <span className="text-xs font-bold text-slate-500">days</span>
        </div>
        <Flame className="w-6 h-6 text-orange-500 mt-2" fill="currentColor" />
      </motion.div>

      <motion.div 
        animate={{ y: [-8, 8, -8] }}
        transition={{ duration: 5.5, repeat: Infinity, ease: "easeInOut", delay: 2 }}
        className="absolute bottom-32 -right-16 z-20 glass-card-light p-4 rounded-2xl shadow-lg w-36"
      >
        <div className="text-xs font-bold text-slate-500 mb-1">Productivity</div>
        <div className="text-xl font-black text-slate-900 mb-1">+32%</div>
        <div className="text-[10px] text-teal-600 font-semibold mb-2">vs yesterday</div>
        <svg viewBox="0 0 100 30" className="w-full h-8 overflow-visible">
          <path d="M0,25 Q15,25 25,15 T50,20 T75,5 T100,0" fill="none" stroke="#14B8A6" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"/>
          <path d="M0,25 Q15,25 25,15 T50,20 T75,5 T100,0 L100,30 L0,30 Z" fill="url(#gradient-teal)" stroke="none" opacity="0.2"/>
          <defs>
            <linearGradient id="gradient-teal" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#14B8A6"/>
              <stop offset="100%" stopColor="transparent"/>
            </linearGradient>
          </defs>
        </svg>
      </motion.div>
    </div>
  );
}
