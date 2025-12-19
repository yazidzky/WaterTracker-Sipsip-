import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:watertracker/l10n/app_localizations.dart';
import 'package:watertracker/providers/theme_provider.dart';
import 'package:watertracker/screens/main_screen.dart';
import 'package:watertracker/widgets/onboarding_picker.dart';
import 'package:watertracker/services/user_service.dart';
import 'package:watertracker/services/intake_calculator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Form Data
  String _gender = 'Male'; // Male, Female
  int _age = 20;
  int _weight = 60; // Weight is still needed
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _sleepTime = const TimeOfDay(hour: 22, minute: 0);
  bool _hasHealthCondition = false; // false = Tidak, true = Ya
  final Set<String> _selectedConditions = {};
  String _otherCondition = '';

  final int _totalPages = 6;

  Future<void> _nextPage() async {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Finish Onboarding
      // Calculate Goal
      final int calculatedGoal = IntakeCalculator.calculateDailyGoal(
        age: _age,
        gender: _gender,
        weight: _weight,
        conditions: _hasHealthCondition ? _selectedConditions.toList() : [],
      );

      // Prepare Data
      // Note: Backend expects specific fields. 
      // Assuming 'healthConditions' is a List<String> or similar in backend update logic.
      // Based on ProfileScreen read: healthConditions is handled as List? join ', ' for display.
      // UserService.updateProfile takes Map<String, dynamic>.
      
      final Map<String, dynamic> profileData = {
        'age': _age,
        'gender': _gender == 'Male' ? 'Laki-laki' : 'Perempuan', // Mapping to indonesian as seen in ProfileScreen
        'weight': _weight,
        'dailyGoal': calculatedGoal,
        'healthConditions': _hasHealthCondition ? _selectedConditions.toList() : [],
        // Timings if needed by backend, otherwise just local preference or separate endpoint? 
        // For now not saving timings to backend as ProfileScreen comment said they aren't in model yet
      };

      try {
        await UserService().updateProfile(profileData);
        
        if (mounted) {
           Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      } catch (e) {
        // Handle error (maybe show snackbar)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menyimpan data: $e')),
          );
        }
      } 
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Progress calculation (based on pages + 1 initial state 0.2)
    double progress = (_currentPage + 1) / _totalPages;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localized = AppLocalizations.of(context)!;
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    
    final Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF0F8FF);
    final Color textColor = isDark ? Colors.white : const Color(0xFF1D3557);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF65C9F6)),
                  minHeight: 6,
                ),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe to enforce buttons
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildGenderPage(),
                  _buildAgePage(),
                  _buildWeightPage(),
                  _buildTimePage(
                    title: localized.translate('whatTimeWakeUp'),
                    time: _wakeTime,
                    onTimeChanged: (newTime) => setState(() => _wakeTime = newTime),
                  ),
                  _buildTimePage(
                    title: localized.translate('whatTimeSleep'),
                    time: _sleepTime,
                    onTimeChanged: (newTime) => setState(() => _sleepTime = newTime),
                  ),
                  _buildHealthConditionPage(),
                ],
              ),
            ),

            // Bottom Navigation
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  IconButton(
                    onPressed: _prevPage,
                    icon: Icon(Icons.arrow_back_ios_new, color: textColor),
                  ),
                  
                  // Next Button
                  GestureDetector(
                    onTap: _nextPage,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Color(0xFF65C9F6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 1: Gender ---
  Widget _buildGenderPage() {
    final localized = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1D3557);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            localized.translate('whatIsYourGender'),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildGenderOption('Male', localized.translate('male')),
              const SizedBox(width: 40),
              _buildGenderOption('Female', localized.translate('female')),
            ],
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildGenderOption(String value, String label) {
    bool isSelected = _gender == value;
    String assetName = value == 'Male' ? 'btn_pria' : 'btn_perempuan';
    // Use hover version if selected
    if (isSelected) {
      if (value == 'Male') assetName = 'btn_hover_pria';
      if (value == 'Female') assetName = 'btn_hover_perempuan';
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _gender = value;
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
             // Assuming SVG takes care of the full visual state (bg + icon)
            child: SvgPicture.asset(
              'assets/images/$assetName.svg',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 16),
          // Use Opacity or Visibility
          // User asked for "only appears when clicked" (muncul ketika di klik)
          Visibility(
            visible: isSelected,
            maintainSize: true, 
            maintainAnimation: true,
            maintainState: true,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF65C9F6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Step 2: Age ---
  Widget _buildAgePage() {
    final localized = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1D3557);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            localized.translate('howOldAreYou'),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const Spacer(),
          OnboardingPicker(
            minValue: 10,
            maxValue: 100,
            initialValue: _age,
            onChanged: (val) => setState(() => _age = val),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  // --- Step 3: Weight ---
  Widget _buildWeightPage() {
    final localized = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1D3557);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            localized.translate('whatIsYourWeight'),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const Spacer(),
          OnboardingPicker(
            minValue: 30,
            maxValue: 150,
            initialValue: _weight,
            suffix: 'kg',
            onChanged: (val) => setState(() => _weight = val),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  // --- Step 4 & 5: Time ---
  Widget _buildTimePage({
    required String title,
    required TimeOfDay time,
    required Function(TimeOfDay) onTimeChanged,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1D3557);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Hour Picker
              Expanded(
                child: OnboardingPicker(
                  minValue: 0,
                  maxValue: 23,
                  initialValue: time.hour,
                  onChanged: (val) {
                    onTimeChanged(TimeOfDay(hour: val, minute: time.minute));
                  },
                ),
              ),
              const Text(
                ':',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF65C9F6),
                ),
              ),
              // Minute Picker
              Expanded(
                child: OnboardingPicker(
                  minValue: 0,
                  maxValue: 59,
                  initialValue: time.minute,
                  onChanged: (val) {
                    onTimeChanged(TimeOfDay(hour: time.hour, minute: val));
                  },
                ),
              ),
            ],
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  // --- Step 5: Health Condition ---
  Widget _buildHealthConditionPage() {
    final localized = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1D3557);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            localized.translate('doYouHaveHealthCondition'),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const Spacer(),
          Column(
            children: [
              _buildHealthOption(true, localized.translate('yes')),
              const SizedBox(height: 16),
              _buildHealthOption(false, localized.translate('no')),
            ],
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildHealthOption(bool value, String label) {
    bool isSelected = _hasHealthCondition == value;
    
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _hasHealthCondition = value;
        });
        // Show modal if "Ya" is selected
        if (value == true) {
          _showHealthConditionModal();
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF65C9F6) : (isDark ? Colors.white24 : Colors.grey.shade300),
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color(0xFF65C9F6).withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
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
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? (isDark ? Colors.white : const Color(0xFF1D3557)) : (isDark ? Colors.grey : Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHealthConditionModal() {
    final localized = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;

    final TextEditingController otherController = TextEditingController(text: _otherCondition);
    final List<String> allConditions = [
      localized.translate('diabetes'),
      localized.translate('dehydration'),
      localized.translate('hypertension'),
      localized.translate('kidneyIssue'),
      localized.translate('gastricAcid'),
      localized.translate('pregnantBreastfeeding'),
    ];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
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

                    // List Items
                    ...List.generate(allConditions.length, (index) {
                      String condition = allConditions[index];
                      bool isSelected = _selectedConditions.contains(condition);
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              _selectedConditions.remove(condition);
                            } else {
                              _selectedConditions.add(condition);
                            }
                          });
                          setState(() {});
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: index % 2 != 0 ? (isDark ? const Color(0xFF333333) : const Color(0xFFF0F0F0)) : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
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
                              // Custom Circular Checkbox
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
                    
                    // Lainnya Option
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          Text(
                            "${localized.translate('others')}:",
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
                                style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
                                decoration: InputDecoration(
                                  hintText: localized.translate('writeHere'),
                                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onChanged: (value) {
                                  _otherCondition = value;
                                  // Logic to handle auto-selecting 'Lainnya' could be added but simpler to just store text
                                  // Design doesn't explicitly show 'Lainnya' checklist item being separate from text field in input logic from ProfileScreen, 
                                  // but here `_selectedConditions` is a Set. 
                                  // We can manage it, but user didn't ask for complex logic, just UI match.
                                  // I'll stick to text field input updating variable.
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Button
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            // If 'Lainnya' text is present, maybe enable it or just keep data
                            Navigator.pop(context);
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
}
