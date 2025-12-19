import 'package:dio/dio.dart';
import 'package:watertracker/services/api_service.dart';
import 'local_storage_service.dart';

class UserService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response = await _apiService.dio.get('/auth/me');
      if (response.data != null) {
        final profile = Map<String, dynamic>.from(response.data);
        await LocalStorageService.saveUserProfile(profile);
        return profile;
      }
    } on DioException catch (e) {
      print('Get profile error (using local): ${e.message}');
    }

    // Fallback to local
    return LocalStorageService.getUserProfile();
  }

  Future<Map<String, dynamic>?> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.dio.put('/users/profile', data: data);
      if (response.data != null) {
        final profile = Map<String, dynamic>.from(response.data);
        await LocalStorageService.saveUserProfile(profile);
        return profile;
      }
    } on DioException catch (e) {
      print('Update profile error: ${e.message}');
    }
    
    // In this simple offline mode, we update local first if allowed, 
    // but usually profile updates need to be confirmed by server.
    // For now, let's just return what we have.
    return LocalStorageService.getUserProfile();
  }
}
