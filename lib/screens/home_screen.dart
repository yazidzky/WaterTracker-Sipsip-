import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:watertracker/l10n/app_localizations.dart';
import 'package:watertracker/providers/theme_provider.dart';
import 'package:watertracker/providers/user_provider.dart';
import 'package:watertracker/services/notification_service.dart';
import 'package:watertracker/widgets/empty_state_widget.dart';
import 'package:watertracker/widgets/water_progress_painter.dart';
import 'package:watertracker/screens/home/change_cup_sheet.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedCupAmount = 200; 
  String _selectedAssetBase = 'Glass'; // Default

  @override
  void initState() {
    super.initState();
    // Initial fetch handled by UserProvider constructor or refreshAll
  }

  void _deleteIntake(String id) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    try {
      await userProvider.deleteIntake(id);
      if (mounted) {
        NotificationService().showInAppNotification(context, NotificationType.updateSuccess);
      }
    } catch (e) {
      if (mounted) {
        NotificationService().showInAppNotification(context, NotificationType.updateFailed);
      }
    }
  }

  void _addWater() async {
    final localized = AppLocalizations.of(context)!;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    try {
      await userProvider.logIntake(_selectedCupAmount, _selectedAssetBase);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localized.translate('failedToAdd'))),
        );
      }
    }
  }

  void _openChangeCupSheet() {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: ChangeCupSheet(
          currentAmount: _selectedCupAmount,
          currentAssetBase: _selectedAssetBase,
          onChanged: (newAmount, newAssetBase) {
            setState(() {
              _selectedCupAmount = newAmount;
              _selectedAssetBase = newAssetBase;
            });
            NotificationService().showInAppNotification(context, NotificationType.updateSuccess);
          },
        ),
      ),
    );
  }

  String _getGreetingKey() {
    var hour = DateTime.now().hour;
    if (hour < 11) {
      return 'goodMorning';
    } else if (hour < 15) {
      return 'goodAfternoon';
    } else if (hour < 18) {
      return 'goodEvening';
    } else {
      return 'goodNight';
    }
  }

  String _getIconAssetPath(String? type) {
    const validTypes = ['Glass', 'Bottle', 'Cup', 'Mug'];
    final iconType = type ?? 'Glass';
    
    if (validTypes.contains(iconType)) {
      return 'assets/images/${iconType}_Filled.svg';
    }
    return 'assets/images/Glass_Filled.svg';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final localized = AppLocalizations.of(context)!;
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    
    final Color textColor = isDark ? Colors.white : const Color(0xFF1D3557);
    final Color subTextColor = isDark ? Colors.white70 : const Color(0xFF1D3557).withOpacity(0.7);
    final Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final int currentWater = userProvider.currentWater;
    final int goalWater = userProvider.dailyGoal;
    final String userName = userProvider.name;
    final List<dynamic> history = userProvider.intakeHistory;
    final bool isLoading = userProvider.isLoading;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await userProvider.refreshAll();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localized.translate(_getGreetingKey()),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textColor),
                ),
                Text(
                  userName.isNotEmpty ? userName : 'User', 
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: textColor, letterSpacing: -0.5),
                ),
                const SizedBox(height: 50),
                Center(
                  child: SizedBox(
                    width: 360,
                    height: 380,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        SizedBox(
                          width: 320,
                          height: 320,
                          child: CustomPaint(
                            painter: WaterProgressPainter(
                              percentage: (currentWater / goalWater).clamp(0.0, 1.0),
                              backgroundColor: isDark ? const Color(0xFF333333) : Colors.grey.shade300,
                              progressColor: const Color(0xFF65C9F6),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 100,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$currentWater',
                                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Color(0xFF65C9F6), letterSpacing: -2),
                                  ),
                                  const Text(
                                    'ml',
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF65C9F6)),
                                  ),
                                ],
                              ),
                              Text(
                                '${localized.translate('of')} $goalWater ml',
                                style: TextStyle(fontSize: 16, color: subTextColor, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          bottom: 40,
                          child: GestureDetector(
                            onTap: _addWater,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(35),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 8))],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: SvgPicture.asset('assets/images/${_selectedAssetBase}_Add.svg', fit: BoxFit.contain),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('$_selectedCupAmount' 'ml', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 30,
                          right: 10,
                          child: GestureDetector(
                            onTap: _openChangeCupSheet,
                            child: Image.asset('assets/images/ic_switch.png', width: 70, height: 70, fit: BoxFit.contain),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(localized.translate('todayRecord'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 16),
                if (isLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()))
                else if (history.isEmpty)
                   const Padding(padding: EdgeInsets.all(20.0), child: EmptyStateWidget())
                else
                  ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    DateTime date = DateTime.parse(item['date']);
                    String timeStr = DateFormat('HH:mm').format(date.toLocal());
                    String id = item['_id'] ?? item['id'];

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                             width: 40,
                             alignment: Alignment.center,
                             child: SvgPicture.asset(_getIconAssetPath(item['type']), height: 28, colorFilter: const ColorFilter.mode(Color(0xFF65C9F6), BlendMode.srcIn)),
                          ),
                          const SizedBox(width: 16),
                          Text(timeStr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                          const Spacer(),
                          Text('${item['amount']}ml', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              if (id != null) _deleteIntake(id);
                            },
                            child: SvgPicture.asset('assets/images/ic_delete.svg', width: 20, height: 20),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
