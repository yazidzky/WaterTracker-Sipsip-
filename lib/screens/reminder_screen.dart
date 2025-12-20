import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watertracker/l10n/app_localizations.dart';
import 'package:watertracker/providers/theme_provider.dart';
import 'package:watertracker/services/notification_service.dart';
import 'package:watertracker/services/user_service.dart';
import 'package:watertracker/services/water_service.dart';
import 'package:watertracker/services/reminder_service.dart';
import 'package:watertracker/providers/user_provider.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  List<ReminderModel> _reminders = [];
  final ReminderService _reminderService = ReminderService();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 30); // Default to match profile sleepTime
  String _intervalDisplay = "Auto";
  int? _intervalMinutes; // null for Auto
  bool _isLoading = true;

  List<String> _hiddenReminders = [];
  
  // Real Data
  int _currentWater = 0;
  int _goalWater = 2500;
  final WaterService _waterService = WaterService();
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchData();
    // Refresh status every minute
    _statusTimer = Stream.periodic(const Duration(minutes: 1)).listen((_) {
      if (mounted) setState(() {});
    });
  }

  late final dynamic _statusTimer;

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _fetchData() async {
    try {
      // Fetch Today's Intake
      final intakeData = await _waterService.getTodayIntake();
      // Fetch User Profile for Goal
      final userProfile = await _userService.getProfile();
      
      if (mounted) {
        setState(() {
          if (intakeData != null) {
            int fetchedIntake = intakeData['totalAmount'] ?? 0;
            // Only regenerate if reminders are empty (first run)
            // or if we decide to implement smarter sync.
            // For now, prioritize existing reminders to avoid reset loop.
            if (_reminders.isEmpty) {
               _currentWater = fetchedIntake;
               _generateNewSchedule();
               _saveSettings();
            } else {
               // Update current water display but do NOT reset reminders
               _currentWater = fetchedIntake;
            }
          }
          if (userProfile != null) {
             int fetchedGoal = _goalWater;
             if (userProfile['daily_goal'] != null) {
                fetchedGoal = userProfile['daily_goal'];
             } else if (userProfile['dailyGoal'] != null) {
                fetchedGoal = userProfile['dailyGoal'];
             }
             
             if (fetchedGoal != _goalWater) {
               _goalWater = fetchedGoal;
               if (_reminders.isEmpty) {
                  _generateNewSchedule();
               }
               _saveSettings(); // Auto-sync to storage and alarms
             }
          }
        });
      }
    } catch (e) {
      print("Error fetching data in reminder: $e");
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    setState(() {
      final startParts = userProvider.wakeTime.split(':');
      final endParts = userProvider.sleepTime.split(':');
      
      _startTime = TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      );
      _endTime = TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      );
      _intervalDisplay = prefs.getString('reminder_interval_display') ?? "Auto";
      final savedMinutes = prefs.getInt('reminder_interval_minutes');
      _intervalMinutes = savedMinutes == -1 ? null : savedMinutes;
      
      // Load actual reminders
      final String? savedDate = prefs.getString('reminders_date');
      final String todayDate = DateTime.now().toIso8601String().split('T')[0];
      
      List<String>? storedReminders;
      if (savedDate == todayDate) {
         storedReminders = prefs.getStringList('reminders_list');
      }

      if (storedReminders != null && storedReminders.isNotEmpty) {
        try {
          _reminders = storedReminders
              .map((s) => ReminderModel.fromJson(jsonDecode(s)))
              .toList();
        } catch (e) {
          print("Error decoding reminders: $e");
          _generateNewSchedule();
          _saveSettings(); // Ensure generated ones are scheduled
        }
      } else {
        _generateNewSchedule();
        _saveSettings(); // Ensure generated ones are scheduled
      }
      
      _isLoading = false;
    });
  }

  void _generateNewSchedule() {
    setState(() {
      _reminders = _reminderService.generateReminders(_goalWater, _currentWater, _startTime, _endTime, intervalMinutes: _intervalMinutes);
    });
  }

  Future<void> _deleteReminder(String time) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hiddenReminders.add(time);
    });
    await prefs.setStringList('hidden_reminders', _hiddenReminders);
  }

  Future<void> _saveSettings() async {
    print('DEBUG: _saveSettings() triggered');
    try {
      final prefs = await SharedPreferences.getInstance();
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.updateWakeTime(_formatTime(_startTime));
      await userProvider.updateSleepTime(_formatTime(_endTime));
      
      await prefs.setString('reminder_interval_display', _intervalDisplay);
      await prefs.setInt('reminder_interval_minutes', _intervalMinutes ?? -1);
      
      // Save reminders list
      List<String> reminderStrings = _reminders.map((r) => jsonEncode(r.toJson())).toList();
      await prefs.setStringList('reminders_list', reminderStrings);
      // Save date to ensure we reset on new day
      await prefs.setString('reminders_date', DateTime.now().toIso8601String().split('T')[0]);
      print('DEBUG: Saved ${reminderStrings.length} reminders to SharedPreferences');

      // Request permissions and schedule
      final notificationService = NotificationService();
      await notificationService.requestPermissions();
      print('DEBUG: Permissions requested, now scheduling list');
      await notificationService.scheduleRemindersList(_reminders);
      print('DEBUG: Scheduling complete');

      if (mounted) {
        NotificationService().showInAppNotification(context, NotificationType.updateSuccess);
      }
    } catch (e) {
      print("Error saving settings: $e");
      if (mounted) {
        NotificationService().showInAppNotification(context, NotificationType.updateFailed);
      }
    }
  }

  void _showTestMenu() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Menu Pengujian Notifikasi",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF65C9F6),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.notifications_active, color: Color(0xFF65C9F6)),
                title: const Text("Test Notifikasi Instan"),
                subtitle: const Text("Langsung munculkan notifikasi platform"),
                onTap: () {
                  Navigator.pop(context);
                  NotificationService().showInstantTestNotification();
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer, color: Color(0xFF65C9F6)),
                title: const Text("Test Alaram (10 Detik)"),
                subtitle: const Text("Jadwalkan notifikasi muncul dalam 10 detik"),
                onTap: () {
                  Navigator.pop(context);
                  NotificationService().scheduleTestNotification(10);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Alaram dijadwalkan dalam 10 detik. Silakan kunci layar atau ke background.")),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.list_alt, color: Color(0xFF65C9F6)),
                title: const Text("Cek Alaram Terjadwal"),
                subtitle: const Text("Lihat daftar alaram yang sedang aktif di sistem"),
                onTap: () async {
                  final pending = await NotificationService().getPendingNotifications();
                  if (!mounted) return;
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Alaram Aktif"),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: pending.isEmpty 
                          ? const Text("Tidak ada alaram yang terjadwal.")
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: pending.length,
                              itemBuilder: (context, i) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(pending[i]),
                              ),
                            ),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup")),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localized = AppLocalizations.of(context)!;
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    
    final Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF0F8FF);
    final Color textColor = isDark ? Colors.white : const Color(0xFF1D3557);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                   GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF65C9F6)),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      localized.translate('reminder'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  (() {
                    bool isPressed = false;
                    return StatefulBuilder(
                      builder: (context, setDialogState) {
                        return GestureDetector(
                          onTapDown: (_) => setDialogState(() => isPressed = true),
                          onTapUp: (_) {
                            setDialogState(() => isPressed = false);
                            _saveSettings();
                          },
                          onTapCancel: () => setDialogState(() => isPressed = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: isPressed ? const Color(0xFF65C9F6) : const Color(0xFF2fa2d6),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: isPressed
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF65C9F6).withOpacity(0.6),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              localized.translate('save'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        );
                      }
                    );
                  })(),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showTestMenu,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF65C9F6).withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.bug_report_outlined, size: 18, color: Color(0xFF65C9F6)),
                    ),
                  ),

                ],
              ),
            ),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const SizedBox(height: 20),
                  // Circular Progress Chart with Open Arc
                  Center(
                    child: SizedBox(
                      width: 250,
                      height: 250,
                      child: CustomPaint(
                        painter: ArcProgressBarPainter(
                          progress: _goalWater > 0 ? (_currentWater / _goalWater).clamp(0.0, 1.0) : 0, 
                          trackColor: const Color(0xFF65C9F6).withOpacity(0.2), // Lighter blue for track
                          progressColor: const Color(0xFF65C9F6),
                          strokeWidth: 24,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "${_currentWater}ml",
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF65C9F6),
                                ),
                              ),
                              Text(
                                "dari ${_goalWater}ml",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey : const Color(0xFF455A64),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Hari ini Dropdown
                  Center(
                    child: GestureDetector(
                      onTap: _selectDate,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatDate(_selectedDate),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: textColor),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                   // Time Settings Row
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => _selectTime(context, true),
                          child: _buildTimePill(_formatTime(_startTime)),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text("—", style: TextStyle(color: Colors.grey)),
                        ),
                        GestureDetector(
                          onTap: _showIntervalSelection,
                          child: _buildTimePill(_intervalDisplay),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text("—", style: TextStyle(color: Colors.grey)),
                        ),
                         GestureDetector(
                          onTap: () => _selectTime(context, false),
                          child: _buildTimePill(_formatTime(_endTime)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    localized.translate('todayRecord'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Reminders List
                  ..._reminders.asMap().entries.map((entry) => _buildReminderItem(entry.value, entry.key)),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Cleanup: removed _generateRemindersList as we now use _reminders directly

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  String _formatDate(DateTime date) {
    // Need context for localization? Or pass it. 
    // _formatDate is confusing if it returns "Hari ini" without context. 
    // Let's assume we can access AppLocalizations.of(context) inside build or pass it if this is helper.
    // It's inside State, so context is available.
    final localized = AppLocalizations.of(context)!;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (target == today) {
      // "Hari ini" -> localized
      // We might need to add "today" key. 'todayRecord' is "Today's Record".
      // Let's use specific key for "Today" if possible, or string literal if not critical. 
      // User requested "Hari ini" in ID. 
      return localized.translate('today');
    }
    
    // Simple format: DD/MM/YYYY
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF65C9F6),
            colorScheme: const ColorScheme.light(primary: Color(0xFF65C9F6)),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        _generateNewSchedule(); // Regenerate on time change
      });

    }
  }

  Future<void> _showIntervalSelection() async {
    final localized = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                localized.translate('selectInterval'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1D3557),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildIntervalOption("Auto", null),
                      _buildIntervalOption("30 ${localized.translate('mins')}", 30),
                      _buildIntervalOption("1 ${localized.translate('hour')}", 60),
                      _buildIntervalOption("2 ${localized.translate('hours')}", 120),
                      _buildIntervalOption("Custom", -1), // -1 for custom picker
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIntervalOption(String label, int? minutes) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;

    bool isSelected = _intervalDisplay == label || (_intervalDisplay.contains(label.split(" ")[0]) && label != "Auto" && label != "Custom"); // Rough check but logic might need refinement if labels change. 
    // Actually, relying on _intervalDisplay string match is fragile with localization.
    // Better to check `_intervalMinutes`.
    if (minutes == null) {
      isSelected = _intervalMinutes == null;
    } else if (minutes == -1) {
       // Custom
       isSelected = _intervalMinutes != null && ![30, 60, 120].contains(_intervalMinutes);
    } else {
       isSelected = _intervalMinutes == minutes;
    }

    return ListTile(
      title: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isSelected ? const Color(0xFF65C9F6) : (isDark ? Colors.white : const Color(0xFF1D3557)),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        if (minutes == -1) {
          _selectCustomInterval();
        } else {
          setState(() {
            _intervalDisplay = label; // This sets display to "30 Mnt" or "1 Hour" localized.
            _intervalMinutes = minutes;
            _generateNewSchedule();
          });
        }
      },
    );
  }

  Future<void> _selectCustomInterval() async {
    final localized = AppLocalizations.of(context)!;
    final TextEditingController controller = TextEditingController();
    int? customMinutes = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${localized.translate('interval')} (${localized.translate('mins')})'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "Contoh: 45"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(localized.translate('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text("Ok"),
          ),
        ],
      ),
    );

    if (customMinutes != null && customMinutes > 0) {
      setState(() {
        _intervalDisplay = "${customMinutes}m";
        _intervalMinutes = customMinutes;
        _generateNewSchedule();
      });
    }
  }

  Widget _buildTimePill(String text) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          color: isDark ? Colors.white : const Color(0xFF455A64),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildReminderItem(ReminderModel item, int index) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
           SizedBox(
            width: 24,
            height: 24,
            child: SvgPicture.asset(
              'assets/images/${item.icon}', 
               colorFilter: const ColorFilter.mode(Color(0xFF2fa2d6), BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.time,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1D3557),
                  ),
                ),
                Text(
                  _getDisplayStatus(item),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getDisplayStatus(item) == 'Selesai' 
                        ? const Color(0xFF65C9F6) 
                        : (_getDisplayStatus(item) == 'Terlewat' ? Colors.red.withOpacity(0.7) : const Color(0xFF90A4AE)),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _toggleStatus(index),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: item.status == 'Selesai' ? const Color(0xFF65C9F6).withOpacity(0.1) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.status == 'Selesai' ? Icons.check_circle : Icons.radio_button_unchecked,
                color: item.status == 'Selesai' ? const Color(0xFF65C9F6) : Colors.grey.withOpacity(0.5),
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _editAmount(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF333333) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${item.amount}ml",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1D3557),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () async {
              final reminder = _reminders[index];
              if (reminder.status == 'Selesai' && reminder.intakeId != null) {
                 await _waterService.deleteIntake(reminder.intakeId!);
                 setState(() {
                    _currentWater -= reminder.amount;
                    if (_currentWater < 0) _currentWater = 0;
                 });
              }

              setState(() {
                _reminders.removeAt(index);
                if (_reminders.isNotEmpty) {
                   int lastIdx = index > 0 ? index - 1 : 0;
                   _reminders = _reminderService.rebalanceReminders(_reminders, _goalWater, lastIdx);
                }
              });
              await _saveSettings();
            },
            child: SvgPicture.asset(
              'assets/images/ic_delete.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editAmount(int index) async {
    final localized = AppLocalizations.of(context)!;
    final TextEditingController controller = TextEditingController(text: _reminders[index].amount.toString());
    int? newAmount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit ML"), // "Edit ML" is okay or translate?
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: "ml"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(localized.translate('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: Text(localized.translate('save')),
          ),
        ],
      ),
    );

    if (newAmount != null && newAmount != _reminders[index].amount) {
      setState(() {
        _reminders[index].amount = newAmount;
        _reminders[index].icon = _reminderService.getIconForAmount(newAmount);
        _reminders = _reminderService.rebalanceReminders(_reminders, _goalWater, index);
      });
      _saveSettings(); // Save changes
    }
  }

  String _getDisplayStatus(ReminderModel item) {
    if (item.status == 'Selesai') return 'Selesai';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final timeParts = item.time.split(':');
    final rTime = DateTime(today.year, today.month, today.day, int.parse(timeParts[0]), int.parse(timeParts[1]));
    
    if (now.isAfter(rTime)) {
       return 'Terlewat';
    }
    return 'Nanti';
  }

  Future<void> _toggleStatus(int index) async {
    final reminder = _reminders[index];
    final bool isMarkingAsDone = reminder.status != 'Selesai';

    setState(() {
      _reminders[index].status = isMarkingAsDone ? 'Selesai' : 'Nanti';
    });

    try {
      if (isMarkingAsDone) {
        // Log intake
        final result = await _waterService.logIntake(reminder.amount, 'water');
        if (result != null) {
          if (result.containsKey('id')) {
             _reminders[index].intakeId = result['id'];
          } else if (result.containsKey('local_key')) {
             _reminders[index].intakeId = result['local_key']; // Use local key if offline
          }
        }
        
        setState(() {
          _currentWater += reminder.amount;
        });
      } else {
        // Undo log
        if (reminder.intakeId != null) {
          await _waterService.deleteIntake(reminder.intakeId!);
          _reminders[index].intakeId = null;
        }
        setState(() {
           _currentWater -= reminder.amount;
           if (_currentWater < 0) _currentWater = 0;
        });
      }
    } catch (e) {
      print("Error toggling status: $e");
    }

    await _saveSettings();
  }
}

class ArcProgressBarPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  ArcProgressBarPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    
    // Define the open arc (horseshoe)
    // Start from typically 135 degrees (bottom-left) to 45 degrees (bottom-right)
    // Creating a 270 degree arc, open at the bottom
    
    // In radians:
    // 0 is right (3 o'clock)
    // PI/2 is bottom (6 o'clock)
    // PI is left (9 o'clock)
    // 3PI/2 is top (12 o'clock)
    
    // We want to start around 135 degrees = 3PI/4 = 2.356 rad
    // And go for about 270 degrees = 3PI/2 = 4.712 rad
    
    const startAngle = 135 * (math.pi / 180);
    const sweepAngle = 270 * (math.pi / 180);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    // Draw Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // Draw Progress
    final progressSweepAngle = sweepAngle * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      progressSweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ArcProgressBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.trackColor != trackColor ||
           oldDelegate.progressColor != progressColor;
  }
}
