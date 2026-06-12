import React, { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import AppLayout from '../components/layout/AppLayout';
import Modal from '../components/ui/Modal';
import Button from '../components/ui/Button';
import Badge from '../components/ui/Badge';
import EmptyState from '../components/ui/EmptyState';
import { todosApi } from '../services/api';
import {
  Plus, Search, CheckSquare, Trash2, Edit3, Calendar,
  Filter, AlertCircle, ChevronDown, X, Check
} from 'lucide-react';
import { format, parseISO, isPast, isToday } from 'date-fns';

const PRIORITIES = ['low', 'medium', 'high'];
const CATEGORIES = ['personal', 'work', 'study', 'health', 'other'];
const FILTERS = ['all', 'active', 'completed', 'overdue'];

const priorityBadge = { high: 'rose', medium: 'orange', low: 'gray' };
const priorityLabel = { high: '🔴 High', medium: '🟡 Medium', low: '⚪ Low' };

function TodoForm({ initial = {}, onSave, onClose }) {
  const [form, setForm] = useState({
    title: initial.title || '',
    description: initial.description || '',
    due_date: initial.due_date ? initial.due_date.split('T')[0] : '',
    priority: initial.priority || 'medium',
    category: initial.category || 'personal',
  });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!form.title.trim()) { setError('Title is required'); return; }
    setSaving(true);
    try {
      await onSave(form);
      onClose();
    } catch (err) {
      setError(err.message || 'Failed to save');
    } finally {
      setSaving(false);
    }
  };

  const inputClass = 'w-full bg-white/4 border border-white/10 rounded-xl px-3 py-2.5 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-cyan/50 focus:bg-white/6 transition-colors';

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {error && <p className="text-xs text-rose-400 bg-rose-500/10 border border-rose-500/20 rounded-lg px-3 py-2">{error}</p>}

      <div>
        <label className="text-xs font-semibold text-gray-400 mb-1.5 block">Title *</label>
        <input className={inputClass} placeholder="What needs to be done?" value={form.title}
          onChange={e => setForm(f => ({ ...f, title: e.target.value }))} autoFocus />
      </div>

      <div>
        <label className="text-xs font-semibold text-gray-400 mb-1.5 block">Description</label>
        <textarea className={`${inputClass} resize-none`} rows={2} placeholder="Add details..."
          value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} />
      </div>

      <div className="grid grid-cols-2 gap-3">
        <div>
          <label className="text-xs font-semibold text-gray-400 mb-1.5 block">Due Date</label>
          <input type="date" className={inputClass} value={form.due_date}
            onChange={e => setForm(f => ({ ...f, due_date: e.target.value }))} />
        </div>
        <div>
          <label className="text-xs font-semibold text-gray-400 mb-1.5 block">Priority</label>
          <select className={inputClass} value={form.priority} onChange={e => setForm(f => ({ ...f, priority: e.target.value }))}>
            {PRIORITIES.map(p => <option key={p} value={p}>{p.charAt(0).toUpperCase() + p.slice(1)}</option>)}
          </select>
        </div>
      </div>

      <div>
        <label className="text-xs font-semibold text-gray-400 mb-1.5 block">Category</label>
        <div className="flex flex-wrap gap-2">
          {CATEGORIES.map(c => (
            <button key={c} type="button"
              onClick={() => setForm(f => ({ ...f, category: c }))}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold border transition-all
                ${form.category === c
                  ? 'bg-cyan/20 border-cyan/40 text-cyan'
                  : 'bg-white/4 border-white/10 text-gray-400 hover:text-white'
                }`}>
              {c.charAt(0).toUpperCase() + c.slice(1)}
            </button>
          ))}
        </div>
      </div>

      <div className="flex gap-3 pt-2">
        <Button type="submit" loading={saving} fullWidth>
          {initial.id ? 'Save Changes' : 'Create Task'}
        </Button>
        <Button type="button" variant="secondary" onClick={onClose}>Cancel</Button>
      </div>
    </form>
  );
}

export default function Todos() {
  const [todos, setTodos] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('active');
  const [sortBy, setSortBy] = useState('due_date');
  const [showCreate, setShowCreate] = useState(false);
  const [editing, setEditing] = useState(null);
  const [deleting, setDeleting] = useState(null);
  const [error, setError] = useState('');
  const [completing, setCompleting] = useState(null);

  const fetchTodos = useCallback(async () => {
    setLoading(true);
    try {
      const res = await todosApi.list();
      const data = res?.data || res?.results || res || [];
      setTodos(Array.isArray(data) ? data : []);
    } catch (err) {
      setError(err.message || 'Failed to load tasks');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { fetchTodos(); }, [fetchTodos]);

  const handleComplete = async (todo) => {
    setCompleting(todo.id);
    try {
      await todosApi.update(todo.id, { completed: !todo.completed });
      setTodos(prev => prev.map(t => t.id === todo.id ? { ...t, completed: !t.completed } : t));
    } catch {
      setError('Failed to update task');
    } finally {
      setCompleting(null);
    }
  };

  const handleCreate = async (data) => {
    const res = await todosApi.create(data);
    const newTodo = res?.data || res;
    setTodos(prev => [newTodo, ...prev]);
  };

  const handleUpdate = async (data) => {
    const res = await todosApi.update(editing.id, data);
    const updated = res?.data || res;
    setTodos(prev => prev.map(t => t.id === editing.id ? { ...t, ...updated } : t));
  };

  const handleDelete = async () => {
    try {
      await todosApi.delete(deleting.id);
      setTodos(prev => prev.filter(t => t.id !== deleting.id));
      setDeleting(null);
    } catch { setError('Failed to delete'); }
  };

  // Filter + search
  const filtered = todos.filter(t => {
    const matchSearch = !search || t.title.toLowerCase().includes(search.toLowerCase());
    let matchFilter = true;
    if (filter === 'active') matchFilter = !t.completed;
    if (filter === 'completed') matchFilter = t.completed;
    if (filter === 'overdue') matchFilter = !t.completed && t.due_date && isPast(parseISO(t.due_date)) && !isToday(parseISO(t.due_date));
    return matchSearch && matchFilter;
  }).sort((a, b) => {
    if (sortBy === 'due_date') return (a.due_date || '9') < (b.due_date || '9') ? -1 : 1;
    if (sortBy === 'priority') {
      const w = { high: 0, medium: 1, low: 2 };
      return (w[a.priority] || 1) - (w[b.priority] || 1);
    }
    if (sortBy === 'created') return new Date(b.created_at) - new Date(a.created_at);
    return 0;
  });

  const counts = {
    all: todos.length,
    active: todos.filter(t => !t.completed).length,
    completed: todos.filter(t => t.completed).length,
    overdue: todos.filter(t => !t.completed && t.due_date && isPast(parseISO(t.due_date)) && !isToday(parseISO(t.due_date))).length,
  };

  return (
    <AppLayout title="Tasks">
      <div className="max-w-4xl mx-auto space-y-5 animate-fadeInUp">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center gap-3 justify-between">
          <div>
            <h1 className="text-xl font-hero font-extrabold text-white flex items-center gap-2">
              <CheckSquare className="w-5 h-5 text-green-400" /> Task Manager
            </h1>
            <p className="text-xs text-gray-400 mt-0.5">{counts.active} active · {counts.completed} completed</p>
          </div>
          <Button icon={Plus} onClick={() => setShowCreate(true)}>New Task</Button>
        </div>

        {error && (
          <div className="flex items-center gap-2 p-3 rounded-xl bg-rose-500/10 border border-rose-500/20 text-rose-400 text-sm">
            <AlertCircle className="w-4 h-4 flex-shrink-0" />
            {error}
            <button onClick={() => setError('')} className="ml-auto"><X className="w-4 h-4" /></button>
          </div>
        )}

        {/* Search + filters */}
        <div className="glass card-3d p-4 space-y-3">
          <div className="flex gap-3">
            <div className="flex-1 flex items-center gap-2 px-3 py-2.5 bg-white/4 border border-white/10 rounded-xl">
              <Search className="w-4 h-4 text-gray-500 flex-shrink-0" />
              <input
                className="flex-1 bg-transparent text-sm text-white placeholder-gray-500 outline-none"
                placeholder="Search tasks..."
                value={search}
                onChange={e => setSearch(e.target.value)}
              />
              {search && <button onClick={() => setSearch('')}><X className="w-3.5 h-3.5 text-gray-500" /></button>}
            </div>
            <select
              className="bg-white/4 border border-white/10 rounded-xl px-3 py-2 text-sm text-gray-300 focus:outline-none focus:border-cyan/50"
              value={sortBy} onChange={e => setSortBy(e.target.value)}
            >
              <option value="due_date">Sort: Due Date</option>
              <option value="priority">Sort: Priority</option>
              <option value="created">Sort: Created</option>
            </select>
          </div>

          {/* Filter tabs */}
          <div className="flex gap-1.5 flex-wrap">
            {FILTERS.map(f => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all
                  ${filter === f
                    ? 'bg-cyan/20 text-cyan border border-cyan/30'
                    : 'bg-white/4 text-gray-400 border border-white/5 hover:text-white hover:bg-white/8'
                  }`}
              >
                {f.charAt(0).toUpperCase() + f.slice(1)} ({counts[f]})
              </button>
            ))}
          </div>
        </div>

        {/* Task list */}
        <div className="space-y-2">
          {loading ? (
            Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="h-16 rounded-xl bg-white/3 animate-shimmer" />
            ))
          ) : filtered.length === 0 ? (
            <EmptyState
              icon={CheckSquare}
              title={search ? 'No tasks match your search' : 'No tasks here'}
              description={filter === 'active' ? 'Create a task to get started.' : 'Nothing to show.'}
              action={<Button icon={Plus} onClick={() => setShowCreate(true)} size="sm">New Task</Button>}
            />
          ) : (
            filtered.map((todo) => {
              const overdue = !todo.completed && todo.due_date && isPast(parseISO(todo.due_date)) && !isToday(parseISO(todo.due_date));
              const dueToday = !todo.completed && todo.due_date && isToday(parseISO(todo.due_date));

              return (
                <div
                  key={todo.id}
                  className={`group glass card-3d p-4 flex items-center gap-3 transition-all duration-200 hover:border-cyan/30
                    ${todo.completed ? 'opacity-60' : ''}
                    ${overdue ? 'border-rose-500/20' : ''}
                  `}
                >
                  {/* Checkbox */}
                  <button
                    onClick={() => handleComplete(todo)}
                    disabled={completing === todo.id}
                    className={`w-5 h-5 rounded-md border flex items-center justify-center flex-shrink-0 transition-all
                      ${todo.completed
                        ? 'bg-cyan border-cyan'
                        : 'border-white/20 hover:border-cyan'
                      }`}
                  >
                    {completing === todo.id ? (
                      <div className="w-3 h-3 rounded-full border-2 border-white/30 border-t-white animate-spin" />
                    ) : todo.completed ? (
                      <Check className="w-3 h-3 text-white" />
                    ) : null}
                  </button>

                  {/* Content */}
                  <div className="flex-1 min-w-0">
                    <p className={`text-sm font-semibold text-white truncate ${todo.completed ? 'line-through text-gray-500' : ''}`}>
                      {todo.title}
                    </p>
                    <div className="flex items-center gap-2 mt-0.5 flex-wrap">
                      {todo.due_date && (
                        <span className={`text-[10px] flex items-center gap-1 ${overdue ? 'text-rose-400' : dueToday ? 'text-orange-400' : 'text-gray-500'}`}>
                          <Calendar className="w-2.5 h-2.5" />
                          {overdue ? 'Overdue · ' : dueToday ? 'Due today · ' : ''}
                          {format(parseISO(todo.due_date), 'MMM d, yyyy')}
                        </span>
                      )}
                      {todo.category && (
                        <span className="text-[10px] text-gray-500">{todo.category}</span>
                      )}
                    </div>
                  </div>

                  {/* Priority */}
                  {todo.priority && (
                    <Badge variant={priorityBadge[todo.priority] || 'gray'} size="xs">
                      {todo.priority}
                    </Badge>
                  )}

                  {/* Actions */}
                  <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button onClick={() => setEditing(todo)}
                      className="p-1.5 rounded-lg hover:bg-white/5 text-gray-500 hover:text-white transition-colors">
                      <Edit3 className="w-3.5 h-3.5" />
                    </button>
                    <button onClick={() => setDeleting(todo)}
                      className="p-1.5 rounded-lg hover:bg-rose-500/10 text-gray-500 hover:text-rose-400 transition-colors">
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>

      {/* Create Modal */}
      <Modal isOpen={showCreate} onClose={() => setShowCreate(false)} title="New Task">
        <TodoForm onSave={handleCreate} onClose={() => setShowCreate(false)} />
      </Modal>

      {/* Edit Modal */}
      <Modal isOpen={!!editing} onClose={() => setEditing(null)} title="Edit Task">
        {editing && <TodoForm initial={editing} onSave={handleUpdate} onClose={() => setEditing(null)} />}
      </Modal>

      {/* Delete confirm */}
      <Modal isOpen={!!deleting} onClose={() => setDeleting(null)} title="Delete Task" size="sm">
        <p className="text-sm text-gray-300 mb-6">
          Delete <span className="font-semibold text-white">"{deleting?.title}"</span>? This cannot be undone.
        </p>
        <div className="flex gap-3">
          <Button variant="danger" onClick={handleDelete} fullWidth icon={Trash2}>Delete</Button>
          <Button variant="secondary" onClick={() => setDeleting(null)}>Cancel</Button>
        </div>
      </Modal>
    </AppLayout>
  );
}
