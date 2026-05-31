import 'package:dio/dio.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../models/routine_model.dart';

class RoutineRepository {
  final Dio _dio = apiClient.dio;

  /// Backend list response: { success, count, data: [...] }
  Future<List<RoutineModel>> getRoutines() async {
    final response = await _dio.get(ApiEndpoints.routines);
    final body = response.data;
    List<dynamic> list;
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      list = body['data'] as List<dynamic>;
    } else if (body is List<dynamic>) {
      list = body;
    } else {
      list = [];
    }
    return list
        .map((e) => RoutineModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Backend create response: { success, data: {...} }
  Future<RoutineModel> createRoutine(RoutineModel routine) async {
    final response =
        await _dio.post(ApiEndpoints.routines, data: routine.toJson());
    final body = response.data as Map<String, dynamic>;
    final item = body.containsKey('data')
        ? body['data'] as Map<String, dynamic>
        : body;
    return RoutineModel.fromJson(item);
  }

  /// Backend update response: { success, data: {...} }
  Future<RoutineModel> updateRoutine(int id, RoutineModel routine) async {
    final response = await _dio.put(
      ApiEndpoints.routineDetail(id),
      data: routine.toJson(),
    );
    final body = response.data as Map<String, dynamic>;
    final item = body.containsKey('data')
        ? body['data'] as Map<String, dynamic>
        : body;
    return RoutineModel.fromJson(item);
  }

  Future<void> deleteRoutine(int id) async {
    await _dio.delete(ApiEndpoints.routineDetail(id));
  }

  Future<RoutineModel?> getRoutineByDate(String date) async {
    final routines = await getRoutines();
    try {
      return routines.firstWhere((r) => r.date == date);
    } catch (_) {
      return null;
    }
  }
}
