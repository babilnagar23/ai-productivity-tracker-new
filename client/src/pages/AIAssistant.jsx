import React, { useState } from 'react';
import { apiFetch } from '../services/api';
import Navbar from '../components/Navbar';
import Sidebar from '../components/Sidebar';
import { Sparkles, Send, BrainCircuit, Terminal, ArrowRight } from 'lucide-react';

const AIAssistant = () => {
  const [chatInput, setChatInput] = useState('');
  const [chatLogs, setChatLogs] = useState([
    { role: 'ai', text: 'Operational greeting. I am the Gemini Productivity Engine. How can I augment your schedule today?' }
  ]);
  const [loadingChat, setLoadingChat] = useState(false);
  const [loadingSchedule, setLoadingSchedule] = useState(false);
  const [aiPlan, setAiPlan] = useState('');

  // Handle plan generator
  const handleGeneratePlan = async () => {
    setLoadingSchedule(true);
    try {
      const res = await apiFetch('/ai/generate-plan', { method: 'POST' });
      if (res.success) {
        setAiPlan(res.plan);
      }
    } catch (err) {
      console.error(err);
      setAiPlan('Error generating operational agenda.');
    } finally {
      setLoadingSchedule(false);
    }
  };

  // Handle send message
  const handleSendMessage = async (e) => {
    e.preventDefault();
    if (!chatInput.trim()) return;

    const userMsg = chatInput;
    setChatInput('');
    setChatLogs(prev => [...prev, { role: 'user', text: userMsg }]);
    setLoadingChat(true);

    try {
      const res = await apiFetch('/ai/chat', {
        method: 'POST',
        body: JSON.stringify({
          message: userMsg,
          context: { chatLogs }
        })
      });

      if (res.success) {
        setChatLogs(prev => [...prev, { role: 'ai', text: res.reply }]);
      }
    } catch (err) {
      console.error(err);
      setChatLogs(prev => [...prev, { role: 'ai', text: 'Critical network loss. Unable to resolve response.' }]);
    } finally {
      setLoadingChat(false);
    }
  };

  return (
    <div className="flex bg-background min-h-screen text-white">
      <Sidebar />
      <div className="flex-1 flex flex-col overflow-y-auto">
        <Navbar />

        <main className="p-8 space-y-8 flex-1 grid grid-cols-1 lg:grid-cols-2 gap-8">
          
          {/* Schedule generator */}
          <div className="glass-card p-6 flex flex-col justify-between border border-white/5 space-y-4">
            <div className="space-y-2">
              <div className="flex items-center gap-2 text-gradient">
                <BrainCircuit className="h-5 w-5" />
                <h2 className="text-xl font-bold">Neural Schedule Architect</h2>
              </div>
              <p className="text-xs text-gray-400">
                AI analyzes your 7-day routine submission habits, sleep duration consistency, and logged study hours to forge a personalized productivity calendar strategy.
              </p>
            </div>

            <div className="flex-1 min-h-[300px] bg-white/5 border border-white/5 rounded-2xl p-6 overflow-y-auto text-sm leading-relaxed text-gray-300">
              {loadingSchedule ? (
                <div className="flex items-center justify-center h-full">
                  <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-accent"></div>
                </div>
              ) : aiPlan ? (
                <div className="whitespace-pre-wrap font-sans">{aiPlan}</div>
              ) : (
                <div className="flex flex-col items-center justify-center h-full text-center text-gray-500 space-y-3">
                  <Terminal className="h-10 w-10 text-gray-600 animate-pulse" />
                  <p>Neural planner waiting for instruction matrix.</p>
                </div>
              )}
            </div>

            <button
              onClick={handleGeneratePlan}
              disabled={loadingSchedule}
              className="w-full flex items-center justify-center gap-2 py-4 rounded-xl bg-gradient-to-r from-blue-600 to-purple-600 font-bold text-sm shadow-neon hover:opacity-90 transition-all duration-300 disabled:opacity-50"
            >
              <Sparkles className="h-4 w-4" /> Synthesize Daily & Exam Prep Plan
            </button>
          </div>

          {/* AI Chat Bot */}
          <div className="glass-card p-6 flex flex-col border border-white/5 space-y-4 max-h-[600px]">
            <div className="space-y-1">
              <div className="flex items-center gap-2 text-purple-400">
                <Sparkles className="h-5 w-5" />
                <h2 className="text-xl font-bold">Productivity Mentor</h2>
              </div>
              <p className="text-xs text-gray-400">
                Ask anything about exams, habit streaks, or getting rid of study procrastination.
              </p>
            </div>

            {/* Chat output */}
            <div className="flex-1 bg-white/5 border border-white/5 rounded-2xl p-4 overflow-y-auto space-y-4">
              {chatLogs.map((msg, index) => (
                <div 
                  key={index}
                  className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
                >
                  <div className={`max-w-[80%] rounded-2xl p-4 text-sm leading-relaxed ${
                    msg.role === 'user'
                      ? 'bg-blue-600/20 border border-blue-500/30 text-white rounded-tr-none'
                      : 'bg-white/5 border border-white/5 text-gray-300 rounded-tl-none'
                  }`}>
                    {msg.text}
                  </div>
                </div>
              ))}
              {loadingChat && (
                <div className="flex justify-start">
                  <div className="bg-white/5 border border-white/5 rounded-2xl rounded-tl-none p-4 text-sm text-gray-500 flex items-center gap-2">
                    <div className="w-1.5 h-1.5 bg-gray-500 rounded-full animate-bounce"></div>
                    <div className="w-1.5 h-1.5 bg-gray-500 rounded-full animate-bounce [animation-delay:0.2s]"></div>
                    <div className="w-1.5 h-1.5 bg-gray-500 rounded-full animate-bounce [animation-delay:0.4s]"></div>
                  </div>
                </div>
              )}
            </div>

            {/* Input field */}
            <form onSubmit={handleSendMessage} className="flex gap-2">
              <input
                type="text"
                required
                value={chatInput}
                onChange={(e) => setChatInput(e.target.value)}
                placeholder="Ask about productivity strategies..."
                className="flex-1 px-4 py-3 bg-white/5 border border-white/5 rounded-xl text-white placeholder-gray-500 text-sm focus:outline-none focus:border-blue-500 transition-all"
              />
              <button
                type="submit"
                disabled={loadingChat}
                className="p-3 bg-blue-600 hover:bg-blue-700 rounded-xl transition-all shadow-neon flex items-center justify-center disabled:opacity-50"
              >
                <Send className="h-5 w-5" />
              </button>
            </form>

          </div>

        </main>
      </div>
    </div>
  );
};

export default AIAssistant;
