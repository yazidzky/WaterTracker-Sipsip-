import 'package:flutter/material.dart';
import 'package:watertracker/services/user_service.dart';
import 'package:watertracker/services/water_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watertracker/services/notification_service.dart';
import 'package:watertracker/services/local_storage_service.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService = UserService();
  final WaterService _waterService = WaterService();

  Map<String, dynamic>? _profile;
  int _currentWater = 0;
  List<dynamic> _intakeHistory = [];
  List<dynamic> _allStats = [];
  bool _isLoading = false;
  String _wakeTime = "07:00";
  String _sleepTime = "21:30";

  Map<String, dynamic>? get profile => _profile;
  int get currentWater => _currentWater;
  List<dynamic> get intakeHistory => _intakeHistory;
  List<dynamic> get allStats => _allStats;
  bool get isLoading => _isLoading;

  String get name => _profile?['name'] ?? 'User';
  String get email => _profile?['email'] ?? '';
  String get avatar => _profile?['avatar'] ?? 'avatar1.png';
  int get dailyGoal => _profile?['dailyGoal'] ?? 2500;
  String get wakeTime => _wakeTime;
  String get sleepTime => _sleepTime;

  UserProvider() {
    _loadLocalUserData();
    refreshAll();
  }

  Future<void> _loadLocalUserData() async {
    // 1. Load from Hive
    _profile = LocalStorageService.getUserProfile();
    
    final localIntakes = LocalStorageService.getTodayIntakes();
    _currentWater = localIntakes.fold<int>(0, (sum, item) => sum + (item['amount'] as int));
    _intakeHistory = localIntakes;

    // 2. Load Wake/Sleep times from SharedPreferences (matching ReminderScreen keys)
    final prefs = await SharedPreferences.getInstance();
    final startHour = prefs.getInt('reminder_start_hour') ?? 7;
    final startMinute = prefs.getInt('reminder_start_minute') ?? 0;
    final endHour = prefs.getInt('reminder_end_hour') ?? 21;
    final endMinute = prefs.getInt('reminder_end_minute') ?? 30;
    
    _wakeTime = "${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}";
    _sleepTime = "${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}";
    
    notifyListeners();
  }

  Future<void> refreshAll() async {
    _isLoading = true;
    notifyListeners();

    // Trigger background sync if there's any pending data
    _waterService.syncPendingData().then((_) {
      fetchTodayIntake();
    });

    await Future.wait([
      fetchProfile(),
      fetchTodayIntake(),
      fetchStats(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchProfile() async {
    try {
      final user = await _userService.getProfile();
      if (user != null) {
        _profile = user;
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching profile in provider: $e');
    }
  }

  Future<void> fetchTodayIntake() async {
    try {
      final data = await _waterService.getTodayIntake();
      if (data != null) {
        _currentWater = data['totalAmount'] ?? 0;
        _intakeHistory = data['intakes'] ?? [];
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching intake in provider: $e');
    }
  }

  Future<void> fetchStats() async {
    try {
      final stats = await _waterService.getStats();
      if (stats != null) {
        _allStats = stats;
        notifyListeners();
      }
    } catch (e) {
      print('Error fetching stats in provider: $e');
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      final updatedUser = await _userService.updateProfile(data);
      if (updatedUser != null) {
        _profile = updatedUser;
        notifyListeners();
      }
    } catch (e) {
      print('Error updating profile in provider: $e');
      rethrow;
    }
  }

  Future<void> logIntake(int amount, String type) async {
    try {
      await _waterService.logIntake(amount, type);
      // Local UI update is handled by fetchTodayIntake (which now uses local-first)
      await fetchTodayIntake();
      fetchStats(); // Background refresh
    } catch (e) {
      print('Error logging intake in provider: $e');
      rethrow;
    }
  }

  Future<void> deleteIntake(String id) async {
    try {
      await _waterService.deleteIntake(id);
      await Future.wait([
        fetchTodayIntake(),
        fetchStats(),
      ]);
    } catch (e) {
      print('Error deleting intake in provider: $e');
      rethrow;
    }
  }

  Future<void> updateWakeTime(String time) async {
    _wakeTime = time;
    final parts = time.split(':');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_start_hour', int.parse(parts[0]));
    await prefs.setInt('reminder_start_minute', int.parse(parts[1]));
    
    // Auto-reschedule notifications if times change
    await NotificationService().rescheduleAllReminders();
    
    notifyListeners();
  }

  Future<void> updateSleepTime(String time) async {
    _sleepTime = time;
    final parts = time.split(':');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_end_hour', int.parse(parts[0]));
    await prefs.setInt('reminder_end_minute', int.parse(parts[1]));
    
    // Auto-reschedule notifications if times change
    await NotificationService().rescheduleAllReminders();
    
    notifyListeners();
  }
}
