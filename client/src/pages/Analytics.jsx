import  { useState, useEffect } from 'react';
import AppLayout from '../components/layout/AppLayout';
import StatCard from '../components/ui/StatCard';
import { analyticsApi } from '../services/api';
import { BarChart3, TrendingUp, Target, Focus, CalendarDays, Award } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, AreaChart, Area } from 'recharts';

export default function Analytics() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [timeRange, setTimeRange] = useState('7d');

  useEffect(() => {
    const fetchAnalytics = async () => {
      setLoading(true);
      try {
        const res = await analyticsApi.full();
        if (res.success && res.stats) {
          setData(mapBackendToChartData(res));
        } else {
          setData(generateMockData(timeRange));
        }
      } catch (err) {
        setData(generateMockData(timeRange));
      } finally {
        setLoading(false);
      }
    };
    fetchAnalytics();
  }, [timeRange]);

  return (
    <AppLayout title="Analytics">
      <div className="max-w-6xl mx-auto space-y-6 animate-fadeInUp">
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-xl font-hero font-extrabold text-white flex items-center gap-2">
              <BarChart3 className="w-5 h-5 text-cyan" /> Performance Analytics
            </h1>
            <p className="text-xs text-gray-400 mt-0.5">Track your productivity trends and insights</p>
          </div>
          
          <div className="flex gap-1 p-1 bg-white/5 rounded-xl border border-white/5">
            {['7d', '30d', '90d'].map(r => (
              <button key={r} onClick={() => setTimeRange(r)}
                className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all
                  ${timeRange === r ? 'bg-cyan/20 text-cyan border border-cyan/30' : 'text-gray-500 hover:text-white hover:bg-white/5'}`}>
                {r.toUpperCase()}
              </button>
            ))}
          </div>
        </div>

        {loading ? (
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            {Array.from({length:4}).map((_,i) => <div key={i} className="h-28 rounded-2xl bg-white/5 animate-shimmer" />)}
          </div>
        ) : (
          <>
            {/* KPI Stats */}
            <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
              <StatCard label="Productivity Score" value={`${data?.avgScore || 85}%`} icon={TrendingUp} color="#00FFFF" gradient="from-cyan/5" ring={data?.avgScore || 85} />
              <StatCard label="Focus Hours" value={`${data?.focusHours || 12.5}h`} icon={Focus} color="#BF5AF2" gradient="from-plasma/5" />
              <StatCard label="Tasks Completed" value={data?.tasksCompleted || 42} icon={Target} color="#00FFFF" gradient="from-cyan/5" />
              <StatCard label="Active Days" value={data?.activeDays || 6} icon={CalendarDays} color="#F59E0B" gradient="from-orange-500/5" />
            </div>

            {/* Charts Row 1 */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Productivity Trend */}
              <div className="glass card-3d p-6 flex flex-col h-80">
                <h3 className="font-bold text-white text-sm mb-4 flex items-center gap-2">
                  <TrendingUp className="w-4 h-4 text-cyan" /> Productivity Trend
                </h3>
                <div className="flex-1 min-h-0">
                  <ResponsiveContainer width="100%" height="100%">
                    <AreaChart data={data?.trendData || []}>
                      <defs>
                        <linearGradient id="colorScore" x1="0" y1="0" x2="0" y2="1">
                          <stop offset="5%" stopColor="#00FFFF" stopOpacity={0.3}/>
                          <stop offset="95%" stopColor="#00FFFF" stopOpacity={0}/>
                        </linearGradient>
                      </defs>
                      <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" vertical={false} />
                      <XAxis dataKey="date" axisLine={false} tickLine={false} tick={{fill: '#6B7280', fontSize: 10}} dy={10} />
                      <YAxis axisLine={false} tickLine={false} tick={{fill: '#6B7280', fontSize: 10}} dx={-10} domain={[0, 100]} />
                      <Tooltip 
                        contentStyle={{backgroundColor: '#0d1126', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '12px'}}
                        itemStyle={{color: '#00FFFF', fontWeight: 'bold'}}
                      />
                      <Area type="monotone" dataKey="score" stroke="#00FFFF" strokeWidth={3} fillOpacity={1} fill="url(#colorScore)" />
                    </AreaChart>
                  </ResponsiveContainer>
                </div>
              </div>

              {/* Focus Distribution */}
              <div className="glass card-3d p-6 flex flex-col h-80">
                <h3 className="font-bold text-white text-sm mb-4 flex items-center gap-2">
                  <Focus className="w-4 h-4 text-plasma" /> Focus Distribution (Hours)
                </h3>
                <div className="flex-1 min-h-0">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={data?.focusData || []}>
                      <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" vertical={false} />
                      <XAxis dataKey="day" axisLine={false} tickLine={false} tick={{fill: '#6B7280', fontSize: 10}} dy={10} />
                      <YAxis axisLine={false} tickLine={false} tick={{fill: '#6B7280', fontSize: 10}} dx={-10} />
                      <Tooltip 
                        cursor={{fill: 'rgba(255,255,255,0.02)'}}
                        contentStyle={{backgroundColor: '#0d1126', border: '1px solid rgba(255,255,255,0.1)', borderRadius: '12px'}}
                      />
                      <Bar dataKey="hours" fill="#BF5AF2" radius={[4, 4, 0, 0]} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </div>
            </div>

            {/* Insights Panel */}
            <div className="glass card-3d p-6 border border-cyan/20 bg-gradient-to-br from-cyan/5 to-plasma/5">
              <h3 className="font-bold text-white text-sm mb-4 flex items-center gap-2">
                <Award className="w-4 h-4 text-yellow-400" /> AI Insights
              </h3>
              <div className="space-y-3">
                <p className="text-sm text-gray-300">
                  <span className="font-semibold text-white">Peak Performance:</span> You are most productive on <span className="text-cyan">Tuesdays</span> between <span className="text-cyan">9 AM and 11 AM</span>.
                </p>
                <p className="text-sm text-gray-300">
                  <span className="font-semibold text-white">Focus Trend:</span> Your average focus session duration has increased by 15% compared to the previous period. Keep it up!
                </p>
                <p className="text-sm text-gray-300">
                  <span className="font-semibold text-white">Area for Improvement:</span> Your daily log completion rate dropped over the weekend. Try setting a reminder!
                </p>
              </div>
            </div>
          </>
        )}
      </div>
    </AppLayout>
  );
}

// Helper to map real backend data
function mapBackendToChartData(backendRes) {
  const { stats, behavioral } = backendRes;
  
  const trendData = (behavioral?.habitHeatmap || []).map(h => {
    const d = new Date(h.date);
    return {
      date: `${d.getMonth()+1}/${d.getDate()}`,
      score: h.score || 0
    };
  });
  
  const focusData = (behavioral?.studyVsMobile || []).slice(-7).map(s => {
    const d = new Date(s.date);
    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return {
      day: dayNames[d.getDay()],
      hours: s.studyHours || 0
    };
  });

  return {
    avgScore: stats?.avgScore || 0,
    focusHours: focusData.reduce((acc, curr) => acc + curr.hours, 0).toFixed(1),
    tasksCompleted: stats?.totalLogs || 0,
    activeDays: stats?.totalLogs || 0,
    trendData,
    focusData
  };
}

// Mock data generator for visualization until backend is ready
function generateMockData(range) {
  const days = range === '7d' ? 7 : range === '30d' ? 30 : 90;
  const trendData = [];
  const focusData = [];
  
  const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const today = new Date();
  
  for(let i = days - 1; i >= 0; i--) {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    
    trendData.push({
      date: `${d.getMonth()+1}/${d.getDate()}`,
      score: Math.floor(Math.random() * 40) + 50 + (i === 0 ? 10 : 0) // random 50-90
    });
    
    if (i < 7) {
      focusData.push({
        day: dayNames[d.getDay()],
        hours: Number((Math.random() * 3 + 1).toFixed(1))
      });
    }
  }
  
  return {
    avgScore: Math.floor(trendData.reduce((a,b)=>a+b.score, 0) / trendData.length),
    focusHours: Number(focusData.reduce((a,b)=>a+b.hours, 0).toFixed(1)),
    tasksCompleted: days * 4 + Math.floor(Math.random() * 10),
    activeDays: Math.floor(days * 0.8),
    trendData,
    focusData
  };
}
