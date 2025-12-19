import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:watertracker/l10n/app_localizations.dart';
import 'package:watertracker/providers/theme_provider.dart';
import 'package:watertracker/providers/user_provider.dart';
import 'package:watertracker/screens/settings_screen.dart';
import 'package:watertracker/services/notification_service.dart';
import 'package:watertracker/services/water_service.dart';
import 'package:watertracker/services/auth_service.dart';
import 'package:watertracker/services/intake_calculator.dart';
import 'package:watertracker/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Stats
  int _streak = 0;
  String _average = "0%";
  
  final WaterService _waterService = WaterService();
  final AuthService _authService = AuthService();
  bool _isStatsLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }
  
  Future<void> _fetchStats() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.fetchStats();
    } catch (e) {
      print("Error fetching stats: $e");
    } finally {
      if (mounted) setState(() => _isStatsLoading = false);
    }
  }

  Map<String, int> _calculateDailyIntakes(List<dynamic> stats) {
    Map<String, int> dailyIntakes = {};
    for (var item in stats) {
       String dateStr = item['date'].toString().substring(0, 10);
       int amount = item['amount'] ?? 0;
       dailyIntakes[dateStr] = (dailyIntakes[dateStr] ?? 0) + amount;
    }
    return dailyIntakes;
  }

  int _calculateStreak(Map<String, int> dailyIntakes) {
    if (dailyIntakes.isEmpty) return 0;
    int currentStreak = 0;
    DateTime date = DateTime.now();
    String todayStr = date.toIso8601String().substring(0, 10);
    
    if ((dailyIntakes[todayStr] ?? 0) > 0) {
      currentStreak++;
      date = date.subtract(const Duration(days: 1));
    } else {
       DateTime yesterday = date.subtract(const Duration(days: 1));
       String yesterdayStr = yesterday.toIso8601String().substring(0, 10);
       if ((dailyIntakes[yesterdayStr] ?? 0) > 0) {
          date = yesterday;
       }
    }
    
    if (currentStreak > 0 || (dailyIntakes[date.toIso8601String().substring(0, 10)] ?? 0) > 0) {
       while (true) {
         String dStr = date.toIso8601String().substring(0, 10);
         if ((dailyIntakes[dStr] ?? 0) > 0) {
            if (dStr != todayStr) currentStreak++; 
            date = date.subtract(const Duration(days: 1));
         } else {
           break;
         }
       }
    }
    return currentStreak;
  }

  String _calculateAverage(Map<String, int> dailyIntakes, int dailyGoal) {
    if (dailyIntakes.isEmpty || dailyGoal <= 0) return "0%";
    double totalConsumed = 0;
    int daysCount = dailyIntakes.length;
    dailyIntakes.forEach((key, value) => totalConsumed += value);
    
    double avgAmount = totalConsumed / daysCount;
    double avgPercent = (avgAmount / dailyGoal) * 100;
    return "${avgPercent.toInt()}%";
  }

  Future<void> _updateProfile(Map<String, dynamic> data) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    try {
      await userProvider.updateProfile(data);
      if (mounted) {
        NotificationService().showInAppNotification(context, NotificationType.updateSuccess);
      }
    } catch (e) {
      if (mounted) {
        NotificationService().showInAppNotification(context, NotificationType.updateFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final localized = AppLocalizations.of(context)!;
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    
    final Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF0F8FF);
    final Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1D3557);
    final Color subTextColor = isDark ? Colors.grey : const Color(0xFF455A64);

    final dailyGoal = userProvider.dailyGoal;
    final Map<String, int> dailyIntakes = _calculateDailyIntakes(userProvider.allStats);
    final int streak = _calculateStreak(dailyIntakes);
    final String average = _calculateAverage(dailyIntakes, dailyGoal);
    
    final String name = userProvider.name;
    final String email = userProvider.email;
    final String avatar = userProvider.avatar;
    final int age = userProvider.profile?['age'] ?? 0;
    final int weight = userProvider.profile?['weight'] ?? 0;
    final String genderValue = userProvider.profile?['gender'] ?? "Laki-laki";
    final String gender = genderValue == "Perempuan" ? localized.translate('female') : (genderValue == "Laki-laki" ? localized.translate('male') : genderValue);
    final String healthConditions = (userProvider.profile?['healthConditions'] as List?)?.join(', ') ?? "-";
    final String wakeTime = userProvider.wakeTime;
    final String sleepTime = userProvider.sleepTime;

    if (userProvider.isLoading && userProvider.profile == null) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF65C9F6), width: 2),
                        ),
                        child: ClipOval(child: _buildAvatarImage(avatar, 80)),
                      ),
                      GestureDetector(
                        onTap: _showEditProfileDialog,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Color(0xFF2fa2d6), shape: BoxShape.circle),
                          child: const Icon(Icons.edit, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 4),
                  Text(email, style: TextStyle(fontSize: 12, color: subTextColor)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildStatCard("$streak", localized.translate('streak'))),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard(average, localized.translate('average'))),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard("${(dailyGoal / 1000).toStringAsFixed(1)}L", localized.translate('dailyGoal'))),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  _buildDetailItem(localized.translate('dailyGoal'), "${(dailyGoal / 1000).toStringAsFixed(3).replaceAll('.', '.')}ml", "assets/images/ic_Daily goal.svg", borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
                  _buildDetailItem(localized.translate('gender'), gender, "assets/images/ic_Jenis Kelamin.svg", isEven: true),
                  _buildDetailItem(localized.translate('age'), "$age", "assets/images/ic_Usia.svg"),
                  _buildDetailItem(localized.translate('weight'), "${weight}kg", "assets/images/ic_Berat Badan.svg", isEven: true),
                  _buildDetailItem(localized.translate('bedTime'), sleepTime, "assets/images/ic_mulai_tidur.svg"),
                  _buildDetailItem(localized.translate('wakeUpTime'), wakeTime, "assets/images/ic_bangun_tidur.svg", isEven: true),
                  _buildDetailItem(localized.translate('healthCondition'), healthConditions, "assets/images/ic_kondisi_kesehatan.svg", isVertical: true, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildActionCard(title: localized.translate('editHydrationFactors'), iconPath: "assets/images/ic_faktor_dehidrasi.svg", onTap: _showEditHydrationDialog),
            const SizedBox(height: 12),
            _buildActionCard(title: localized.translate('settings'), iconPath: "assets/images/ic_pengaturan.svg", onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
            }),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                   TextButton(
                    onPressed: () async {
                      await _authService.logout();
                      if (mounted) {
                         Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
                      }
                    },
                    child: Text(localized.translate('logout'), style: const TextStyle(color: Color(0xFFE57373), fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _showDeleteAccountDialog,
                    child: Text(localized.translate('deleteAccount'), style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w400)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1D3557),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey : const Color(0xFF545454),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String iconPath,
    required VoidCallback onTap,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF333333) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SvgPicture.asset(
                iconPath,
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1D3557),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFB0BEC5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, String iconPath,
      {bool isEven = false, BorderRadius? borderRadius, bool isVertical = false}) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    
    final Color itemColor = isEven 
        ? (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5))
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);

    return Container(
      decoration: BoxDecoration(
        color: itemColor,
        borderRadius: borderRadius,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: isVertical ? CrossAxisAlignment.center : CrossAxisAlignment.center,
        children: [
          SvgPicture.asset(
            iconPath,
            width: 24,
            height: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: isVertical
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1D3557),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey : const Color(0xFF455A64),
                        ),
                      ),
                    ],
                  )
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1D3557),
                    ),
                  ),
          ),
          if (!isVertical)
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey : const Color(0xFF455A64),
              ),
            ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final localized = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String name = userProvider.name;
    final String email = userProvider.email;
    String selectedAvatar = userProvider.avatar;

    TextEditingController nameController = TextEditingController(text: name);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 24), 
                  Text(
                    localized.translate('editProfile'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1D3557),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Consumer<UserProvider>(
                        builder: (context, provider, child) {
                          return Column(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  GestureDetector(
                                    onTap: () => _showAvatarSelection(selectedAvatar, (newAsset) {
                                      selectedAvatar = newAsset;
                                      (context as Element).markNeedsBuild(); // Redraw Consumer
                                    }),
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF65C9F6),
                                          width: 2,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: _buildAvatarImage(selectedAvatar, 80),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF2fa2d6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _buildTextField(localized.translate('name'), nameController),
                              const SizedBox(height: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(localized.translate('email'), style: const TextStyle(fontSize: 12, color: Color(0xFF455A64))),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF333333) : const Color(0xFFF5F5F5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(email, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.grey)),
                                  )
                                ],
                              ),
                            ],
                          );
                        }
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 120,
                        child: StatefulBuilder(
                            builder: (context, setState) {
                              bool isHovered = false;
                              bool isPressed = false;
                              return MouseRegion(
                                onEnter: (_) => setState(() => isHovered = true),
                                onExit: (_) => setState(() => isHovered = false),
                                child: GestureDetector(
                                  onTapDown: (_) => setState(() => isPressed = true),
                                  onTapUp: (_) async { 
                                    setState(() => isPressed = false);
                                    await _updateProfile({
                                      'name': nameController.text,
                                      'avatar': selectedAvatar,
                                    });
                                    if (mounted) Navigator.pop(context);
                                  },
                                  onTapCancel: () => setState(() => isPressed = false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: (isHovered || isPressed) ? const Color(0xFF65C9F6) : const Color(0xFF2fa2d6),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: (isHovered || isPressed)
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF65C9F6).withOpacity(0.6),
                                                blurRadius: 15,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Text(localized.translate('save'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              );
                            }
                          ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditHydrationDialog() {
    final localized = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 20),
                    Text(
                      localized.translate('editHydrationFactors'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1D3557),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.grey, size: 20),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Consumer<UserProvider>(
                    builder: (context, provider, child) {
                      return Column(
                        children: [
                          _buildDialogItem(
                            localized.translate('dailyGoal'), 
                            "${(provider.dailyGoal / 1000).toStringAsFixed(3).replaceAll('.', '.')}ml", 
                            "assets/images/ic_Daily goal.svg",
                            isEven: false,
                            onTap: () => _editDailyGoal(),
                          ),
                          _buildDialogItem(
                            localized.translate('gender'), 
                            provider.profile?['gender'] ?? "Laki-laki", 
                            "assets/images/ic_Jenis Kelamin.svg", 
                            isEven: true,
                            onTap: () => _showGenderSelectionDialog(),
                          ),
                          _buildDialogItem(
                            localized.translate('age'), 
                            "${provider.profile?['age'] ?? 0}", 
                            "assets/images/ic_Usia.svg", 
                            isEven: false,
                            onTap: () => _editAge(),
                          ),
                          _buildDialogItem(
                            localized.translate('weight'), 
                            "${provider.profile?['weight'] ?? 0}kg", 
                            "assets/images/ic_Berat Badan.svg", 
                            isEven: true,
                            onTap: () => _editWeight(),
                          ),
                          _buildDialogItem(
                            localized.translate('bedTime'), 
                            provider.sleepTime, 
                            "assets/images/ic_mulai_tidur.svg", 
                            isEven: false,
                            onTap: () => _editTime(false),
                          ),
                          _buildDialogItem(
                            localized.translate('wakeUpTime'), 
                            provider.wakeTime, 
                            "assets/images/ic_bangun_tidur.svg", 
                            isEven: true,
                            onTap: () => _editTime(true),
                          ),
                          _buildDialogItem(
                            localized.translate('healthCondition'), 
                            (provider.profile?['healthConditions'] as List?)?.join(', ') ?? "-", 
                            "assets/images/ic_kondisi_kesehatan.svg", 
                            isEven: false, 
                            isVertical: true,
                            onTap: () => _showConditionSelectionDialog(),
                          ),
                        ],
                      );
                    }
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: SizedBox(
                  width: 110,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF65C9F6), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: Text(localized.translate('close'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF455A64),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1D3557)),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogItem(String label, String value, String iconPath, {bool isEven = false, bool isVertical = false, VoidCallback? onTap}) {
     final themeProvider = Provider.of<ThemeProvider>(context);
     final bool isDark = themeProvider.themeMode == ThemeMode.dark;
     
     return GestureDetector(
       onTap: onTap,
       child: Container(
        decoration: BoxDecoration(
          color: isEven 
              ? (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)) 
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: isVertical ? CrossAxisAlignment.center : CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconPath,
              width: 20,
              height: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isVertical
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1D3557),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.grey : const Color(0xFF455A64),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1D3557),
                      ),
                    ),
            ),
            if (!isVertical)
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey : const Color(0xFF455A64),
                ),
              ),
            if (onTap != null && isVertical) 
               const Padding(
                 padding: EdgeInsets.only(left: 8.0),
                 child: Icon(Icons.chevron_right, size: 16, color: Colors.grey),
               ),
          ],
        ),
      ),
     );
  }

  Future<void> _showConditionSelectionDialog() async {
    final localized = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String healthConditions = (userProvider.profile?['healthConditions'] as List?)?.join(', ') ?? "-";
    final int age = userProvider.profile?['age'] ?? 0;
    final String gender = userProvider.profile?['gender'] ?? "Laki-laki";
    final int weight = userProvider.profile?['weight'] ?? 0;

    final List<String> allConditions = [
      "Diabetes",
      "Dehidrasi",
      "Hipertensi",
      "Masalah Ginjal",
      "Asam Lambung",
      "Hamil/Menyusui",
    ];

    List<String> currentSelections = healthConditions.split(RegExp(r'[,|]\s*')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    
    String otherText = "";
    List<String> others = currentSelections.where((e) {
      return !allConditions.any((preset) => preset.toLowerCase() == e.toLowerCase());
    }).toList();
    
    if (others.isNotEmpty) {
      otherText = others.join(', ');
    }

    // Keep only presets in currentSelections for the checkbox logic
    currentSelections = currentSelections.where((e) {
      return allConditions.any((preset) => preset.toLowerCase() == e.toLowerCase());
    }).toList();

    TextEditingController otherController = TextEditingController(text: otherText);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F4F8), // Match image background
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 24),
                          Text(
                            localized.translate('selectCondition'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1D3557),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close, color: Colors.grey, size: 20),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Consumer<UserProvider>(
                              builder: (context, provider, child) {
                                return Column(
                                  children: List.generate(allConditions.length, (index) {
                                    String condition = allConditions[index];
                                    bool isSelected = currentSelections.contains(condition);
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            currentSelections.remove(condition);
                                          } else {
                                            currentSelections.add(condition);
                                          }
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: index % 2 != 0 
                                              ? (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)) 
                                              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                condition,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white : const Color(0xFF1D3557),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isSelected ? const Color(0xFF65C9F6) : Colors.grey.shade400,
                                                  width: 2,
                                                ),
                                                color: isSelected ? const Color(0xFF65C9F6) : Colors.transparent,
                                              ),
                                              child: isSelected
                                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              }
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              child: Row(
                                children: [
                                  Text(
                                    localized.translate('others'),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF1D3557),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      height: 36,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade400),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: TextField(
                                        controller: otherController,
                                        decoration: InputDecoration(
                                          hintText: localized.translate('writeHere'),
                                          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1D3557)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                           Set<String> finalSelection = {...currentSelections};
                           if (otherController.text.trim().isNotEmpty) {
                             List<String> extras = otherController.text.split(RegExp(r'[,|]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                             finalSelection.addAll(extras);
                           }
                           
                           // Get latest data from provider for calculation
                           final up = Provider.of<UserProvider>(context, listen: false);
                           final int currentAge = up.profile?['age'] ?? 0;
                           final String currentGender = up.profile?['gender'] ?? "Laki-laki";
                           final int currentWeight = up.profile?['weight'] ?? 0;

                           // Recalculate Goal
                           int newGoal = IntakeCalculator.calculateDailyGoal(
                             age: currentAge,
                             gender: currentGender,
                             weight: currentWeight,
                             conditions: finalSelection.toList(),
                           );

                           await _updateProfile({
                             'healthConditions': finalSelection.toList(),
                             'dailyGoal': newGoal,
                           });
                           if (mounted) Navigator.pop(context); 
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF65C9F6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(
                            localized.translate('continue'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showGenderSelectionDialog() async {
    final localized = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 24),
                        Text(
                          localized.translate('selectGender'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1D3557),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close, color: Colors.grey, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Consumer<UserProvider>(
                      builder: (context, provider, child) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildGenderOption(localized.translate('male'), "Laki-laki", "assets/images/btn_pria.svg", "assets/images/btn_hover_pria.svg", setDialogState),
                            const SizedBox(width: 32),
                            _buildGenderOption(localized.translate('female'), "Perempuan", "assets/images/btn_perempuan.svg", "assets/images/btn_hover_perempuan.svg", setDialogState),
                          ],
                        );
                      }
                    ),
                    const SizedBox(height: 32),
                     SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                           // Gender is updated in _buildGenderOption immediately
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF65C9F6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          elevation: 0,
                        ),
                        child: Text(
                          localized.translate('continue'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildGenderOption(String label, String value, String unselectedIcon, String selectedIcon, StateSetter setDialogState) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final String gender = userProvider.profile?['gender'] ?? "Laki-laki";
    final int age = userProvider.profile?['age'] ?? 0;
    final int weight = userProvider.profile?['weight'] ?? 0;
    final String healthConditions = (userProvider.profile?['healthConditions'] as List?)?.join(', ') ?? "-";

    bool isSelected = gender == value;
    return GestureDetector(
      onTap: () {
        // Recalculate Goal
        // Parse current conditions
        List<String> conds = healthConditions.split(', ').where((e) => e.isNotEmpty).toList();
        
        int newGoal = IntakeCalculator.calculateDailyGoal(
           age: age,
           gender: label,
           weight: weight,
           conditions: conds,
        );

         _updateProfile({
          'gender': value,
          'dailyGoal': newGoal,
        });
        setDialogState(() {});
      },
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              isSelected ? selectedIcon : unselectedIcon,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 12),
          Visibility(
            visible: isSelected,
            maintainSize: true, 
            maintainAnimation: true,
            maintainState: true,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF65C9F6), 
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editDailyGoal() async {
    final localized = AppLocalizations.of(context)!;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    TextEditingController controller = TextEditingController(text: userProvider.dailyGoal.toString());
    await showDialog(
      context: context,
      builder: (context) => _buildEditNumberDialog("${localized.translate('dailyGoal')} (ml)", controller, (val) {
        int? newVal = int.tryParse(val);
        if (newVal != null) {
          _updateProfile({'dailyGoal': newVal});
        }
      }),
    );
  }

  Future<void> _editAge() async {
    final localized = AppLocalizations.of(context)!;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final int age = userProvider.profile?['age'] ?? 0;
    final String gender = userProvider.profile?['gender'] ?? "Laki-laki";
    final int weight = userProvider.profile?['weight'] ?? 0;
    final String healthConditions = (userProvider.profile?['healthConditions'] as List?)?.join(', ') ?? "-";

    TextEditingController controller = TextEditingController(text: age.toString());
    await showDialog(
      context: context,
      builder: (context) => _buildEditNumberDialog(localized.translate('age'), controller, (val) {
        int? newVal = int.tryParse(val);
        if (newVal != null) {
          // Recalculate Goal
          List<String> conds = healthConditions.split(', ').where((e) => e.isNotEmpty).toList();
          int newGoal = IntakeCalculator.calculateDailyGoal(
             age: newVal,
             gender: gender,
             weight: weight,
             conditions: conds,
          );
          _updateProfile({
            'age': newVal,
            'dailyGoal': newGoal,
          });
        }
      }),
    );
  }

  Future<void> _editWeight() async {
    final localized = AppLocalizations.of(context)!;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final int age = userProvider.profile?['age'] ?? 0;
    final String gender = userProvider.profile?['gender'] ?? "Laki-laki";
    final int weight = userProvider.profile?['weight'] ?? 0;
    final String healthConditions = (userProvider.profile?['healthConditions'] as List?)?.join(', ') ?? "-";

    TextEditingController controller = TextEditingController(text: weight.toString());
    await showDialog(
      context: context,
      builder: (context) => _buildEditNumberDialog("${localized.translate('weight')} (kg)", controller, (val) {
        int? newVal = int.tryParse(val);
        if (newVal != null) {
          // Recalculate Goal
          List<String> conds = healthConditions.split(', ').where((e) => e.isNotEmpty).toList();
          int newGoal = IntakeCalculator.calculateDailyGoal(
             age: age,
             gender: gender,
             weight: newVal,
             conditions: conds,
          );
          _updateProfile({
            'weight': newVal,
            'dailyGoal': newGoal,
          });
        }
      }),
    );
  }

  Future<void> _editTime(bool isWakeTime) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    String current = isWakeTime ? userProvider.wakeTime : userProvider.sleepTime;
    List<String> parts = current.split(':');
    TimeOfDay initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
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

    if (picked != null) {
      String formatted = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      if (isWakeTime) {
        await userProvider.updateWakeTime(formatted);
      } else {
        await userProvider.updateSleepTime(formatted);
      }
    }
  }

  Widget _buildEditNumberDialog(String title, TextEditingController controller, Function(String) onSave) {
    final localized = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1D3557))),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF65C9F6), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(localized.translate('cancel'), style: const TextStyle(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    onSave(controller.text);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF65C9F6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(localized.translate('save'), style: const TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final localized = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/ic_hapusakun.png',
                width: 80,
                height: 80,
              ),
              const SizedBox(height: 16),
              Text(
                localized.translate('deleteAccountConfirmation'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1D3557),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                   Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF5F5F5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: Text(localized.translate('cancel'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                        Navigator.pop(context); // Close dialog
                        
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                        
                        final success = await _authService.deleteAccount();
                        
                        if (mounted) {
                          // Close loading dialog
                          Navigator.pop(context);
                          
                          if (success) {
                            // Navigate to Login and clear entire stack using root navigator
                            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => const LoginScreen()), 
                              (route) => false
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Gagal menghapus akun")),
                            );
                          }
                        }
                      },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE57373),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          elevation: 0,
                        ),
                        child: Text(localized.translate('delete'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey : const Color(0xFF545454),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1D3557),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 20,
      endIndent: 20,
      color: isDark ? Colors.white10 : Colors.grey.shade100,
    );
  }

  void _showAvatarSelection(String currentSelection, Function(String) onSelected) {
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
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                localized.translate('chooseAvatar'),
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1D3557),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _avatarChoice("avatar1.png", currentSelection, onSelected),
                  _avatarChoice("avatar2.png", currentSelection, onSelected),
                  _avatarChoice("avatar3.png", currentSelection, onSelected),
                  _avatarChoice("avatar4.png", currentSelection, onSelected),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _avatarChoice(String asset, String currentSelection, Function(String) onSelected) {
    return GestureDetector(
      onTap: () {
        onSelected(asset);
        Navigator.pop(context);
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: currentSelection == asset ? const Color(0xFF65C9F6) : Colors.grey.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: _buildAvatarImage(asset, 70),
        ),
      ),
    );
  }

  Widget _buildAvatarImage(String source, double size) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(
        source,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            'assets/images/avatar1.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          );
        },
      );
    } else if (source.endsWith('.svg')) {
      return SvgPicture.asset(
        'assets/images/$source',
        width: size,
        height: size,
        fit: BoxFit.cover,
        colorFilter: source == 'ic_profile.svg'
            ? const ColorFilter.mode(Color(0xFF65C9F6), BlendMode.srcIn)
            : null,
      );
    } else {
      return Image.asset(
        'assets/images/$source',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
           // Fallback if local asset is missing or name is wrong
           return Image.asset(
            'assets/images/avatar1.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          );
        },
      );
    }
  }
}

