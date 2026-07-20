import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/theme/app_theme.dart';

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  _ChatMessage({required this.text, required this.isUser}) : time = DateTime.now();
}

class AiCoachScreen extends ConsumerStatefulWidget {
  const AiCoachScreen({super.key});

  @override
  ConsumerState<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends ConsumerState<AiCoachScreen> {
  final _messages = <_ChatMessage>[];
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;

  final _tips = [
    'Focus Tip: Try the Pomodoro Technique for 25-minute intervals.',
    'Habit Suggestion: Review daily goals at 9:00 AM.',
    'Focus Tip: Minimize distractions during deep work.',
    'Habit Suggestion: Take a 5-minute break every hour.',
    'Focus Tip: Use background music to boost concentration.',
    'Habit Suggestion: Track your water intake throughout the day.',
    'Focus Tip: Set a clear intention before each work session.',
    'Habit Suggestion: Reflect on your day before sleeping.',
    'Focus Tip: Batch similar tasks together to reduce context switching.',
    'Habit Suggestion: Start your morning with the hardest task.',
  ];

  List<Map<String, dynamic>> _activeTips = [];

  @override
  void initState() {
    super.initState();
    _activeTips = List.generate(_tips.length, (i) => {'text': _tips[i], 'saved': false, 'id': '$i'});
    _activeTips.shuffle();
    _activeTips = _activeTips.take(5).toList();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;
    final userMsg = message.trim();
    _textCtrl.clear();
    setState(() {
      _messages.add(_ChatMessage(text: userMsg, isUser: true));
      _isTyping = true;
    });
    _scrollToBottom();
    try {
      final response = await apiClient.dio.post(ApiEndpoints.aiChat, data: {'message': userMsg});
      final int jobId = response.data['job_id'];
      debugPrint('Job ID received: $jobId');

      setState(() {
        _messages.add(_ChatMessage(text: 'Generating response...', isUser: false));
      });
      _scrollToBottom();

      await _pollJobStatus(jobId);
    } on DioException catch (e) {
      String msg;
      if (e.response?.statusCode == 429) { msg = '⚠️ AI quota exceeded. Try again in a moment.'; }
      else { msg = '❌ Could not get a response. Check your connection.'; }
      setState(() { _messages.add(_ChatMessage(text: msg, isUser: false)); _isTyping = false; });
    }
    _scrollToBottom();
  }

  Future<void> _pollJobStatus(int jobId) async {
    final pollingUrl = ApiEndpoints.aiJobDetail(jobId);
    while (mounted) {
      await Future.delayed(const Duration(seconds: 2));
      try {
        debugPrint('jobId received: $jobId');
        debugPrint('polling URL: $pollingUrl');
        final response = await apiClient.dio.get(pollingUrl);
        debugPrint('status code: ${response.statusCode}');
        debugPrint('response.data: ${response.data}');

        if (response.data == null || response.data is! Map) {
          debugPrint('JSON parsing error: Response is not a JSON Map. Raw body: ${response.data}');
          setState(() {
            if (_messages.isNotEmpty) {
              _messages.removeLast();
            }
            _messages.add(_ChatMessage(text: '❌ Could not get a response. Invalid response format.', isUser: false));
            _isTyping = false;
          });
          return;
        }

        final status = response.data['status'];
        debugPrint('Status: $status');

        if (status == 'done') {
          final result = response.data['result'] as String? ?? 'No response result found.';
          setState(() {
            if (_messages.isNotEmpty) {
              _messages.removeLast();
            }
            _messages.add(_ChatMessage(text: result, isUser: false));
            _isTyping = false;
          });
          _scrollToBottom();
          return;
        }

        if (status == 'failed') {
          setState(() {
            if (_messages.isNotEmpty) {
              _messages.removeLast();
            }
            _messages.add(_ChatMessage(text: '❌ The AI job failed to process. Please try again.', isUser: false));
            _isTyping = false;
          });
          return;
        }
      } on DioException catch (e) {
        debugPrint('DioException in polling: $e');
        debugPrint('DioException response: ${e.response}');
        debugPrint('DioException error detail: ${e.error}');

        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;

        if (statusCode == 401 || statusCode == 403) {
          setState(() {
            if (_messages.isNotEmpty) {
              _messages.removeLast();
            }
            _messages.add(_ChatMessage(text: '🔒 Authentication error. Please log in again.', isUser: false));
            _isTyping = false;
          });
          return;
        }

        if (statusCode == 404) {
          debugPrint('404 URL mismatch. Polled URL: $pollingUrl, Status Code: $statusCode');
          setState(() {
            if (_messages.isNotEmpty) {
              _messages.removeLast();
            }
            _messages.add(_ChatMessage(text: '❌ Polling endpoint not found (404). Check backend configuration.', isUser: false));
            _isTyping = false;
          });
          return;
        }

        if (responseData != null && responseData is! Map) {
          debugPrint('Raw response body: $responseData');
        }

        setState(() {
          if (_messages.isNotEmpty) {
            _messages.removeLast();
          }
          _messages.add(_ChatMessage(text: '❌ Could not get a response. Check your connection.', isUser: false));
          _isTyping = false;
        });
        return;
      } catch (e, s) {
        debugPrint('General exception in polling: $e');
        debugPrint(s.toString());
        setState(() {
          if (_messages.isNotEmpty) {
            _messages.removeLast();
          }
          _messages.add(_ChatMessage(text: '❌ JSON parsing or unexpected error occurred.', isUser: false));
          _isTyping = false;
        });
        return;
      }
    }
  }

  Future<void> _callAnalyze() async {
    setState(() => _isTyping = true);
    try {
      final response = await apiClient.dio.post(ApiEndpoints.aiAnalyze);
      final analysis = response.data['analysis'] as String? ?? response.data.toString();
      _showResultModal('Productivity Analysis', analysis);
    } catch (e) {
      _showResultModal('Error', 'Could not analyze: $e');
    } finally {
      setState(() => _isTyping = false);
    }
  }

  Future<void> _callGeneratePlan() async {
    setState(() => _isTyping = true);
    try {
      final response = await apiClient.dio.post(ApiEndpoints.aiGeneratePlan);
      final plan = response.data['plan'] as String? ?? response.data.toString();
      _showResultModal('Study Plan', plan);
    } catch (e) {
      _showResultModal('Error', 'Could not generate plan: $e');
    } finally {
      setState(() => _isTyping = false);
    }
  }

  void _showResultModal(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700))),
                  IconButton(icon: Icon(Icons.close_rounded, color: AppColors.textMuted), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Text(content, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14, height: 1.6)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Coach Workspace', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Your personal productivity mentor', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14)),
                        const SizedBox(height: 20),

                        // Quick action cards
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.5,
                          children: [
                            _QuickCard(icon: Icons.insights_rounded, label: 'Analyse Productivity', desc: 'Get AI insights', color: AppColors.blue, onTap: _callAnalyze),
                            _QuickCard(icon: Icons.edit_calendar_rounded, label: 'Create Study Plan', desc: 'AI-generated plan', color: AppColors.purple, onTap: _callGeneratePlan),
                            _QuickCard(icon: Icons.summarize_rounded, label: 'Weekly Review', desc: 'This week summary', color: AppColors.success, onTap: () => _sendMessage('Give me my weekly review')),
                            _QuickCard(icon: Icons.center_focus_strong_rounded, label: 'Improve Focus', desc: 'Focus strategies', color: AppColors.warning, onTap: () => _sendMessage('How can I improve my focus?')),
                            _QuickCard(icon: Icons.bolt_rounded, label: 'Reduce Procrastination', desc: 'Beat delays', color: AppColors.cyan, onTap: () => _sendMessage('Help me overcome procrastination')),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // AI Reports
                        Text('AI Reports', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 140,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _ReportCard(title: 'Weekly Review', subtitle: 'This week', metric: '85% Focus Score',
                                  onTap: () => _sendMessage('Give me my weekly review')),
                              _ReportCard(title: 'Monthly Review', subtitle: DateFormat('MMMM').format(DateTime.now()),
                                  metric: 'Productivity Trend', onTap: () => _sendMessage('Give me my monthly productivity review')),
                              _ReportCard(title: 'Habit Analysis', subtitle: 'All time', metric: 'View habits',
                                  onTap: () => _sendMessage('Analyze my habit completion patterns')),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Tips
                        Text('Personalised Tips & Suggestions', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        ..._activeTips.map((tip) => _TipCard(
                          tip: tip['text'] as String,
                          saved: tip['saved'] as bool,
                          onSave: () => setState(() => tip['saved'] = !(tip['saved'] as bool)),
                          onDismiss: () => setState(() => _activeTips.remove(tip)),
                        )),
                        const SizedBox(height: 16),

                        // Chat messages
                        if (_messages.isNotEmpty) ...[
                          Text('Chat', style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          ..._messages.map((m) => _MessageBubble(message: m)),
                          if (_isTyping) const _TypingIndicator(),
                          const SizedBox(height: 80),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Chat input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    style: GoogleFonts.inter(color: AppColors.textPrimary),
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendMessage,
                    decoration: InputDecoration(
                      hintText: 'Ask your AI coach...',
                      hintStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 14),
                      filled: true,
                      fillColor: AppColors.cardElevated,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: AppColors.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: AppColors.blue)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _sendMessage(_textCtrl.text),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: AppColors.blue, borderRadius: BorderRadius.circular(22)),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final Color color;
  final VoidCallback onTap;
  const _QuickCard({required this.icon, required this.label, required this.desc, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const Spacer(),
            Text(label, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(desc, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String metric;
  final VoidCallback onTap;
  const _ReportCard({required this.title, required this.subtitle, required this.metric, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          Text(subtitle, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
          const Spacer(),
          Text(metric, style: GoogleFonts.inter(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onTap,
            child: Text('View Details', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12, decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final String tip;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onDismiss;
  const _TipCard({required this.tip, required this.saved, required this.onSave, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final isHabit = tip.startsWith('Habit');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isHabit ? AppColors.success : AppColors.blue).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(isHabit ? Icons.check_circle_outline_rounded : Icons.lightbulb_outline_rounded,
                color: isHabit ? AppColors.success : AppColors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(tip, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
          ),
          Column(
            children: [
              GestureDetector(
                onTap: onSave,
                child: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                    color: saved ? AppColors.blue : AppColors.textMuted, size: 20),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(Icons.close_rounded, color: AppColors.textMuted, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.blue : AppColors.cardElevated,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser ? null : Border.all(color: AppColors.border),
              ),
              child: Text(message.text, style: GoogleFonts.inter(
                  color: isUser ? Colors.white : AppColors.textPrimary, fontSize: 14, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text('AI is thinking...', style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13, fontStyle: FontStyle.italic)),
    );
  }
}

