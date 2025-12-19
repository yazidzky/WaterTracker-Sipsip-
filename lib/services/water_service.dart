import 'package:dio/dio.dart';
import 'api_service.dart';
import 'local_storage_service.dart';

class WaterService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>?> logIntake(int amount, String type) async {
    final intakeDate = DateTime.now();
    final localIntake = {
      'amount': amount,
      'type': type,
      'date': intakeDate.toIso8601String(),
      'isPending': true, // Mark as pending sync
    };

    // 1. Save locally first
    await LocalStorageService.saveIntake(localIntake);

    try {
      // 2. Try to sync to backend
      final response = await _apiService.dio.post('/water', data: {
        'amount': amount,
        'type': type,
        'date': intakeDate.toIso8601String(),
      });
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // 3. If success, update local storage with backend data (clears pending status)
        final serverData = Map<String, dynamic>.from(response.data);
        serverData['isPending'] = false;
        await LocalStorageService.saveIntake(serverData);
        return serverData;
      }
    } on DioException catch (e) {
      print('Log intake error (offline?): ${e.message}');
      // 4. If offline/error, add to sync queue
      await LocalStorageService.addToSyncQueue(localIntake);
    } catch (e) {
      print('Unexpected log intake error: $e');
      await LocalStorageService.addToSyncQueue(localIntake);
    }
    
    return localIntake;
  }

  Future<Map<String, dynamic>?> getTodayIntake() async {
    // 1. Try to get from server to stay updated
    try {
      final response = await _apiService.dio.get('/water/today');
      if (response.data != null) {
        final data = Map<String, dynamic>.from(response.data);
        // Cache intakes
        if (data['intakes'] != null) {
          await LocalStorageService.saveIntakes(data['intakes']);
        }
        return data;
      }
    } on DioException catch (e) {
      print('Get today intake error (using local): ${e.message}');
    }

    // 2. Fallback to local storage if offline or error
    final localIntakes = LocalStorageService.getTodayIntakes();
    final totalAmount = localIntakes.fold<int>(0, (sum, item) => sum + (item['amount'] as int));
    
    return {
      'totalAmount': totalAmount,
      'intakes': localIntakes,
    };
  }

  Future<List<dynamic>?> getStats({DateTime? start, DateTime? end}) async {
    final String cacheKey = 'stats_${start?.toIso8601String() ?? 'all'}_${end?.toIso8601String() ?? 'all'}';
    try {
      final response = await _apiService.dio.get('/water/stats', queryParameters: {
        if (start != null) 'startDate': start.toIso8601String(),
        if (end != null) 'endDate': end.toIso8601String(),
      });
      if (response.data != null) {
        final stats = List<dynamic>.from(response.data);
        await LocalStorageService.saveStats(cacheKey, stats);
        return stats;
      }
    } on DioException catch (e) {
      print('Get stats error (using cache): ${e.message}');
    }
    
    return LocalStorageService.getStats(cacheKey);
  }

  Future<List<dynamic>?> getMonthlyStats({int? month, int? year}) async {
    final String cacheKey = 'monthly_stats_${month ?? 'curr'}_${year ?? 'curr'}';
    try {
      final response = await _apiService.dio.get('/water/monthly-stats', queryParameters: {
        if (month != null) 'month': month,
        if (year != null) 'year': year,
      });
      if (response.data != null) {
        final stats = List<dynamic>.from(response.data);
        await LocalStorageService.saveStats(cacheKey, stats);
        return stats;
      }
    } on DioException catch (e) {
      print('Get monthly stats error (using cache): ${e.message}');
    }
    return LocalStorageService.getStats(cacheKey);
  }

  Future<void> deleteIntake(String id) async {
    // If it's a local ID (not yet synced), we handle it differently
    // In this simple implementation, we try to delete on server, if fails, we just don't
    try {
      await LocalStorageService.deleteIntake(id);
      await _apiService.dio.delete('/water/$id');
    } on DioException catch (e) {
      print('Delete intake error: ${e.message}');
      // If it fails on server, it might be oridinary offline or already deleted
    }
  }

  // --- Background Sync Logic ---

  Future<void> syncPendingData() async {
    final queue = LocalStorageService.getSyncQueue();
    if (queue.isEmpty) return;

    print('Syncing ${queue.length} pending items...');
    for (var item in queue) {
      try {
        final localKey = item['local_key'];
        // Remove local_key before sending to server
        final syncData = Map<String, dynamic>.from(item)..remove('local_key')..remove('isPending');
        
        final response = await _apiService.dio.post('/water', data: syncData);
        if (response.statusCode == 200 || response.statusCode == 201) {
          await LocalStorageService.removeFromSyncQueue(localKey);
          // Also update the local intake with server data
          final serverData = Map<String, dynamic>.from(response.data);
          serverData['isPending'] = false;
          await LocalStorageService.saveIntake(serverData);
        }
      } catch (e) {
        print('Failed to sync item: $e');
        // Stop syncing for now if we lose connection again
        break;
      }
    }
  }
}
