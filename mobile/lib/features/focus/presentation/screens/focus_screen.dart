import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/focus_alarm_service.dart';

// ── Focus Session Model ───────────────────────────────────────────────────────

class FocusSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationMinutes;
  final String label;
  final bool completed;

  FocusSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.durationMinutes,
    required this.label,
    required this.completed,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'durationMinutes': durationMinutes,
        'label': label,
        'completed': completed,
      };

  factory FocusSession.fromJson(Map<String, dynamic> j) => FocusSession(
        id: j['id'] as String,
        startTime: DateTime.parse(j['startTime'] as String),
        endTime: j['endTime'] != null
            ? DateTime.parse(j['endTime'] as String)
            : null,
        durationMinutes: j['durationMinutes'] as int,
        label: j['label'] as String,
        completed: j['completed'] as bool,
      );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class FocusScreen extends StatefulWidget {
  final int? presetDuration;
  const FocusScreen({super.key, this.presetDuration});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;

  // Timer state
  int _selectedMinutes = 25;
  int _remainingSeconds = 25 * 60;
  bool _timerRunning = false;
  bool _timerPaused = false;
  Timer? _timer;
  DateTime? _sessionStart;
  DateTime? _sessionEndTime;
  final String _sessionLabel = 'Focus Session';

  // Stopwatch state
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _swTimer;
  final List<Duration> _laps = [];
  Duration _lastLapTime = Duration.zero;

  List<FocusSession> _sessions = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    if (widget.presetDuration != null) {
      _selectedMinutes = widget.presetDuration!;
      _remainingSeconds = _selectedMinutes * 60;
    }
    _loadSessions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _swTimer?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('focus_sessions');
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      setState(() {
        _sessions = list
            .map((e) => FocusSession.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    }
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('focus_sessions',
        jsonEncode(_sessions.map((s) => s.toJson()).toList()));
  }

  void _startTimer() {
    _sessionStart ??= DateTime.now();

    _sessionEndTime = DateTime.now().add(
      Duration(seconds: _remainingSeconds),
    );

    setState(() {
      _timerRunning = true;
      _timerPaused = false;
    });

    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (_sessionEndTime == null) return;

        final remaining = _sessionEndTime!.difference(DateTime.now()).inSeconds;

        if (remaining <= 0) {
          _timer?.cancel();

          setState(() {
            _remainingSeconds = 0;
            _timerRunning = false;
          });

          _onTimerComplete();
        } else {
          setState(() {
            _remainingSeconds = remaining;
          });
        }
      },
    );
  }

  void _pauseTimer() {
    _timer?.cancel();

    if (_sessionEndTime != null) {
      _remainingSeconds = _sessionEndTime!.difference(DateTime.now()).inSeconds;
    }

    setState(() {
      _timerRunning = false;
      _timerPaused = true;
    });
  }

  void _endTimer() {
    _timer?.cancel();
    final session = FocusSession(
      id: const Uuid().v4(),
      startTime: _sessionStart ?? DateTime.now(),
      endTime: DateTime.now(),
      durationMinutes: _selectedMinutes - (_remainingSeconds ~/ 60),
      label: _sessionLabel,
      completed: false,
    );
    _sessions.insert(0, session);
    _saveSessions();
    _sessionEndTime = null;
    setState(() {
      _timerRunning = false;
      _timerPaused = false;
      _remainingSeconds = _selectedMinutes * 60;
    });
  }

  Future<void> _onTimerComplete() async {
    final session = FocusSession(
      id: const Uuid().v4(),
      startTime: _sessionStart ?? DateTime.now(),
      endTime: DateTime.now(),
      durationMinutes: _selectedMinutes,
      label: _sessionLabel,
      completed: true,
    );

    _sessions.insert(0, session);

    await _saveSessions();

    setState(() {
      _remainingSeconds = _selectedMinutes * 60;
    });

    // Play alarm sound + vibration
    await FocusAlarmService.playAlarm();

    // Show notification
    await NotificationService.showFocusCompleted();

    if (mounted) {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Session Complete 🎉',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Great work! You completed a $_selectedMinutes minute focus session.',
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await FocusAlarmService.stopAlarm();

              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: Text(
              'Stop Alarm',
              style: GoogleFonts.inter(
                color: AppColors.blue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Stopwatch methods
  void _startStopwatch() {
    _stopwatch.start();
    _swTimer = Timer.periodic(
        const Duration(milliseconds: 100), (_) => setState(() {}));
  }

  void _stopStopwatch() {
    _stopwatch.stop();
    _swTimer?.cancel();
    setState(() {});
  }

  void _addLap() {
    final current = _stopwatch.elapsed;
    final lapTime = current - _lastLapTime;
    setState(() {
      _laps.insert(0, lapTime);
      _lastLapTime = current;
    });
  }

  void _resetStopwatch() {
    _stopwatch.reset();
    setState(() {
      _laps.clear();
      _lastLapTime = Duration.zero;
    });
  }

  void _saveStopwatchSession(String label) {
    final session = FocusSession(
      id: const Uuid().v4(),
      startTime: DateTime.now().subtract(_stopwatch.elapsed),
      endTime: DateTime.now(),
      durationMinutes: _stopwatch.elapsed.inMinutes,
      label: label.isEmpty ? 'Stopwatch Session' : label,
      completed: true,
    );
    _sessions.insert(0, session);
    _saveSessions();
    _resetStopwatch();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds % 1000 ~/ 10).toString().padLeft(2, '0');
    return '$h:$m:$s.$ms';
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  int get _todayFocusMinutes {
    final today = DateTime.now();
    return _sessions
        .where((s) =>
            s.completed &&
            s.startTime.year == today.year &&
            s.startTime.month == today.month &&
            s.startTime.day == today.day)
        .fold(0, (sum, s) => sum + s.durationMinutes);
  }

  int get _weekFocusMinutes {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    return _sessions
        .where((s) => s.completed && s.startTime.isAfter(weekStart))
        .fold(0, (sum, s) => sum + s.durationMinutes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('Focus Command Center',
            style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        // Settings icon removed — not needed here
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [Tab(text: 'Focus Timer'), Tab(text: 'Stopwatch')],
          indicatorColor: AppColors.blue,
          labelColor: AppColors.blue,
          unselectedLabelColor: AppColors.textMuted,
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildFocusTimer(), _buildStopwatch()],
      ),
    );
  }

  Widget _buildFocusTimer() {
    final progress = 1.0 - (_remainingSeconds / (_selectedMinutes * 60));
    final pct = (progress * 100).toInt();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        // Circular timer
        Center(
          child: SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(220, 220),
                  painter: _ArcPainter(progress: progress),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$pct%',
                        style: GoogleFonts.inter(
                            color: AppColors.textSecondary, fontSize: 14)),
                    Text(_formatTimer(_remainingSeconds),
                        style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 48,
                            fontWeight: FontWeight.w800)),
                    Text(_sessionLabel,
                        style: GoogleFonts.inter(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Duration presets (only when not running)
        if (!_timerRunning && !_timerPaused) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...[25, 45, 60, 90].map((m) {
                  final sel = _selectedMinutes == m;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedMinutes = m;
                      _remainingSeconds = m * 60;
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.blue : AppColors.cardElevated,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${m}m',
                          style: GoogleFonts.inter(
                              color:
                                  sel ? Colors.white : AppColors.textSecondary,
                              fontSize: 13)),
                    ),
                  );
                }),
                // Custom duration chip
                GestureDetector(
                  onTap: _showCustomDurationSheet,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: ![25, 45, 60, 90].contains(_selectedMinutes)
                          ? AppColors.blue
                          : AppColors.cardElevated,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: ![25, 45, 60, 90].contains(_selectedMinutes)
                            ? AppColors.blue
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          size: 13,
                          color: ![25, 45, 60, 90].contains(_selectedMinutes)
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ![25, 45, 60, 90].contains(_selectedMinutes)
                              ? '${_selectedMinutes}m'
                              : 'Custom',
                          style: GoogleFonts.inter(
                            color: ![25, 45, 60, 90].contains(_selectedMinutes)
                                ? Colors.white
                                : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _startTimer,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Start Session',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],

        if (_timerRunning || _timerPaused) ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _timerRunning ? _pauseTimer : _startTimer,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(_timerRunning ? 'Pause' : 'Resume',
                      style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _endTimer,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('End Session',
                      style: GoogleFonts.inter(
                          color: AppColors.error, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 20),
        // Stats row
        Row(
          children: [
            Expanded(
                child: _StatMiniCard(
              label: "Today's Focus Time",
              value: '${_todayFocusMinutes ~/ 60}h ${_todayFocusMinutes % 60}m',
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _StatMiniCard(
              label: 'Weekly Focus Hours',
              value: '${_weekFocusMinutes ~/ 60}h ${_weekFocusMinutes % 60}m',
            )),
          ],
        ),
        const SizedBox(height: 20),

        // Session history
        Text('Session History',
            style: GoogleFonts.inter(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (_sessions.isEmpty)
          Center(
              child: Text('No sessions yet',
                  style: GoogleFonts.inter(color: AppColors.textMuted))),
        ..._sessions.take(10).map((s) => _SessionTile(session: s)),
      ],
    );
  }

  Widget _buildStopwatch() {
    final elapsed = _stopwatch.elapsed;
    final isRunning = _stopwatch.isRunning;
    final hasStopped = !isRunning && elapsed.inMilliseconds > 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Text(
            _formatDuration(elapsed),
            style: GoogleFonts.robotoMono(
              color: AppColors.textPrimary,
              fontSize: 44,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (_laps.isNotEmpty)
          Center(
            child: Text(
              'Last lap: ${_formatDuration(_laps.first)}',
              style: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        const SizedBox(height: 32),
        if (!isRunning && !hasStopped)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _startStopwatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Start',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        if (isRunning)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _addLap,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Lap',
                      style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _stopStopwatch,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Stop',
                      style: GoogleFonts.inter(
                          color: AppColors.error, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        if (hasStopped)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _resetStopwatch,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Reset',
                      style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showSaveSessionSheet(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Save Session',
                      style: GoogleFonts.inter(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),
        if (_laps.isNotEmpty) ...[
          Text('Laps',
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._laps.asMap().entries.map((e) {
            final lapNum = _laps.length - e.key;
            final isLatest = e.key == 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isLatest
                    ? AppColors.blue.withValues(alpha: 0.1)
                    : AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isLatest
                        ? AppColors.blue.withValues(alpha: 0.3)
                        : AppColors.border),
              ),
              child: Row(
                children: [
                  Text('Lap $lapNum',
                      style: GoogleFonts.inter(
                          color: AppColors.textSecondary, fontSize: 14)),
                  const Spacer(),
                  Text(_formatDuration(e.value),
                      style: GoogleFonts.inter(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  void _showCustomDurationSheet() {
    final hoursCtrl = TextEditingController(text: '0');
    final minsCtrl = TextEditingController(text: '$_selectedMinutes');
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Custom Duration',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hours',
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: hoursCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.cardElevated,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AppColors.blue)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Minutes',
                          style: GoogleFonts.inter(
                              color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: minsCtrl,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.inter(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.cardElevated,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: AppColors.blue)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final h = int.tryParse(hoursCtrl.text) ?? 0;
                  final m = int.tryParse(minsCtrl.text) ?? 0;
                  final total = h * 60 + m;
                  if (total > 0) {
                    setState(() {
                      _selectedMinutes = total;
                      _remainingSeconds = total * 60;
                    });
                  }
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: Text('Set Duration',
                    style: GoogleFonts.inter(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveSessionSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Save this session',
                style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              style: GoogleFonts.inter(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Activity / Task name (optional)',
                hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.cardElevated,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _saveStopwatchSession(ctrl.text);
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: Text('Save',
                        style: GoogleFonts.inter(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {
                    _resetStopwatch();
                    Navigator.pop(ctx);
                  },
                  child: Text('Skip',
                      style: GoogleFonts.inter(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Arc Painter ───────────────────────────────────────────────────────────────

class _ArcPainter extends CustomPainter {
  final double progress;
  _ArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 12.0;

    // Track
    final trackPaint = Paint()
      ..color = const Color(0x14FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = AppColors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      2 * 3.14159 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _StatMiniCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatMiniCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.inter(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final FocusSession session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final time =
        '${session.startTime.hour.toString().padLeft(2, '0')}:${session.startTime.minute.toString().padLeft(2, '0')} AM';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.blue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.timer_outlined,
                color: AppColors.blue, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$time - ${session.label} (${session.durationMinutes}m)',
              style:
                  GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14),
            ),
          ),
          Icon(
            session.completed
                ? Icons.check_circle_rounded
                : Icons.cancel_outlined,
            color: session.completed ? AppColors.success : AppColors.textMuted,
            size: 18,
          ),
        ],
      ),
    );
  }
}
