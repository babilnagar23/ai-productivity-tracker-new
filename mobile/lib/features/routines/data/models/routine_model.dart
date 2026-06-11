class RoutineModel {
  final String id; // localId
  final int? serverId;
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
  final Map<String, bool> coreChecklists;
  final Map<String, dynamic> coreMetrics;
  final List<dynamic> customLogs;
  final String syncStatus;

  const RoutineModel({
    required this.id,
    this.serverId,
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
    this.syncStatus = 'synced',
  });

  static bool _parseBool(dynamic value) {
    if (value == true) return true;
    if (value == 1) return true;
    final text = value.toString().toLowerCase();
    return text == 'true' || text == '1';
  }

  factory RoutineModel.fromJson(Map<String, dynamic> json) {
    // Backend serializer returns camelCase in to_representation.
    // Accept both camelCase (backend response) and snake_case (legacy / direct).
    return RoutineModel(
      id: json['localId']?.toString() ?? json['client_uuid']?.toString() ?? '',
      serverId: json['serverId'] ?? json['id'],
      date: json['date'] as String,
      studyCompleted:
          _parseBool(json['studyCompleted'] ?? json['study_completed']),
      exerciseCompleted:
          _parseBool(json['exerciseCompleted'] ?? json['exercise_completed']),
      mlCompleted:
          _parseBool(json['mlCompleted'] ?? json['ml_completed']),
      studyHours:
          ((json['studyHours'] ?? json['study_hours']) as num?)?.toDouble() ??
              0,
      sleepTime:
          (json['sleepTime'] ?? json['sleep_time']) as String? ?? '23:00',
      wakeTime: (json['wakeTime'] ?? json['wake_time']) as String? ?? '07:00',
      mobileUsage:
          ((json['mobileUsage'] ?? json['mobile_usage']) as num?)?.toDouble() ??
              0,
      notes: json['notes'] as String? ?? '',
      productivityScore:
          ((json['productivityScore'] ?? json['productivity_score']) as num?)
                  ?.toInt() ??
              0,
      coreChecklists: Map<String, bool>.from(
        json['coreChecklists'] ?? json['core_checklists'] ?? {},
      ),
      coreMetrics: ((json['coreMetrics'] ?? json['core_metrics']) is Map)
          ? Map<String, dynamic>.from(
              json['coreMetrics'] ?? json['core_metrics'])
          : {},
      customLogs:
          (json['customLogs'] ?? json['custom_logs']) as List<dynamic>? ?? [],
      syncStatus: json['syncStatus'] as String? ?? 'synced',
    );
  }

  Map<String, dynamic> toJson() => {
        'localId': id,
        'client_uuid': id,
        if (serverId != null) 'serverId': serverId,
        if (serverId != null) 'id': serverId,
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
    String? id,
    int? serverId,
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
    Map<String, bool>? coreChecklists,
    Map<String, dynamic>? coreMetrics,
    List<dynamic>? customLogs,
    String? syncStatus,
  }) {
    return RoutineModel(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
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
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
