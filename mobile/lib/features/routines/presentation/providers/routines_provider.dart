import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/routine_model.dart';
import '../../data/repositories/routine_repository.dart';

/// Shared provider for the full list of routines.
/// Import this file in any screen that needs to watch/invalidate routines.
final routinesProvider = FutureProvider<List<RoutineModel>>((ref) async {
  return RoutineRepository().getRoutines();
});
