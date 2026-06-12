import React, { useState, useEffect, useRef, useCallback } from 'react';
import AppLayout from '../components/layout/AppLayout';
import Button from '../components/ui/Button';
import { aiApi } from '../services/api';
import { Sparkles, Send, RotateCcw, ChevronRight } from 'lucide-react';

const SUGGESTED_PROMPTS = [
  "How can I improve my study focus?",
  "Create a productivity routine for me",
  "Analyze my habits and give advice",
  "What's the best Pomodoro strategy?",
  "How do I beat procrastination?",
  "Give me a weekly study plan",
];

function Message({ msg }) {
  const isUser = msg.role === 'user';
  return (
    <div className={`flex items-end gap-3 ${isUser ? 'flex-row-reverse' : ''} animate-fadeInUp`}>
      {/* Avatar */}
      <div className={`w-7 h-7 rounded-full flex items-center justify-center flex-shrink-0 text-xs font-bold
        ${isUser ? 'bg-cyan text-black' : 'bg-plasma/20 border border-plasma/30'}`}>
        {isUser ? 'U' : <Sparkles className="w-3.5 h-3.5 text-plasma" />}
      </div>

      {/* Bubble */}
      <div className={`max-w-[80%] px-4 py-3 rounded-2xl text-sm leading-relaxed
        ${isUser
          ? 'bg-cyan/20 border border-cyan/20 text-white rounded-br-sm'
          : 'glass text-gray-200 rounded-bl-sm'
        }`}>
        {msg.content}
      </div>
    </div>
  );
}

function TypingIndicator() {
  return (
    <div className="flex items-end gap-3 animate-fadeIn">
      <div className="w-7 h-7 rounded-full bg-plasma/20 border border-plasma/30 flex items-center justify-center flex-shrink-0">
        <Sparkles className="w-3.5 h-3.5 text-plasma" />
      </div>
      <div className="glass px-4 py-3 rounded-2xl rounded-bl-sm">
        <div className="flex items-center gap-1.5">
          <div className="w-1.5 h-1.5 rounded-full bg-gray-400 typing-dot" />
          <div className="w-1.5 h-1.5 rounded-full bg-gray-400 typing-dot" />
          <div className="w-1.5 h-1.5 rounded-full bg-gray-400 typing-dot" />
        </div>
      </div>
    </div>
  );
}

export default function AIAssistant() {
  const [messages, setMessages] = useState([
    { role: 'assistant', content: "Hi! I'm your AI productivity coach. I can help you build better habits, optimize your study schedule, and boost your focus. What would you like to work on today?" }
  ]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const bottomRef = useRef(null);
  const inputRef = useRef(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, loading]);

  const sendMessage = async (text) => {
    const msg = text.trim();
    if (!msg || loading) return;
    setInput('');
    setMessages(prev => [...prev, { role: 'user', content: msg }]);
    setLoading(true);
    try {
      const history = messages.map(m => ({ role: m.role, content: m.content }));
      const res = await aiApi.chat(msg, history);
      const reply = res?.data || res?.reply || res?.message || res || 'I\'m here to help!';
      setMessages(prev => [...prev, { role: 'assistant', content: reply }]);
    } catch {
      setMessages(prev => [...prev, { role: 'assistant', content: 'Sorry, I\'m having trouble connecting. Please try again.' }]);
    } finally {
      setLoading(false);
      inputRef.current?.focus();
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    sendMessage(input);
  };

  const clearChat = () => setMessages([{
    role: 'assistant',
    content: "Chat cleared! How can I help you today?"
  }]);

  return (
    <AppLayout title="AI Assistant">
      <div className="max-w-3xl mx-auto h-[calc(100vh-8rem)] flex flex-col gap-4 animate-fadeInUp">
        {/* Header */}
        <div className="flex items-center justify-between flex-shrink-0">
          <div>
            <h1 className="text-xl font-hero font-extrabold text-white flex items-center gap-2">
              <Sparkles className="w-5 h-5 text-plasma animate-pulse" /> AI Coach
            </h1>
            <p className="text-xs text-gray-400 mt-0.5">Powered by AI · Personalized productivity guidance</p>
          </div>
          <Button variant="ghost" size="sm" icon={RotateCcw} onClick={clearChat}>Clear</Button>
        </div>

        {/* Chat area */}
        <div className="flex-1 glass card-3d p-4 overflow-y-auto space-y-4 min-h-0">
          {messages.map((m, i) => <Message key={i} msg={m} />)}
          {loading && <TypingIndicator />}
          <div ref={bottomRef} />
        </div>

        {/* Suggested prompts */}
        {messages.length <= 1 && (
          <div className="flex gap-2 flex-wrap flex-shrink-0">
            {SUGGESTED_PROMPTS.map(p => (
              <button
                key={p}
                onClick={() => sendMessage(p)}
                className="px-3 py-2 rounded-xl bg-white/4 border border-white/8 text-xs text-gray-400 hover:text-white hover:bg-white/8 hover:border-cyan/20 transition-all flex items-center gap-1.5"
              >
                <ChevronRight className="w-3 h-3 text-cyan" /> {p}
              </button>
            ))}
          </div>
        )}

        {/* Input */}
        <form onSubmit={handleSubmit} className="flex gap-3 flex-shrink-0">
          <div className="flex-1 flex items-center gap-2 px-4 py-3 glass card-3d border border-white/8 rounded-xl focus-within:border-cyan/40 transition-colors">
            <input
              ref={inputRef}
              className="flex-1 bg-transparent text-sm text-white placeholder-gray-500 outline-none"
              placeholder="Ask your AI coach anything..."
              value={input}
              onChange={e => setInput(e.target.value)}
              disabled={loading}
            />
          </div>
          <Button
            type="submit"
            icon={Send}
            loading={loading}
            disabled={!input.trim()}
            className="px-4 py-3"
          >
            Send
          </Button>
        </form>
      </div>
    </AppLayout>
  );
}
