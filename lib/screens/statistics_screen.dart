import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:watertracker/l10n/app_localizations.dart';
import 'package:watertracker/providers/theme_provider.dart';
import 'package:watertracker/providers/user_provider.dart';
import 'package:watertracker/widgets/custom_loading_widget.dart';
import 'package:watertracker/widgets/water_progress_painter.dart';
import 'package:watertracker/services/water_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _toggleIndex = 0; // 0 for Week, 1 for Month

  // Weekly View State
  int _selectedDayIndex = 0; // 0 = Mon
  List<double> _weekData = [0, 0, 0, 0, 0, 0, 0];
  DateTime _currentWeekStart = DateTime.now();

  // Data for Weekly Details
  Map<int, List<dynamic>> _weeklyIntakesByDay = {};

  // Monthly View State
  DateTime _selectedMonthDate = DateTime.now(); // To track selected month/year
  List<double> _monthWeeksData = [0, 0, 0, 0, 0]; // 5 weeks
  int _selectedWeekIndex = 2; // Default to middle or current week

  // Shared Data
  List<dynamic> _rawIntakes = [];
  bool _isLoading = true;
  final WaterService _waterService = WaterService();

  // Aggregated Stats
  double _averageDaily = 0;
  String _progressText = "0/0"; // e.g. "20/30"

  // Habits (Percentages)
  int _morningPct = 0;
  int _afternoonPct = 0;
  int _nightPct = 0;

  // Highlights
  int _longestStreak = 0;
  int _bestHydration = 0;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    _currentWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    _selectedDayIndex = now.weekday - 1;
    if (_selectedDayIndex < 0) _selectedDayIndex = 6; 
    
    _initData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to UserProvider for changes in intake records
    final userProvider = Provider.of<UserProvider>(context);
    // If we are not loading and the current water has changed compared to last known, refresh
    // Note: This might be called too often, but since we use didChangeDependencies,
    // it's a safe place to react to provider changes. 
    // We can also use a specific listener if needed.
    if (!_isLoading) {
      _fetchData();
    }
  }

  Future<void> _initData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _fetchData();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchData() async {
    if (_toggleIndex == 0) {
      await _fetchWeeklyStats();
    } else {
      await _fetchMonthlyStats();
    }
  }

  Future<void> _fetchWeeklyStats() async {
    try {
      // End day should be Sunday 23:59:59
      DateTime end = _currentWeekStart.add(const Duration(days: 6, hours: 23, minutes: 59));
      final stats = await _waterService.getStats(start: _currentWeekStart, end: end);
      
      if (!mounted) return;

      List<double> newWeekData = [0, 0, 0, 0, 0, 0, 0];
      Map<int, List<dynamic>> newIntakesByDay = {};
      
      for(int i=0; i<7; i++) newIntakesByDay[i] = [];

      if (stats != null) {
        _rawIntakes = stats;
        for (var item in stats) {
          DateTime date = DateTime.parse(item['date']).toLocal();
          int dayIndex = date.weekday - 1; // 1 (Mon) -> 0
           
          if (dayIndex >= 0 && dayIndex < 7) {
            newWeekData[dayIndex] += (item['amount'] as num).toDouble();
            newIntakesByDay[dayIndex]!.add(item);
          }
        }
      }
      setState(() {
        _weekData = newWeekData;
        _weeklyIntakesByDay = newIntakesByDay;
        _calculateWeeklyAverage();
      });
    } catch (e) {
      print("Error fetching weekly: $e");
    }
  }

  Future<void> _fetchMonthlyStats() async {
    try {
      final stats = await _waterService.getMonthlyStats(
        month: _selectedMonthDate.month,
        year: _selectedMonthDate.year,
      );

      if (stats != null && mounted) {
        _rawIntakes = stats;
        _processMonthlyData(stats);
      }
    } catch (e) {
      print("Error fetching monthly: $e");
    }
  }

  void _processMonthlyData(List<dynamic> intakes) {
    if (!mounted) return;
    List<double> weeks = [0, 0, 0, 0, 0];
    Map<String, int> dailyTotals = {};
    int totalVolume = 0;
    int morning = 0;
    int afternoon = 0;
    int night = 0;
    int totalCount = 0;
    int maxVolume = 0;

    for (var item in intakes) {
      DateTime date = DateTime.parse(item['date']).toLocal();
      int amount = (item['amount'] as num).toInt();

      int day = date.day;
      int weekIndex = (day - 1) ~/ 7;
      if (weekIndex > 4) weekIndex = 4;
      weeks[weekIndex] += amount;

      String dateKey = DateFormat('yyyy-MM-dd').format(date);
      dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + amount;
      totalVolume += amount;

      int hour = date.hour;
      if (hour >= 4 && hour < 11) {
        morning++;
      } else if (hour >= 11 && hour < 18) {
        afternoon++;
      } else {
        night++;
      }
      totalCount++;
    }

    int daysInMonth = DateTime(_selectedMonthDate.year, _selectedMonthDate.month + 1, 0).day;
    int daysWithData = dailyTotals.length;
    _averageDaily = daysWithData > 0 ? totalVolume / daysWithData : 0;

    _progressText = "$daysWithData/$daysInMonth";

    if (totalCount > 0) {
      _morningPct = ((morning / totalCount) * 100).round();
      _afternoonPct = ((afternoon / totalCount) * 100).round();
      _nightPct = ((night / totalCount) * 100).round();
    } else {
      _morningPct = 0; _afternoonPct = 0; _nightPct = 0;
    }

    dailyTotals.forEach((key, value) {
      if (value > maxVolume) maxVolume = value;
    });
    _bestHydration = maxVolume;
    _longestStreak = _calculateLongestStreak(dailyTotals.keys.toList()..sort());

    setState(() {
      _monthWeeksData = weeks;
    });
  }

  int _calculateLongestStreak(List<String> sortedDates) {
    if (sortedDates.isEmpty) return 0;
    int maxStreak = 0;
    int currentStreak = 1;

    for (int i = 0; i < sortedDates.length - 1; i++) {
      DateTime d1 = DateTime.parse(sortedDates[i]);
      DateTime d2 = DateTime.parse(sortedDates[i + 1]);
      if (d2.difference(d1).inDays == 1) {
        currentStreak++;
      } else {
        if (currentStreak > maxStreak) maxStreak = currentStreak;
        currentStreak = 1;
      }
    }
    if (currentStreak > maxStreak) maxStreak = currentStreak;
    return maxStreak;
  }

  void _calculateWeeklyAverage() {
    double total = _weekData.reduce((a, b) => a + b);
    _averageDaily = total / 7;
    
    double todayIntake = 0;
    DateTime now = DateTime.now();
    if (now.difference(_currentWeekStart).inDays >= 0 && now.difference(_currentWeekStart).inDays < 7) {
       int todayIdx = now.weekday - 1;
       todayIntake = _weekData[todayIdx];
    }
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    int pct = userProvider.dailyGoal > 0 ? ((todayIntake / userProvider.dailyGoal) * 100).toInt() : 0;
    _progressText = "$pct%";
  }

  void _selectWeek() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentWeekStart.add(Duration(days: _selectedDayIndex)), // Highlight currently selected day
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF65C9F6),
            colorScheme: const ColorScheme.light(primary: Color(0xFF65C9F6)),
          ),
          child: child!,
        );
      },
      helpText: 'Pilih Tanggal',
    );
    
    if (picked != null && mounted) {
      // Find Monday of the selected week
      int difference = picked.weekday - DateTime.monday;
      DateTime startOfWeek = picked.subtract(Duration(days: difference));
      startOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day); // Normalize time
      
      setState(() {
        _currentWeekStart = startOfWeek;
        _selectedDayIndex = picked.weekday - 1; // Select the specific day picked (0-6)
      });
      _fetchData();
    }
  }

  void _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonthDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: const Color(0xFF65C9F6),
            colorScheme: const ColorScheme.light(primary: Color(0xFF65C9F6)),
          ),
          child: child!,
        );
      },
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedMonthDate = picked;
      });
      _fetchData();
    }
  }

  void _changeWeek(int offset) {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(Duration(days: offset * 7));
      _fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final localized = AppLocalizations.of(context)!;
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    
    // Theme Colors
    final Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF0F8FF);
    final Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1D3557);
    final Color subTextColor = isDark ? Colors.grey : const Color(0xFF1D3557).withOpacity(0.7);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CustomLoadingWidget()),
      );
    }

    final List<String> weekDays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final List<String> fullWeekDays = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title
              Center(
                child: Text(
                  localized.translate('statistics'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Toggle Button
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildToggleButton(0, localized.translate('weekly')),
                    _buildToggleButton(1, localized.translate('monthly')),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Date Navigation
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: textColor),
                      onPressed: () {
                         if (_toggleIndex == 0) _changeWeek(-1);
                         else {
                            setState(() => _selectedMonthDate = DateTime(_selectedMonthDate.year, _selectedMonthDate.month - 1));
                            _fetchData();
                         }
                      },
                    ),
                    Expanded(
                      child: Center(
                         child: _toggleIndex == 0 
                         ? GestureDetector(
                             onTap: _selectWeek,
                             child: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF2FA2D6)),
                                 const SizedBox(width: 8),
                                 Text(
                                   _isCurrentWeek() ? localized.translate('weekly') : "${DateFormat('d MMM', localized.locale.toString()).format(_currentWeekStart)} - ${DateFormat('d MMM', localized.locale.toString()).format(_currentWeekStart.add(const Duration(days: 6)))}",
                                   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                                 ),
                               ],
                             ),
                           )
                         : GestureDetector(
                            onTap: _selectMonth,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF2FA2D6)),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('MMMM yyyy', localized.locale.toString()).format(_selectedMonthDate),
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                                ),
                              ],
                            ),
                          ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: textColor),
                      onPressed: () {
                         if (_toggleIndex == 0) _changeWeek(1);
                         else {
                            setState(() => _selectedMonthDate = DateTime(_selectedMonthDate.year, _selectedMonthDate.month + 1));
                            _fetchData();
                         }
                      },
                    ),
                  ],
                ),
              ),

              // Chart Card with Summary
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_toggleIndex == 1)
                       Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Center(
                          child: Text(
                            localized.translate('monthly'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    SizedBox(
                      height: 180,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: _getDynamicMaxY(userProvider.dailyGoal.toDouble()),
                          barTouchData: BarTouchData(
                            enabled: true,
                            touchTooltipData: BarTouchTooltipData(
                              tooltipBgColor: Colors.transparent,
                              tooltipPadding: EdgeInsets.zero,
                              tooltipMargin: 8,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                return null;
                              },
                            ),
                            touchCallback: (FlTouchEvent event, barTouchResponse) {
                              if (!event.isInterestedForInteractions ||
                                  barTouchResponse == null ||
                                  barTouchResponse.spot == null) {
                                return;
                              }
                              if (event is FlTapUpEvent) {
                                setState(() {
                                  if (_toggleIndex == 0) {
                                    _selectedDayIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                                  } else {
                                    // Monthly view - select week
                                    _selectedWeekIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                                  }
                                });
                              }
                            },
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (double value, TitleMeta meta) {
                                  if (_toggleIndex == 1) {
                                     return SideTitleWidget(
                                       axisSide: meta.axisSide,
                                       child: Text(
                                          "M${value.toInt() + 1}", 
                                          style: const TextStyle(color: Colors.grey, fontSize: 10)
                                       ),
                                     );
                                  }
                                  int index = value.toInt();
                                  if (index >= 0 && index < weekDays.length) {
                                    bool isSelected = index == _selectedDayIndex;
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(
                                        weekDays[index],
                                        style: TextStyle(
                                          color: isSelected ? const Color(0xFF2FA2D6) : Colors.grey,
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox();
                                },
                              ),
                            ),
                            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: const FlGridData(show: false),
                          barGroups: _toggleIndex == 0
                              ? List.generate(7, (index) => _makeBarGroup(
                                  index,
                                  _weekData[index],
                                  index == _selectedDayIndex,
                                  20,
                                  _getDynamicMaxY(userProvider.dailyGoal.toDouble()),
                                ))
                              : List.generate(5, (index) => _makeBarGroup(
                                  index,
                                  _monthWeeksData[index],
                                  index == _selectedWeekIndex, 
                                  30,
                                  _getDynamicMaxY(userProvider.dailyGoal.toDouble()),
                                )),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Summary Box
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF333333) : const Color(0xFFE0F7FA).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(_toggleIndex == 0 ? localized.translate('dailyAverage') : localized.translate('dailyAverage'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text('${_averageDaily.toInt()}ml', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w900)),
                            ],
                          ),
                          Column(
                            children: [
                              Text(_toggleIndex == 0 ? localized.translate('completion') : localized.translate('completionRate'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(_progressText, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              if (_toggleIndex == 0) ...[
                // WEEKLY DETAIL SECTION
                Text(
                  "Detail ${fullWeekDays[_selectedDayIndex]}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),
                // Unified Detail Container (Arc Progress + Intake List)
                _buildUnifiedDetailCard(_selectedDayIndex, localized, isDark, userProvider.dailyGoal),
              ] else ...[
                 // MONTHLY HABITS & HIGHLIGHTS
                 Text(localized.translate('habits'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                 const SizedBox(height: 12),
                 Row(
                   children: [
                     _buildHabitPill(localized.translate('morning'), _morningPct, isDark ? Colors.orange.withOpacity(0.2) : Colors.orange.shade100, Colors.orange),
                     const SizedBox(width: 10),
                     _buildHabitPill(localized.translate('afternoon'), _afternoonPct, isDark ? Colors.yellow.withOpacity(0.2) : Colors.yellow.shade100, Colors.orangeAccent),
                     const SizedBox(width: 10),
                     _buildHabitPill(localized.translate('night'), _nightPct, isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade100, Colors.blue),
                   ],
                 ),
                 const SizedBox(height: 20),
                 Text(localized.translate('highlights'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                 const SizedBox(height: 12),
                 Row(
                   children: [
                     Expanded(child: _buildHighlightCard(localized.translate('longestStreak'), "$_longestStreak hari", "assets/images/ic_fire.svg", isDark ? const Color(0xFF4E342E) : const Color(0xFFFFCCBC), isDark)),
                     const SizedBox(width: 12),
                     Expanded(child: _buildHighlightCard(localized.translate('bestHydration'), "${(_bestHydration / 1000).toStringAsFixed(3).replaceFirst('.', '.')}ml", "assets/images/ic_star.svg", isDark ? const Color(0xFF424242) : const Color(0xFFFFF9C4), isDark)),
                   ],
                 ),
              ],
              const SizedBox(height: 100), // Extra space for scrolling to analysis section
            ],
          ),
        ),
      ),
    );
  }

  bool _isCurrentWeek() {
    DateTime now = DateTime.now();
    DateTime startOfThisWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return _currentWeekStart.isAtSameMomentAs(startOfThisWeek);
  }

  double _calculateDayProgress(int dayIndex, int dailyGoal) {
    if (dailyGoal == 0) return 0;
    return (_weekData[dayIndex] / dailyGoal).clamp(0.0, 1.0);
  }

  String _getIconAssetPath(String? type) {
    // List of available icon types
    const validTypes = ['Glass', 'Bottle', 'Cup', 'Mug'];
    final iconType = type ?? 'Glass';
    
    // Use Glass as fallback if type is not in valid list
    if (validTypes.contains(iconType)) {
      return 'assets/images/${iconType}_Filled.svg';
    }
    return 'assets/images/Glass_Filled.svg';
  }


  Widget _buildUnifiedDetailCard(int dayIndex, AppLocalizations localized, bool isDark, int dailyGoal) {
    List<dynamic> intakes = _weeklyIntakesByDay[dayIndex] ?? [];
    
    // Sort intakes
    intakes.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          // Arc Progress Section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Arc Progress Indicator
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CustomPaint(
                    painter: WaterProgressPainter(
                      percentage: _calculateDayProgress(dayIndex, dailyGoal),
                      backgroundColor: const Color(0xFFE8F4F8),
                      progressColor: const Color(0xFF65C9F6),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${_weekData[dayIndex].toInt()}",
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF2FA2D6)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${localized.translate('of')} ${dailyGoal}ml",
                        style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Text(
                  "${(_calculateDayProgress(dayIndex, dailyGoal) * 100).toInt()}%",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1D3557)),
                ),
              ],
            ),
          ),
          
          // Intake List Section
          if (intakes.isNotEmpty) ...[
            ...intakes.asMap().entries.map((entry) {
              final item = entry.value;
              final isLast = entry.key == intakes.length - 1;
              DateTime date = DateTime.parse(item['date']).toLocal();
              
              return Column(
                children: [
                  // Divider
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey.shade200,
                    indent: 20,
                    endIndent: 20,
                  ),
                  // Intake Item
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, isLast ? 20 : 16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          alignment: Alignment.center,
                          child: SvgPicture.asset(
                            _getIconAssetPath(item['type']),
                            height: 28,
                            colorFilter: const ColorFilter.mode(
                              Color(0xFF65C9F6), BlendMode.srcIn),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          DateFormat('H:mm').format(date),
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: isDark ? Colors.white : const Color(0xFF1D3557)),
                        ),
                        const Spacer(),
                        Text(
                          "${item['amount']}ml",
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1D3557), fontWeight: FontWeight.w600, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ] else ...[
            // Empty state
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.shade200,
              indent: 20,
              endIndent: 20,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/icon_databelumada.png',
                    width: 80,
                    height: 80,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    localized.translate('noWaterRecord'),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }




  Widget _buildToggleButton(int index, String text) {
    final bool isSelected = _toggleIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_toggleIndex != index) {
            setState(() {
              _toggleIndex = index;
            });
            _fetchData();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF65C9F6) : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF65C9F6), Color(0xFF2FA2D6)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1D3557)),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  double _getDynamicMaxY(double dailyGoal) {
    double maxData = 0;
    if (_toggleIndex == 0) {
      if (_weekData.isNotEmpty) {
        maxData = _weekData.reduce((a, b) => a > b ? a : b);
      }
    } else {
      if (_monthWeeksData.isNotEmpty) {
        maxData = _monthWeeksData.reduce((a, b) => a > b ? a : b);
      }
    }
    
    // Ensure we at least show up to daily goal if data is small
    double baseline = dailyGoal; 
    if (baseline == 0) baseline = 2500;
    
    double highest = maxData > baseline ? maxData : baseline;
    // Add 20% buffer
    return highest * 1.2;
  }

  BarChartGroupData _makeBarGroup(
    int x,
    double y,
    bool isSelected,
    double width,
    double maxY,
  ) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: width,
          borderRadius: BorderRadius.circular(width / 2),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: maxY,
            color: const Color(0xFFF5F5F5),
          ),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF65C9F6), Color(0xFF2FA2D6)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                )
              : const LinearGradient(
                  colors: [Color(0xFF90A4AE), Color(0xFF607D8B)], // Darker slate
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
        ),
      ],
    );
  }

  Widget _buildHabitPill(
    String label,
    int pct,
    Color bgColor,
    Color iconColor,
  ) {
    final localized = AppLocalizations.of(context)!;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4), // Reduced horizontal padding
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              label == (localized.translate('morning'))
                  ? Icons.wb_sunny_outlined
                  : (label == localized.translate('afternoon')
                        ? Icons.wb_sunny
                        : Icons.nights_stay_outlined),
              size: 14, // Slightly smaller icon
              color: iconColor,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "$label $pct%",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF455A64),
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightCard(
    String title,
    String value,
    String iconAsset,
    Color iconBg,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: title.contains("Streak")
                    ? const Icon(Icons.local_fire_department, color: Colors.orange, size: 18)
                    : const Icon(Icons.star, color: Colors.orangeAccent, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1D3557)),
          ),
        ],
      ),
    );
  }
}
