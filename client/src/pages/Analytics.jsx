import React, { useState, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiFetch } from '../services/api';
import { useAuth } from '../context/AuthContext';
import Navbar from '../components/Navbar';
import Sidebar from '../components/Sidebar';
import {
  AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer,
  BarChart, Bar, LineChart, Line, Legend, CartesianGrid
} from 'recharts';
import {
  BarChart3, TrendingUp, Sparkles, Calendar, Target,
  Award, Activity, Edit2, ChevronUp, ChevronDown,
  CheckCircle2, XCircle, Clock, Smartphone, BookOpen,
  RefreshCw, Layers
} from 'lucide-react';

/* ─────────── helpers ─────────── */
const fmt = (dateStr) =>
  new Date(dateStr).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });

const fmtFull = (dateStr) =>
  new Date(dateStr).toLocaleDateString(undefined, {
    weekday: 'short', month: 'short', day: 'numeric', year: 'numeric'
  });

const scoreColor = (s) => {
  if (s >= 80) return 'text-green-400';
  if (s >= 50) return 'text-yellow-400';
  return 'text-red-400';
};

const scoreBg = (s) => {
  if (s >= 80) return 'bg-green-500/8 border-green-500/10';
  if (s >= 50) return 'bg-yellow-500/8 border-yellow-500/10';
  return 'bg-red-500/8 border-red-500/10';
};

/* ─────────── Stat Card ─────────── */
const StatCard = ({ icon: Icon, label, value, sub, color }) => (
  <div className={`glass-card p-5 flex items-center gap-4 border ${color}`}>
    <div className={`p-3 rounded-2xl bg-white/5`}>
      <Icon className="h-5 w-5 text-white/60" />
    </div>
    <div>
      <p className="text-xs text-gray-400 uppercase tracking-wider font-bold">{label}</p>
      <p className="text-2xl font-extrabold text-white leading-tight">{value}</p>
      {sub && <p className="text-[10px] text-gray-500 mt-0.5">{sub}</p>}
    </div>
  </div>
);

/* ─────────── Chart Tooltip ─────────── */
const ChartTooltipStyle = {
  backgroundColor: '#0d1126',
  borderColor: 'rgba(255,255,255,0.08)',
  borderRadius: '12px',
  fontSize: '11px',
  color: '#e5e7eb'
};

/* ─────────── MAIN COMPONENT ─────────── */
const Analytics = () => {
  const { user } = useAuth();
  const navigate = useNavigate();

  const [fullData, setFullData] = useState(null);
  const [chartData, setChartData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [sortField, setSortField] = useState('date');
  const [sortDir, setSortDir] = useState('desc');
  const [activeTab, setActiveTab] = useState('table'); // 'table' | 'charts'

  /* Live config comes from AuthContext (updates when user edits Customization) */
  const config = user?.customConfig || {
    coreChecklists: [
      { id: 'study', title: 'Study', description: 'Core study session' },
      { id: 'exercise', title: 'Exercise', description: 'Workout routine' },
      { id: 'ml', title: 'AI/ML', description: 'Dev & learning' }
    ],
    coreMetrics: [
      { id: 'studyHours', title: 'Study Hrs' },
      { id: 'mobileUsage', title: 'Mobile Hrs' }
    ]
  };

  const fetchData = useCallback(async () => {
    setLoading(true);
    try {
      const [fullRes, weeklyRes] = await Promise.all([
        apiFetch('/analytics/full'),
        apiFetch('/analytics/weekly')
      ]);

      if (fullRes.success) setFullData(fullRes);

      if (weeklyRes.success) {
        setChartData(weeklyRes.data.map(item => {
          const mapped = {
            ...item,
            formattedDate: fmt(item.date),
            studyHours: item.studyHours || item.coreMetrics?.studyHours || 0,
            mobileUsage: item.mobileUsage || item.coreMetrics?.mobileUsage || 0,
          };
          if (item.coreMetrics) {
            Object.entries(item.coreMetrics).forEach(([key, val]) => {
              mapped[key] = Number(val) || 0;
            });
          }
          return mapped;
        }));
      }
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchData(); }, [fetchData]);

  /* Sort the table rows */
  const sortedRows = fullData?.data
    ? [...fullData.data].sort((a, b) => {
        let aVal = a[sortField];
        let bVal = b[sortField];
        if (sortField === 'date') {
          aVal = new Date(aVal);
          bVal = new Date(bVal);
        }
        if (aVal < bVal) return sortDir === 'asc' ? -1 : 1;
        if (aVal > bVal) return sortDir === 'asc' ? 1 : -1;
        return 0;
      })
    : [];

  const handleSort = (field) => {
    if (sortField === field) setSortDir(d => d === 'asc' ? 'desc' : 'asc');
    else { setSortField(field); setSortDir('desc'); }
  };

  const SortIcon = ({ field }) =>
    sortField === field
      ? (sortDir === 'asc' ? <ChevronUp className="h-3 w-3 inline ml-0.5" /> : <ChevronDown className="h-3 w-3 inline ml-0.5" />)
      : null;

  const stats = fullData?.stats;

  /* ── Top summary stats derived from live config ── */
  const topChecklistRate = stats?.checklistRates
    ? Object.values(stats.checklistRates).sort((a, b) => b.rate - a.rate)[0]
    : null;

  return (
    <div className="flex bg-background min-h-screen text-white">
      <Sidebar />
      <div className="flex-1 flex flex-col overflow-y-auto">
        <Navbar />

        <main className="p-6 lg:p-8 space-y-8 flex-1">

          {/* ── Page Header ── */}
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div>
              <h1 className="text-3xl font-extrabold tracking-tight">Analytics Report</h1>
              <p className="text-sm text-gray-400 mt-1">
                Linked live to your daily logs and customization settings.
              </p>
            </div>
            <div className="flex items-center gap-3">
              <button
                onClick={fetchData}
                className="flex items-center gap-1.5 px-4 py-2.5 rounded-xl bg-white/5 border border-white/10 text-xs font-semibold text-gray-300 hover:bg-white/10 transition"
              >
                <RefreshCw className="h-3.5 w-3.5" /> Refresh
              </button>
              {/* Tab switcher */}
              <div className="flex items-center bg-white/5 border border-white/10 rounded-xl p-1">
                {[['table', 'Report Table'], ['charts', 'Charts']].map(([key, label]) => (
                  <button
                    key={key}
                    onClick={() => setActiveTab(key)}
                    className={`px-4 py-1.5 rounded-lg text-xs font-bold transition-all ${
                      activeTab === key
                        ? 'bg-gradient-to-r from-blue-600 to-purple-600 text-white shadow-neon'
                        : 'text-gray-400 hover:text-white'
                    }`}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </div>
          </div>

          {loading ? (
            <div className="flex flex-col items-center justify-center py-24 gap-4">
              <div className="h-10 w-10 rounded-full border-2 border-blue-500 border-t-transparent animate-spin" />
              <p className="text-gray-400 text-sm">Loading analytics data...</p>
            </div>
          ) : (
            <>
              {/* ── Summary Stats Cards ── */}
              <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
                <StatCard
                  icon={Calendar}
                  label="Days Logged"
                  value={stats?.totalLogs ?? 0}
                  sub="Total entries recorded"
                  color="border-white/5"
                />
                <StatCard
                  icon={Target}
                  label="Avg Score"
                  value={`${stats?.avgScore ?? 0}%`}
                  sub="Mean productivity index"
                  color="border-blue-500/10"
                />
                <StatCard
                  icon={Award}
                  label="Peak Score"
                  value={`${stats?.bestScore ?? 0}%`}
                  sub="Personal best day"
                  color="border-purple-500/10"
                />
                <StatCard
                  icon={CheckCircle2}
                  label="Top Habit"
                  value={topChecklistRate ? `${topChecklistRate.rate}%` : 'N/A'}
                  sub={topChecklistRate ? topChecklistRate.title : 'No data'}
                  color="border-green-500/10"
                />
              </div>

              {/* ── Checklist Completion Rate Bars ── */}
              {config.coreChecklists.length > 0 && stats?.checklistRates && (
                <div className="glass-card p-6 border border-white/5 space-y-4">
                  <div className="flex items-center gap-2 mb-2">
                    <Layers className="h-4 w-4 text-blue-400" />
                    <h3 className="font-bold text-sm text-gray-300 uppercase tracking-wider">
                      Habit Completion Rates
                    </h3>
                  </div>
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                    {config.coreChecklists.map((chk) => {
                      const rate = stats.checklistRates[chk.id];
                      const pct = rate?.rate ?? 0;
                      return (
                        <div key={chk.id} className="space-y-2">
                          <div className="flex justify-between items-center">
                            <span className="text-xs font-semibold text-gray-300">{chk.title}</span>
                            <span className={`text-xs font-bold ${scoreColor(pct)}`}>{pct}%</span>
                          </div>
                          <div className="h-2 w-full bg-white/5 rounded-full overflow-hidden">
                            <div
                              className={`h-full rounded-full transition-all duration-700 ${
                                pct >= 80 ? 'bg-green-500' : pct >= 50 ? 'bg-yellow-500' : 'bg-red-500'
                              }`}
                              style={{ width: `${pct}%` }}
                            />
                          </div>
                          <p className="text-[10px] text-gray-500">
                            {rate?.completed ?? 0} / {rate?.total ?? 0} days
                          </p>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}

              {/* ══════════════ REPORT TABLE TAB ══════════════ */}
              {activeTab === 'table' && (
                <div className="glass-card border border-white/5 overflow-hidden">
                  <div className="p-5 border-b border-white/5 flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <BarChart3 className="h-4 w-4 text-blue-400" />
                      <h3 className="font-bold text-sm text-white uppercase tracking-wider">
                        Daily Log Analysis Report
                      </h3>
                    </div>
                    <span className="text-[10px] bg-blue-500/10 text-blue-400 px-2.5 py-1 rounded-full font-bold border border-blue-500/20">
                      {sortedRows.length} entries
                    </span>
                  </div>

                  {sortedRows.length === 0 ? (
                    <div className="py-16 text-center text-gray-500">
                      <Calendar className="h-10 w-10 mx-auto mb-3 opacity-30" />
                      <p className="text-sm">No log entries found.</p>
                      <p className="text-xs mt-1">Start logging in the Daily Routines section.</p>
                    </div>
                  ) : (
                    <div className="overflow-x-auto">
                      <table className="w-full text-xs">
                        <thead>
                          <tr className="bg-white/3 border-b border-white/5">
                            {/* Date */}
                            <th
                              className="text-left px-4 py-3 font-bold text-gray-400 uppercase tracking-wider cursor-pointer hover:text-white transition whitespace-nowrap sticky left-0 bg-[#0d1126] z-10"
                              onClick={() => handleSort('date')}
                            >
                              Date <SortIcon field="date" />
                            </th>

                            {/* Core Checklist columns — dynamic from customConfig */}
                            {config.coreChecklists.map((chk) => (
                              <th
                                key={chk.id}
                                className="px-4 py-3 font-bold text-gray-400 uppercase tracking-wider text-center whitespace-nowrap"
                                title={chk.description}
                              >
                                {chk.title}
                              </th>
                            ))}

                            {/* Core Metric columns — dynamic from customConfig */}
                            {config.coreMetrics.map((met) => (
                              <th
                                key={met.id}
                                className="px-4 py-3 font-bold text-gray-400 uppercase tracking-wider text-center whitespace-nowrap"
                              >
                                {met.title}
                              </th>
                            ))}

                            {/* Fixed columns */}
                            <th className="px-4 py-3 font-bold text-gray-400 uppercase tracking-wider text-center whitespace-nowrap">
                              Sleep
                            </th>
                            <th className="px-4 py-3 font-bold text-gray-400 uppercase tracking-wider text-center whitespace-nowrap">
                              Wake
                            </th>
                            <th className="px-4 py-3 font-bold text-gray-400 uppercase tracking-wider text-center whitespace-nowrap">
                              Custom Logs
                            </th>
                            <th
                              className="px-4 py-3 font-bold text-gray-400 uppercase tracking-wider text-center whitespace-nowrap cursor-pointer hover:text-white transition"
                              onClick={() => handleSort('productivityScore')}
                            >
                              Score <SortIcon field="productivityScore" />
                            </th>
                            <th className="px-4 py-3 font-bold text-gray-400 uppercase tracking-wider text-center whitespace-nowrap">
                              Actions
                            </th>
                          </tr>
                        </thead>
                        <tbody>
                          {sortedRows.map((row, i) => {
                            const score = row.productivityScore ?? 0;
                            return (
                              <tr
                                key={row.id || row._id || i}
                                className={`border-b border-white/5 hover:bg-white/4 transition-colors ${
                                  i % 2 === 0 ? 'bg-transparent' : 'bg-white/2'
                                }`}
                              >
                                {/* Date cell */}
                                <td className="px-4 py-3 font-semibold text-gray-200 whitespace-nowrap sticky left-0 bg-[#0d1126] z-10">
                                  <div>{fmt(row.date)}</div>
                                  <div className="text-[9px] text-gray-500 font-normal">
                                    {new Date(row.date).toLocaleDateString(undefined, { weekday: 'short' })}
                                  </div>
                                </td>

                                {/* Core Checklist cells — dynamic */}
                                {config.coreChecklists.map((chk) => {
                                   let done = row.coreChecklists?.[chk.id];
                                   if (done === undefined) {
                                     if (chk.id === 'study') done = row.studyCompleted;
                                     else if (chk.id === 'exercise') done = row.exerciseCompleted;
                                     else if (chk.id === 'ml') done = row.mlCompleted;
                                   }
                                   return (
                                     <td key={chk.id} className="px-4 py-3 text-center">
                                       {done
                                         ? <CheckCircle2 className="h-4 w-4 text-green-400 mx-auto" />
                                         : <XCircle className="h-4 w-4 text-gray-600 mx-auto" />
                                       }
                                     </td>
                                   );
                                 })}

                                {/* Core Metric cells — dynamic */}
                                {config.coreMetrics.map((met) => {
                                   let val = row.coreMetrics?.[met.id];
                                   if (val === undefined) {
                                     if (met.id === 'studyHours') val = row.studyHours;
                                     else if (met.id === 'mobileUsage') val = row.mobileUsage;
                                   }
                                   return (
                                     <td key={met.id} className="px-4 py-3 text-center font-mono font-semibold text-gray-200">
                                       {val ?? 0}
                                     </td>
                                   );
                                 })}

                                {/* Sleep */}
                                <td className="px-4 py-3 text-center text-gray-300 font-mono">
                                  {row.sleepTime || '—'}
                                </td>

                                {/* Wake */}
                                <td className="px-4 py-3 text-center text-gray-300 font-mono">
                                  {row.wakeTime || '—'}
                                </td>

                                {/* Custom Logs */}
                                <td className="px-4 py-3 text-center">
                                  {row.customLogs && row.customLogs.length > 0 ? (
                                    <div className="flex flex-wrap gap-1 justify-center max-w-[200px] mx-auto">
                                      {row.customLogs.map((log, li) => (
                                        <span
                                          key={li}
                                          title={log.title}
                                          className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-medium ${
                                            log.completed
                                              ? 'bg-blue-500/15 text-blue-300 border border-blue-500/20'
                                              : 'bg-white/5 text-gray-500 border border-white/5'
                                          }`}
                                        >
                                          {log.completed ? '✓' : '✗'}{' '}
                                          {log.title.length > 12 ? log.title.slice(0, 12) + '…' : log.title}
                                        </span>
                                      ))}
                                    </div>
                                  ) : (
                                    <span className="text-gray-600">—</span>
                                  )}
                                </td>

                                {/* Productivity Score */}
                                <td className="px-4 py-3 text-center">
                                  <span className={`inline-flex items-center justify-center w-12 h-7 rounded-lg text-xs font-black border ${
                                    score >= 80
                                      ? 'bg-green-500/10 text-green-400 border-green-500/20'
                                      : score >= 50
                                        ? 'bg-yellow-500/10 text-yellow-400 border-yellow-500/20'
                                        : 'bg-red-500/10 text-red-400 border-red-500/20'
                                  }`}>
                                    {score}%
                                  </span>
                                </td>

                                {/* Edit action */}
                                <td className="px-4 py-3 text-center">
                                  <button
                                    onClick={() => navigate('/routines', { state: { editId: row.id || row._id } })}
                                    className="inline-flex items-center gap-1 px-2.5 py-1.5 rounded-lg bg-blue-500/10 border border-blue-500/20 text-blue-400 text-[10px] font-bold hover:bg-blue-500/20 transition"
                                  >
                                    <Edit2 className="h-3 w-3" /> Edit
                                  </button>
                                </td>
                              </tr>
                            );
                          })}
                        </tbody>
                      </table>
                    </div>
                  )}
                </div>
              )}

              {/* ══════════════ CHARTS TAB ══════════════ */}
              {activeTab === 'charts' && (() => {
                const primaryMetric = config.coreMetrics?.find(m => m.id === 'studyHours') || config.coreMetrics?.[0] || { id: 'studyHours', title: 'Study Hrs' };
                const comparedMetrics = config.coreMetrics?.slice(0, 3) || [];
                const lineColors = ['#3B82F6', '#EF4444', '#10B981', '#F59E0B'];

                return chartData.length === 0 ? (
                  <div className="text-center py-12 text-gray-400 bg-white/5 border border-white/5 rounded-2xl">
                    No chart data. Log at least 3 daily entries to generate dynamic charts.
                  </div>
                ) : (
                  <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">

                    {/* Primary Metric Trend */}
                    <div className="glass-card p-6 border border-white/5 space-y-4">
                      <div className="flex justify-between items-center">
                        <h3 className="font-bold text-sm text-gray-400 uppercase tracking-wider">{primaryMetric.title} Log</h3>
                        <TrendingUp className="h-4 w-4 text-blue-400" />
                      </div>
                      <div className="h-[250px] w-full">
                        <ResponsiveContainer width="100%" height="100%">
                          <AreaChart data={chartData}>
                            <defs>
                              <linearGradient id="studyGrad" x1="0" y1="0" x2="0" y2="1">
                                <stop offset="5%" stopColor="#3B82F6" stopOpacity={0.4} />
                                <stop offset="95%" stopColor="#3B82F6" stopOpacity={0} />
                              </linearGradient>
                            </defs>
                            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
                            <XAxis dataKey="formattedDate" stroke="#6B7280" fontSize={11} tickLine={false} />
                            <YAxis stroke="#6B7280" fontSize={11} tickLine={false} />
                            <Tooltip contentStyle={ChartTooltipStyle} />
                            <Area type="monotone" dataKey={primaryMetric.id} stroke="#3B82F6" strokeWidth={2.5} fillOpacity={1} fill="url(#studyGrad)" name={primaryMetric.title} />
                          </AreaChart>
                        </ResponsiveContainer>
                      </div>
                    </div>

                    {/* Productivity Score Trend */}
                    <div className="glass-card p-6 border border-white/5 space-y-4">
                      <div className="flex justify-between items-center">
                        <h3 className="font-bold text-sm text-gray-400 uppercase tracking-wider">Productivity Score Index</h3>
                        <BarChart3 className="h-4 w-4 text-green-400" />
                      </div>
                      <div className="h-[250px] w-full">
                        <ResponsiveContainer width="100%" height="100%">
                          <AreaChart data={chartData}>
                            <defs>
                              <linearGradient id="prodGrad" x1="0" y1="0" x2="0" y2="1">
                                <stop offset="5%" stopColor="#10B981" stopOpacity={0.4} />
                                <stop offset="95%" stopColor="#10B981" stopOpacity={0} />
                              </linearGradient>
                            </defs>
                            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
                            <XAxis dataKey="formattedDate" stroke="#6B7280" fontSize={11} tickLine={false} />
                            <YAxis stroke="#6B7280" fontSize={11} tickLine={false} domain={[0, 100]} />
                            <Tooltip contentStyle={ChartTooltipStyle} formatter={(v) => `${v}%`} />
                            <Area type="monotone" dataKey="productivityScore" stroke="#10B981" strokeWidth={2.5} fillOpacity={1} fill="url(#prodGrad)" name="Score %" />
                          </AreaChart>
                        </ResponsiveContainer>
                      </div>
                    </div>

                    {/* Dynamic Metric Comparison */}
                    <div className="glass-card p-6 border border-white/5 space-y-4 lg:col-span-2">
                      <div className="flex justify-between items-center">
                        <h3 className="font-bold text-sm text-gray-400 uppercase tracking-wider">Metrics Focus Comparison</h3>
                        <Sparkles className="h-4 w-4 text-purple-400" />
                      </div>
                      <div className="h-[300px] w-full">
                        <ResponsiveContainer width="100%" height="100%">
                          <LineChart data={chartData}>
                            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
                            <XAxis dataKey="formattedDate" stroke="#6B7280" fontSize={11} tickLine={false} />
                            <YAxis stroke="#6B7280" fontSize={11} tickLine={false} />
                            <Tooltip contentStyle={ChartTooltipStyle} />
                            <Legend wrapperStyle={{ fontSize: 12, paddingTop: 10 }} />
                            {comparedMetrics.map((met, idx) => (
                              <Line
                                key={met.id}
                                type="monotone"
                                dataKey={met.id}
                                stroke={lineColors[idx % lineColors.length]}
                                strokeWidth={2.5}
                                name={met.title}
                                dot={{ r: 3, fill: lineColors[idx % lineColors.length] }}
                              />
                            ))}
                          </LineChart>
                        </ResponsiveContainer>
                      </div>
                    </div>

                    {/* Checklist completion Bar Chart */}
                    {config.coreChecklists.length > 0 && stats?.checklistRates && (
                      <div className="glass-card p-6 border border-white/5 space-y-4 lg:col-span-2">
                        <div className="flex justify-between items-center">
                          <h3 className="font-bold text-sm text-gray-400 uppercase tracking-wider">Habit Completion Breakdown</h3>
                          <Activity className="h-4 w-4 text-orange-400" />
                        </div>
                        <div className="h-[250px] w-full">
                          <ResponsiveContainer width="100%" height="100%">
                            <BarChart
                              data={config.coreChecklists.map(chk => ({
                                      name: chk.title,
                                      rate: stats.checklistRates[chk.id]?.rate ?? 0,
                                      completed: stats.checklistRates[chk.id]?.completed ?? 0,
                                      total: stats.checklistRates[chk.id]?.total ?? 0,
                                    }))}
                              barSize={36}
                            >
                              <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
                              <XAxis dataKey="name" stroke="#6B7280" fontSize={11} tickLine={false} />
                              <YAxis stroke="#6B7280" fontSize={11} tickLine={false} domain={[0, 100]} unit="%" />
                              <Tooltip contentStyle={ChartTooltipStyle} formatter={(v) => `${v}%`} />
                              <Bar dataKey="rate" name="Completion Rate" fill="#8B5CF6" radius={[6, 6, 0, 0]} />
                            </BarChart>
                          </ResponsiveContainer>
                        </div>
                      </div>
                    )}

                  </div>
                );
              })()}
            </>
          )}
        </main>
      </div>
    </div>
  );
};

export default Analytics;
