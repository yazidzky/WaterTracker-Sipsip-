import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static const String intakeBoxName = 'water_intake';
  static const String userBoxName = 'user_profile';
  static const String syncBoxName = 'sync_queue';
  static const String statsBoxName = 'stats_cache';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(intakeBoxName);
    await Hive.openBox(userBoxName);
    await Hive.openBox(syncBoxName);
    await Hive.openBox(statsBoxName);
  }

  // --- Water Intake Operations ---

  static Future<void> saveIntake(Map<String, dynamic> intake) async {
    final box = Hive.box(intakeBoxName);
    // Use a unique key, maybe timestamp or ID from server
    final String key = intake['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    await box.put(key, intake);
  }

  static Future<void> saveIntakes(List<dynamic> intakes) async {
    final box = Hive.box(intakeBoxName);
    final Map<String, dynamic> data = {};
    for (var item in intakes) {
      final String key = item['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
      data[key] = item;
    }
    await box.putAll(data);
  }

  static List<Map<String, dynamic>> getIntakes() {
    final box = Hive.box(intakeBoxName);
    return box.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static List<Map<String, dynamic>> getTodayIntakes() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return getIntakes().where((item) {
      final dateStr = item['date'] as String;
      final date = DateTime.parse(dateStr);
      final itemDate = DateTime(date.year, date.month, date.day);
      return itemDate.isAtSameMomentAs(today);
    }).toList();
  }

  static Future<void> deleteIntake(String id) async {
    final box = Hive.box(intakeBoxName);
    await box.delete(id);
  }

  static Future<void> clearIntakes() async {
    await Hive.box(intakeBoxName).clear();
  }

  // --- User Profile Operations ---

  static Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    final box = Hive.box(userBoxName);
    await box.put('current_user', profile);
  }

  static Map<String, dynamic>? getUserProfile() {
    final box = Hive.box(userBoxName);
    final data = box.get('current_user');
    return data != null ? Map<String, dynamic>.from(data) : null;
  }

  // --- Sync Queue Operations ---

  static Future<void> addToSyncQueue(Map<String, dynamic> intake) async {
    final box = Hive.box(syncBoxName);
    final String key = DateTime.now().millisecondsSinceEpoch.toString();
    await box.put(key, intake);
  }

  static List<Map<String, dynamic>> getSyncQueue() {
    final box = Hive.box(syncBoxName);
    return box.toMap().entries.map((e) {
      final val = Map<String, dynamic>.from(e.value);
      val['local_key'] = e.key;
      return val;
    }).toList();
  }

  static Future<void> removeFromSyncQueue(dynamic localKey) async {
    final box = Hive.box(syncBoxName);
    await box.delete(localKey);
  }

  // --- Stats Cache Operations ---

  static Future<void> saveStats(String key, List<dynamic> stats) async {
    final box = Hive.box(statsBoxName);
    await box.put(key, stats);
  }

  static List<dynamic>? getStats(String key) {
    final box = Hive.box(statsBoxName);
    final data = box.get(key);
    return data != null ? List<dynamic>.from(data) : null;
  }
}
