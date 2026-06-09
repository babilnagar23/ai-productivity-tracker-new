import 'package:intl/intl.dart';

class TodoModel {
  final int? id;
  final String title;
  final String description;
  final DateTime dueDate;
  final bool completed;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TodoModel({
    this.id,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.completed = false,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  TodoModel copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? dueDate,
    bool? completed,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodoModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static bool _parseBool(dynamic value) {
    if (value == true) return true;
    if (value == 1) return true;
    final text = value.toString().toLowerCase();
    return text == 'true' || text == '1';
  }

  factory TodoModel.fromJson(Map<String, dynamic> json) {
    final dueRaw = json['due_date'] ?? json['date'];
    return TodoModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}'),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      dueDate: dueRaw != null
          ? DateTime.parse(dueRaw.toString())
          : DateTime.now(),
      completed: _parseBool(json['completed']),
      completedAt: _tryParseDate(json['completed_at']),
      createdAt: _tryParseDate(json['created_at']),
      updatedAt: _tryParseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
      'completed': completed,
      if (completedAt != null) 'completed_at': completedAt!.toUtc().toIso8601String(),
    };
  }
}