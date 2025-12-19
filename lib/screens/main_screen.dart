import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:watertracker/providers/theme_provider.dart';
import 'package:watertracker/screens/home_screen.dart';
import 'package:watertracker/screens/statistics_screen.dart';
import 'package:watertracker/screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const StatisticsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;
    
    // Theme Colors
    final Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF0F8FF);
    final Color navBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Main Content
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          
          // Floating Bottom Navigation Bar
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                constraints: const BoxConstraints(maxWidth: 400), // Prevent stretching on desktop
                height: 70,
                decoration: BoxDecoration(
                  color: navBarColor,
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20), // Add padding
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // Use spaceBetween
                  children: [
                    _buildBottomIcon(0, 'assets/images/nav_btn_ic_home.svg', isDark),
                    _buildBottomIcon(1, 'assets/images/nav_btn_ic_statistik.svg', isDark),
                    _buildBottomIcon(2, 'assets/images/nav_btn_ic_profile.svg', isDark),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomIcon(int index, String assetPath, bool isDark) {
    bool isActive = _currentIndex == index;
    final Color inactiveColor = isDark ? Colors.grey : const Color(0xFF1D3557);

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: isActive ? 80 : 50, // Reduced active width to minimize white space
        height: 55, // Consistent height for touch target
        decoration: isActive
            ? BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF65C9F6), Color(0xFF2FA2D6)],
                  begin: Alignment.centerLeft, // Horizontal gradient for wide pill
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(30), // Fully rounded ends for pill
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF65C9F6).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              )
            : null,
        padding: const EdgeInsets.all(15), // Adjust padding
        alignment: Alignment.center,
        child: SvgPicture.asset(
          assetPath,
          colorFilter: ColorFilter.mode(
            isActive ? Colors.white : inactiveColor,
            BlendMode.srcIn,
          ),
          width: 24, // Explicit icon size
          height: 24,
        ),
      ),
    );
  }
}
