class RoutineModel {
  final int? id;
  final String date;
  final bool studyCompleted;
  final bool exerciseCompleted;
  final bool mlCompleted;
  final double studyHours;
  final String sleepTime;
  final String wakeTime;
  final double mobileUsage;
  final String notes;
  final int productivityScore;
  final Map<String, dynamic> coreChecklists;
  final Map<String, dynamic> coreMetrics;
  final List<dynamic> customLogs;

  const RoutineModel({
    this.id,
    required this.date,
    this.studyCompleted = false,
    this.exerciseCompleted = false,
    this.mlCompleted = false,
    this.studyHours = 0,
    this.sleepTime = '23:00',
    this.wakeTime = '07:00',
    this.mobileUsage = 0,
    this.notes = '',
    this.productivityScore = 0,
    this.coreChecklists = const {},
    this.coreMetrics = const {},
    this.customLogs = const [],
  });

  factory RoutineModel.fromJson(Map<String, dynamic> json) {
    // Backend serializer returns camelCase in to_representation.
    // Accept both camelCase (backend response) and snake_case (legacy / direct).
    return RoutineModel(
      id: json['id'] as int?,
      date: json['date'] as String,
      studyCompleted:
          (json['studyCompleted'] ?? json['study_completed']) as bool? ?? false,
      exerciseCompleted:
          (json['exerciseCompleted'] ?? json['exercise_completed']) as bool? ?? false,
      mlCompleted:
          (json['mlCompleted'] ?? json['ml_completed']) as bool? ?? false,
      studyHours:
          ((json['studyHours'] ?? json['study_hours']) as num?)?.toDouble() ?? 0,
      sleepTime:
          (json['sleepTime'] ?? json['sleep_time']) as String? ?? '23:00',
      wakeTime:
          (json['wakeTime'] ?? json['wake_time']) as String? ?? '07:00',
      mobileUsage:
          ((json['mobileUsage'] ?? json['mobile_usage']) as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String? ?? '',
      productivityScore:
          ((json['productivityScore'] ?? json['productivity_score']) as num?)
              ?.toInt() ?? 0,
      coreChecklists:
          (json['coreChecklists'] ?? json['core_checklists'])
              as Map<String, dynamic>? ?? {},
      coreMetrics:
          (json['coreMetrics'] ?? json['core_metrics'])
              as Map<String, dynamic>? ?? {},
      customLogs:
          (json['customLogs'] ?? json['custom_logs']) as List<dynamic>? ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'study_completed': studyCompleted,
    'exercise_completed': exerciseCompleted,
    'ml_completed': mlCompleted,
    'study_hours': studyHours,
    'sleep_time': sleepTime,
    'wake_time': wakeTime,
    'mobile_usage': mobileUsage,
    'notes': notes,
    'productivity_score': productivityScore,
    'core_checklists': coreChecklists,
    'core_metrics': coreMetrics,
    'custom_logs': customLogs,
  };

  RoutineModel copyWith({
    int? id,
    String? date,
    bool? studyCompleted,
    bool? exerciseCompleted,
    bool? mlCompleted,
    double? studyHours,
    String? sleepTime,
    String? wakeTime,
    double? mobileUsage,
    String? notes,
    int? productivityScore,
    Map<String, dynamic>? coreChecklists,
    Map<String, dynamic>? coreMetrics,
    List<dynamic>? customLogs,
  }) {
    return RoutineModel(
      id: id ?? this.id,
      date: date ?? this.date,
      studyCompleted: studyCompleted ?? this.studyCompleted,
      exerciseCompleted: exerciseCompleted ?? this.exerciseCompleted,
      mlCompleted: mlCompleted ?? this.mlCompleted,
      studyHours: studyHours ?? this.studyHours,
      sleepTime: sleepTime ?? this.sleepTime,
      wakeTime: wakeTime ?? this.wakeTime,
      mobileUsage: mobileUsage ?? this.mobileUsage,
      notes: notes ?? this.notes,
      productivityScore: productivityScore ?? this.productivityScore,
      coreChecklists: coreChecklists ?? this.coreChecklists,
      coreMetrics: coreMetrics ?? this.coreMetrics,
      customLogs: customLogs ?? this.customLogs,
    );
  }
}
