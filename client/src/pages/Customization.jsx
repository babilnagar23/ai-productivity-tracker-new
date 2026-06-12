import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { apiFetch } from '../services/api';
import Navbar from '../components/Navbar';
import Sidebar from '../components/Sidebar';
import { 
  Plus, 
  Trash2, 
  RotateCcw, 
  Settings, 
  CheckSquare, 
  Activity, 
  AlertCircle,
  HelpCircle
} from 'lucide-react';

const Customization = () => {
  const { user, refreshUser } = useAuth();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  // Form states for new checklist
  const [newChecklistTitle, setNewChecklistTitle] = useState('');
  const [newChecklistDesc, setNewChecklistDesc] = useState('');

  // Form states for new metric
  const [newMetricTitle, setNewMetricTitle] = useState('');

  const config = user?.customConfig || {
    coreChecklists: [],
    coreMetrics: [],
    deletedHistory: []
  };

  const handleSaveConfig = async (updatedConfig) => {
    setLoading(true);
    setError('');
    setSuccess('');
    try {
      const res = await apiFetch('/auth/custom-config', {
        method: 'PUT',
        body: JSON.stringify({ customConfig: updatedConfig })
      });
      if (res.success) {
        setSuccess('Configuration synchronized successfully!');
        await refreshUser();
      } else {
        setError(res.error || 'Failed to sync settings.');
      }
    } catch (err) {
      setError(err.message || 'An error occurred during synchronization.');
    } finally {
      setLoading(false);
    }
  };

  // Add a Core Checklist
  const handleAddChecklist = (e) => {
    e.preventDefault();
    if (!newChecklistTitle.trim()) return;

    const newId = 'chk_' + Math.random().toString(36).substring(2, 9);
    const updatedChecklists = [
      ...config.coreChecklists,
      {
        id: newId,
        title: newChecklistTitle.trim(),
        description: newChecklistDesc.trim() || 'Custom checklist milestone'
      }
    ];

    const updatedConfig = {
      ...config,
      coreChecklists: updatedChecklists
    };

    handleSaveConfig(updatedConfig);
    setNewChecklistTitle('');
    setNewChecklistDesc('');
  };

  // Delete a Core Checklist (moves to Recovery Bin)
  const handleDeleteChecklist = (id) => {
    const itemToDelete = config.coreChecklists.find(item => item.id == id);
    if (!itemToDelete) return;

    const updatedChecklists = config.coreChecklists.filter(item => item.id !== id);
    const updatedHistory = [
      ...config.deletedHistory,
      {
        ...itemToDelete,
        type: 'checklist',
        deletedAt: new Date().toISOString()
      }
    ];

    const updatedConfig = {
      ...config,
      coreChecklists: updatedChecklists,
      deletedHistory: updatedHistory
    };

    handleSaveConfig(updatedConfig);
  };

  // Add a Core Metric
  const handleAddMetric = (e) => {
    e.preventDefault();
    if (!newMetricTitle.trim()) return;

    const newId = 'metric_' + Math.random().toString(36).substring(2, 9);
    const updatedMetrics = [
      ...config.coreMetrics,
      {
        id: newId,
        title: newMetricTitle.trim()
      }
    ];

    const updatedConfig = {
      ...config,
      coreMetrics: updatedMetrics
    };

    handleSaveConfig(updatedConfig);
    setNewMetricTitle('');
  };

  // Delete a Core Metric (moves to Recovery Bin)
  const handleDeleteMetric = (id) => {
    const itemToDelete = config.coreMetrics.find(item => item.id == id);
    if (!itemToDelete) return;

    const updatedMetrics = config.coreMetrics.filter(item => item.id !== id);
    const updatedHistory = [
      ...config.deletedHistory,
      {
        ...itemToDelete,
        type: 'metric',
        deletedAt: new Date().toISOString()
      }
    ];

    const updatedConfig = {
      ...config,
      coreMetrics: updatedMetrics,
      deletedHistory: updatedHistory
    };

    handleSaveConfig(updatedConfig);
  };

  // Restore deleted item from Recovery Bin
  const handleRestoreItem = (deletedItem) => {
    const updatedHistory = config.deletedHistory.filter(item => item.id !== deletedItem.id);
    
    let updatedChecklists = [...config.coreChecklists];
    let updatedMetrics = [...config.coreMetrics];

    if (deletedItem.type === 'checklist') {
      updatedChecklists.push({
        id: deletedItem.id,
        title: deletedItem.title,
        description: deletedItem.description
      });
    } else if (deletedItem.type === 'metric') {
      updatedMetrics.push({
        id: deletedItem.id,
        title: deletedItem.title
      });
    }

    const updatedConfig = {
      coreChecklists: updatedChecklists,
      coreMetrics: updatedMetrics,
      deletedHistory: updatedHistory
    };

    handleSaveConfig(updatedConfig);
  };

  return (
    <div className="flex bg-void min-h-screen text-white">
      <Sidebar />
      <div className="flex-1 flex flex-col overflow-y-auto">
        <Navbar />

        <main className="p-8 space-y-8 flex-1">
          {/* Header */}
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-3xl font-hero font-extrabold tracking-tight">System Customization</h1>
              <p className="text-sm text-gray-400">Configure core tracking variables and easily restore deleted layouts.</p>
            </div>
            <div className="bg-white/5 border border-white/5 px-4 py-2 rounded-xl text-xs text-cyan flex items-center gap-1.5 font-medium">
              <Settings className="h-4 w-4 animate-spin-slow" /> Custom Engine Active
            </div>
          </div>

          {/* Feedback Indicators */}
          {error && (
            <div className="bg-red-500/10 border border-red-500/20 text-red-400 px-4 py-3 rounded-2xl text-sm flex items-center gap-2">
              <AlertCircle className="h-4 w-4" /> {error}
            </div>
          )}
          {success && (
            <div className="bg-green-500/10 border border-green-500/20 text-green-400 px-4 py-3 rounded-2xl text-sm flex items-center gap-2">
              <AlertCircle className="h-4 w-4" /> {success}
            </div>
          )}

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            <div className="glass card-3d p-6 space-y-6">
              <div className="flex items-center justify-between border-b border-white/5 pb-4">
                <h3 className="font-bold text-lg text-white flex items-center gap-2">
                  <CheckSquare className="h-5 w-5 text-cyan" /> Core Checklists
                </h3>
                <span className="text-[10px] bg-cyan/10 text-cyan px-2.5 py-1 rounded-full font-bold">
                  {config.coreChecklists.length} Active
                </span>
              </div>

              {/* Active Checklists list */}
              <div className="space-y-3 max-h-60 overflow-y-auto pr-1">
                {config.coreChecklists.length === 0 ? (
                  <p className="text-xs text-gray-500 italic py-4">No active Core Checklists. Add one below!</p>
                ) : (
                  config.coreChecklists.map((item) => (
                    <div key={item.id} className="flex justify-between items-center p-4 bg-white/5 border border-white/5 rounded-2xl">
                      <div>
                        <h4 className="font-semibold text-sm text-white">{item.title}</h4>
                        <p className="text-[10px] text-gray-400">{item.description}</p>
                      </div>
                      <button
                        onClick={() => handleDeleteChecklist(item.id)}
                        disabled={loading}
                        className="p-2 text-red-400 hover:bg-red-500/10 border border-transparent hover:border-red-500/20 rounded-xl transition"
                        title="Delete (Move to trash)"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  ))
                )}
              </div>

              {/* Add form */}
              <form onSubmit={handleAddChecklist} className="space-y-3 pt-4 border-t border-white/5">
                <h4 className="text-xs uppercase font-bold text-gray-400">Add Core Checklist</h4>
                <div className="space-y-2">
                  <input
                    type="text"
                    required
                    placeholder="Checklist Title (e.g. Core Study Completed)"
                    value={newChecklistTitle}
                    onChange={(e) => setNewChecklistTitle(e.target.value)}
                    className="w-full px-4 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white focus:outline-none focus:border-cyan transition text-xs"
                  />
                  <input
                    type="text"
                    placeholder="Brief description / instructions..."
                    value={newChecklistDesc}
                    onChange={(e) => setNewChecklistDesc(e.target.value)}
                    className="w-full px-4 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white focus:outline-none focus:border-cyan transition text-xs"
                  />
                </div>
                <button
                  type="submit"
                  disabled={loading}
                  className="w-full flex items-center justify-center gap-1.5 py-2.5 rounded-xl bg-cyan font-semibold text-black text-xs hover:opacity-90 transition"
                >
                  <Plus className="h-3.5 w-3.5" /> Add Checklist
                </button>
              </form>
            </div>

            <div className="glass card-3d p-6 space-y-6">
              <div className="flex items-center justify-between border-b border-white/5 pb-4">
                <h3 className="font-bold text-lg text-white flex items-center gap-2">
                  <Activity className="h-5 w-5 text-plasma" /> Core Numerical Metrics
                </h3>
                <span className="text-[10px] bg-plasma/10 text-plasma px-2.5 py-1 rounded-full font-bold">
                  {config.coreMetrics.length} Active
                </span>
              </div>

              {/* Active Metrics list */}
              <div className="space-y-3 max-h-60 overflow-y-auto pr-1">
                {config.coreMetrics.length === 0 ? (
                  <p className="text-xs text-gray-500 italic py-4">No active Core Metrics. Add one below!</p>
                ) : (
                  config.coreMetrics.map((item) => (
                    <div key={item.id} className="flex justify-between items-center p-4 bg-white/5 border border-white/5 rounded-2xl">
                      <div>
                        <h4 className="font-semibold text-sm text-white">{item.title}</h4>
                        <span className="text-[9px] text-gray-400">Numeric input operator</span>
                      </div>
                      <button
                        onClick={() => handleDeleteMetric(item.id)}
                        disabled={loading}
                        className="p-2 text-red-400 hover:bg-red-500/10 border border-transparent hover:border-red-500/20 rounded-xl transition"
                        title="Delete (Move to trash)"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  ))
                )}
              </div>

              {/* Add form */}
              <form onSubmit={handleAddMetric} className="space-y-3 pt-4 border-t border-white/5">
                <h4 className="text-xs uppercase font-bold text-gray-400">Add Core Numerical Input</h4>
                <input
                  type="text"
                  required
                  placeholder="Metric Name (e.g. Study Duration (Hrs))"
                  value={newMetricTitle}
                  onChange={(e) => setNewMetricTitle(e.target.value)}
                  className="w-full px-4 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white focus:outline-none focus:border-plasma transition text-xs"
                />
                <button
                  type="submit"
                  disabled={loading}
                  className="w-full flex items-center justify-center gap-1.5 py-2.5 rounded-xl bg-plasma font-semibold text-black text-xs hover:opacity-90 transition"
                >
                  <Plus className="h-3.5 w-3.5" /> Add Metric
                </button>
              </form>
            </div>
          </div>

          <div className="glass card-3d p-6 space-y-4">
            <div className="flex items-center justify-between border-b border-white/5 pb-4">
              <div>
                <h3 className="font-bold text-lg text-white flex items-center gap-2">
                  <RotateCcw className="h-5 w-5 text-orange-400" /> Recovery Bin
                </h3>
                <p className="text-xs text-gray-400">Accidentally deleted items are stored here. Restore them back with historical integrity.</p>
              </div>
              <span className="text-[10px] bg-orange-500/10 text-orange-400 px-2.5 py-1 rounded-full font-bold">
                {config.deletedHistory ? config.deletedHistory.length : 0} Recoverable
              </span>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {!config.deletedHistory || config.deletedHistory.length === 0 ? (
                <div className="col-span-2 text-center py-8 text-gray-500 space-y-2">
                  <HelpCircle className="mx-auto h-8 w-8 text-gray-600" />
                  <p className="text-xs italic">Recovery Bin is empty. No recent variables deleted.</p>
                </div>
              ) : (
                config.deletedHistory.map((item, idx) => (
                  <div key={item.id || idx} className="flex justify-between items-center p-4 bg-white/5 border border-white/5 rounded-2xl">
                    <div>
                      <div className="flex items-center gap-1.5 mb-1">
                        <span className={`text-[8px] uppercase font-black px-1.5 py-0.5 rounded ${
                          item.type === 'checklist' ? 'bg-cyan/20 text-cyan' : 'bg-plasma/20 text-plasma'
                        }`}>
                          {item.type}
                        </span>
                        <span className="text-[9px] text-gray-500">
                          {new Date(item.deletedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                        </span>
                      </div>
                      <h4 className="font-bold text-xs text-white">{item.title}</h4>
                    </div>
                    <button
                      onClick={() => handleRestoreItem(item)}
                      disabled={loading}
                      className="flex items-center gap-1 px-3 py-1.5 bg-orange-500/10 border border-orange-500/20 hover:border-orange-500/40 text-orange-400 text-[10px] font-bold rounded-xl transition"
                    >
                      <RotateCcw className="h-3 w-3" /> Restore
                    </button>
                  </div>
                ))
              )}
            </div>
          </div>
        </main>
      </div>
    </div>
  );
};

export default Customization;
