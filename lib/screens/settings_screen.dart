import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:watertracker/l10n/app_localizations.dart';
import 'package:watertracker/providers/theme_provider.dart';
import 'package:watertracker/screens/reminder_screen.dart';
import 'package:watertracker/services/notification_service.dart';
import 'package:watertracker/services/user_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String selectedSound = 'Dering';
  
  final UserService _userService = UserService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final user = await _userService.getProfile();
      if (user != null && mounted) {
        setState(() {
          selectedSound = user['sound'] ?? 'Dering';
        });
      }
    } catch (e) {
      print("Error fetching settings: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(Map<String, dynamic> data) async {
    try {
      final updatedUser = await _userService.updateProfile(data);
      if (updatedUser != null && mounted) {
        if (data.containsKey('sound')) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('selected_sound', data['sound']);
          // Reschedule all notifications with new sound settings
          await NotificationService().rescheduleAllReminders();
        }
        
        setState(() {
          if (data.containsKey('sound')) selectedSound = updatedUser['sound'];
        });
        
        // Handle local state for Theme and Language via Provider
        if (data.containsKey('isDarkMode')) {
           final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
           await themeProvider.toggleTheme(data['isDarkMode']);
        }
        if (data.containsKey('language')) {
           final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
           // Convert language name to code
           String langCode = data['language'] == 'English' ? 'en' : 'id';
           await themeProvider.setLocale(langCode);
        }

        NotificationService().showInAppNotification(
          context, 
          NotificationType.updateSuccess
        );
      }
    } catch (e) {
      print("Error updating setting: $e");
      if (mounted) {
        NotificationService().showInAppNotification(
          context, 
          NotificationType.updateFailed
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localized = AppLocalizations.of(context)!;
    
    // UI Colors based on theme
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    final Color backgroundColor = isDark ? const Color(0xFF121212) : const Color(0xFFF0F8FF);
    final Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1D3557);
    final Color iconBgColor = isDark ? const Color(0xFF333333) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF4FC3F7)),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        title: Text(
          localized.translate('settings'),
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  children: [
                    // Banner with Pengingat
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ReminderScreen()),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Banner Image
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  'assets/images/banner_pengingat.png',
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            // Pengingat Text
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      localized.translate('reminder'),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Suara
                    _buildSettingCard(
                      context: context,
                      title: localized.translate('sound'),
                      subtitle: localized.translate(selectedSound.toLowerCase()), // Map value to localized key if needed
                      icon: Icons.notifications_outlined,
                      backgroundColor: cardColor,
                      textColor: textColor,
                      iconBgColor: iconBgColor,
                      onTap: () {
                        _showSoundDialog(context);
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Bahasa
                    _buildSettingCard(
                      context: context,
                      title: localized.translate('language'),
                      subtitle: themeProvider.locale.languageCode == 'en' ? 'English' : 'Indonesia',
                      icon: Icons.language,
                      backgroundColor: cardColor,
                      textColor: textColor,
                      iconBgColor: iconBgColor,
                      onTap: () {
                        _showLanguageDialog(context);
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    // Mode Gelap
                    _buildToggleCard(
                      context: context,
                      title: localized.translate('darkMode'),
                      icon: Icons.dark_mode_outlined,
                      value: themeProvider.themeMode == ThemeMode.dark,
                      backgroundColor: cardColor,
                      textColor: textColor,
                      iconBgColor: iconBgColor,
                      onChanged: (value) async {
                        // Immediately update local state via Provider for instant feedback
                        await themeProvider.toggleTheme(value);
                        // Sync with backend
                        _updateSetting({'isDarkMode': value});
                      },
                    ),
                  ],
                ),
              ),
              // Version
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  '${localized.translate('version')} 1.0',
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildSettingCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color textColor,
    required Color iconBgColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 24,
                color: textColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color backgroundColor,
    required Color textColor,
    required Color iconBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 24,
              color: textColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF4FC3F7),
          ),
        ],
      ),
    );
  }

  void _showSoundDialog(BuildContext context) {
    final localized = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1D3557);
    final Color dialogColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    
    showDialog(
      context: context,
      builder: (context) {
        String tempSelected = selectedSound;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: dialogColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            localized.translate('sound'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topRight,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.close,
                                color: Color(0xFF757575),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildDialogOption(
                    title: localized.translate('ring'),
                    isSelected: tempSelected == 'Dering',
                    backgroundColor: dialogColor,
                    textColor: textColor,
                    onTap: () {
                      setDialogState(() {
                        tempSelected = 'Dering';
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                       width: 140,
                       decoration: BoxDecoration(
                         boxShadow: [
                           BoxShadow(
                             color: const Color(0xFF4FC3F7).withOpacity(0.4),
                             blurRadius: 10,
                             offset: const Offset(0, 4),
                           ),
                         ],
                         borderRadius: BorderRadius.circular(25),
                       ),
                       child: ElevatedButton(
                        onPressed: () async {
                          String newValue = tempSelected;
                          _updateSetting({'sound': newValue});
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4FC3F7),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          localized.translate('save'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final localized = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1D3557);
    final Color dialogColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    showDialog(
      context: context,
      builder: (context) {
        String tempSelected = themeProvider.locale.languageCode == 'en' ? 'English' : 'Indonesia';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: dialogColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            localized.translate('language'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topRight,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(
                                Icons.close,
                                color: Color(0xFF757575),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildDialogOption(
                    title: 'Indonesia',
                    isSelected: tempSelected == 'Indonesia',
                    backgroundColor: dialogColor,
                    textColor: textColor,
                    onTap: () {
                      setDialogState(() {
                        tempSelected = 'Indonesia';
                      });
                    },
                  ),
                  _buildDialogOption(
                    title: 'English',
                    isSelected: tempSelected == 'English',
                    backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFFF0F0F0),
                    textColor: textColor,
                    onTap: () {
                      setDialogState(() {
                        tempSelected = 'English';
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                       width: 140,
                       decoration: BoxDecoration(
                         boxShadow: [
                           BoxShadow(
                             color: const Color(0xFF4FC3F7).withOpacity(0.4),
                             blurRadius: 10,
                             offset: const Offset(0, 4),
                           ),
                         ],
                         borderRadius: BorderRadius.circular(25),
                       ),
                       child: ElevatedButton(
                        onPressed: () async {
                           String newValue = tempSelected;
                           _updateSetting({'language': newValue});
                           Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4FC3F7),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          localized.translate('save'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogOption({
    required String title,
    required bool isSelected,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        width: double.infinity,
        decoration: BoxDecoration(
          color: backgroundColor,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF4FC3F7),
                  borderRadius: BorderRadius.circular(8),
                  shape: BoxShape.rectangle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF9E9E9E), // Grey border
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
