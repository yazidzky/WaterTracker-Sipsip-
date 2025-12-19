import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '387859511366-krof544ah846du71jektnh7vh8r8vdcd.apps.googleusercontent.com',
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await _apiService.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        await _saveToken(data['token']);
        await _saveUser(data);
        return data;
      }
    } on DioException catch (e) {
      print('Login error [${e.type}]: ${e.response?.data}');
      String message = e.response?.data is Map ? (e.response?.data['message'] ?? 'Login failed') : 'Login failed';
      if (e.type == DioExceptionType.connectionTimeout) message = 'Connection timed out. Please check your internet or server.';
      throw Exception(message);
    }
    return null;
  }

  Future<Map<String, dynamic>?> register(String name, String email, String password, {String avatar = 'avatar1.png'}) async {
    try {
      final response = await _apiService.dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'avatar': avatar,
      });

      if (response.statusCode == 201) {
        final data = response.data;
        await _saveToken(data['token']);
        await _saveUser(data);
        return data;
      }
    } on DioException catch (e) {
      print('Register error [${e.type}]: ${e.response?.data}');
      String message = e.response?.data is Map ? (e.response?.data['message'] ?? 'Registration failed') : 'Registration failed';
      if (e.type == DioExceptionType.connectionTimeout) message = 'Connection timed out. Please check your internet or server.';
      throw Exception(message);
    }
    return null;
  }

  Future<Map<String, dynamic>?> loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User canceled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Sync with backend to check if user exists
        try {
          print('Attempting to sync with backend for Google user: ${user.email}');
          final syncResponse = await _apiService.dio.post('/auth/google', data: {
            'name': user.displayName,
            'email': user.email,
            'photoURL': user.photoURL,
            'googleId': user.uid,
          });

          if (syncResponse.statusCode == 200) {
            // Existing user - login successful
            final userData = syncResponse.data;
            print('Backend sync successful! Token received.');
            await _saveToken(userData['token']);
            await _saveUser(userData);
            return userData;
          }
        } on DioException catch (e) {
          if (e.response?.statusCode == 404) {
            // New user - needs registration
            print('New Google user detected, needs registration');
            final responseData = e.response?.data;
            return {
              'needsRegistration': true,
              'googleData': responseData['googleData'] ?? {
                'name': user.displayName ?? user.email?.split('@')[0] ?? 'User',
                'email': user.email,
                'googleId': user.uid,
              },
            };
          } else {
            print('CRITICAL: Backend Google Sync error: $e');
            throw Exception('Gagal sinkronisasi dengan server. Silakan coba lagi.');
          }
        } catch (e) {
          print('CRITICAL: Backend Google Sync error: $e');
          throw Exception('Gagal sinkronisasi dengan server. Silakan coba lagi.');
        }
      }
      return null;
    } catch (e) {
      print('Google Login error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print("Error signing out of Google/Firebase: $e");
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all data
  }

  Future<bool> deleteAccount() async {
    try {
      // Attempt to call backend delete endpoint
      // Assuming standard REST method DELETE /auth/delete based on plan
      // If endpoint differs, this will need adjustment.
      await _apiService.dio.delete('/auth/delete');
      
      // Perform local logout cleanup
      await logout();
      return true;
    } on DioException catch (e) {
      print('Delete account error: ${e.response?.data}');
      // Even if backend fails, we might want to log them out locally?
      // For now, let's treat it as a failure to report to user.
      return false;
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<void> _saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    // Simplified storage, might want to store minimal data or stringify json
    // For now we just store the name/email if needed locally
    await prefs.setString('userName', user['name'] ?? 'User');
    await prefs.setString('userEmail', user['email'] ?? '');
    await prefs.setString('userAvatar', user['avatar'] ?? 'avatar1.png');
  }
  
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('token');
  }
}
