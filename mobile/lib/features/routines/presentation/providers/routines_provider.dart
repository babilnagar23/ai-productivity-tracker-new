import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/routine_model.dart';
import '../../data/repositories/routine_repository.dart';

/// Shared provider for the full list of routines.
/// Import this file in any screen that needs to watch/invalidate routines.
final routinesProvider = FutureProvider<List<RoutineModel>>((ref) async {
  return RoutineRepository().getRoutines();
});

/// Shared provider for the user's custom habit & metric configuration.
/// Contains: { coreChecklists: [...], coreMetrics: [...], deletedHistory: [...] }
///
/// Invalidate this provider whenever the customization config changes so that
/// ALL dependent screens (Daily Log, Analytics, Dashboard, AddRoutine) refresh
/// automatically without an app restart.
final customConfigProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return RoutineRepository().getCustomConfig();
});
