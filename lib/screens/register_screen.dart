import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:watertracker/l10n/app_localizations.dart';
import 'package:watertracker/providers/theme_provider.dart';
import 'package:watertracker/services/auth_service.dart';
import 'package:watertracker/screens/onboarding/onboarding_screen.dart';
import 'package:watertracker/services/notification_service.dart';
import 'package:watertracker/widgets/custom_notification_widget.dart';

class RegisterScreen extends StatefulWidget {
  final Map<String, dynamic>? googleData;
  
  const RegisterScreen({super.key, this.googleData});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _obscurePassword = true;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // No auto-registration - user must click Google button
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleGoogleRegister() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.loginWithGoogle();

      if (user != null && mounted) {
        // Check if user needs registration (new user)
        if (user['needsRegistration'] == true) {
          // New Google user - register them
          final googleData = user['googleData'];
          final password = 'google_${DateTime.now().millisecondsSinceEpoch}_${(googleData['email'].hashCode).abs()}';
          
          final registeredUser = await _authService.register(
            googleData['name'],
            googleData['email'],
            password,
          );
          
          if (registeredUser != null && mounted) {
            NotificationService().showInAppNotification(context, NotificationType.welcome);
            
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OnboardingScreen(),
                  ),
                );
              }
            });
          }
        } else {
          // Existing user - show error, they should use login screen
          NotificationService().showInAppNotification(context, NotificationType.registerFailed);
        }
      }
    } catch (e) {
      if (mounted) {
        NotificationService().showInAppNotification(context, NotificationType.registerFailed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleRegister() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final password = _passwordController.text;
      
      final user = await _authService.register(
        _nameController.text,
        _emailController.text,
        password,
      );

      if (user != null && mounted) {
        // Show Welcome or Login Success notification
        NotificationService().showInAppNotification(context, NotificationType.welcome);
        
        Future.delayed(const Duration(seconds: 1), () {
           if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const OnboardingScreen(),
              ),
            );
           }
        });
      }
    } catch (e) {
      if (mounted) {
        NotificationService().showInAppNotification(context, NotificationType.registerFailed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localized = AppLocalizations.of(context)!;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_login_register_splassscreen.png',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Center(
             child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
               child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top Card: Register Form
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      localized.translate('register'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1D3557),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildLabel(localized.translate('enterName')),
                    const SizedBox(height: 8),
                    _buildTextField(
                      hintText: localized.translate('howCanICallYou'),
                      controller: _nameController,
                    ),
                    const SizedBox(height: 16),
                    _buildLabel(localized.translate('email')),
                    const SizedBox(height: 8),
                    _buildTextField(
                      hintText: localized.translate('enterEmail'),
                      controller: _emailController,
                    ),
                    const SizedBox(height: 16),
                    _buildLabel(localized.translate('password')),
                    const SizedBox(height: 8),
                    _buildTextField(
                      hintText: localized.translate('enterPassword'),
                      isPassword: true,
                      obscureText: _obscurePassword,
                      controller: _passwordController,
                      onToggleVisibility: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF65C9F6), Color(0xFF2FA2D6)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF65C9F6).withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                          localized.translate('register'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      localized.translate('acceptTerms'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 10, // Small text
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Bottom Card: Social & Navigate
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                  children: [
                    OutlinedButton(
                      onPressed: _isLoading ? null : _handleGoogleRegister,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/images/btn_google.svg',
                            height: 24,
                            width: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            localized.translate('continueWithGoogle'),
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          localized.translate('alreadyHaveAccount') + ' ',
                          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context); // Go back to login
                          },
                          child: Text(
                            localized.translate('login'),
                            style: const TextStyle(
                              color: Color(0xFF2FA2D6),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            ),
             ),
           )
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;

    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : const Color(0xFF1D3557),
      ),
    );
  }

  Widget _buildTextField({
    required String hintText,
    bool isPassword = false,
    bool obscureText = false,
    TextEditingController? controller,
    VoidCallback? onToggleVisibility,
  }) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF333333) : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? obscureText : false,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade500, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: isPassword
              ? IconButton(
                  icon: SvgPicture.asset(
                    obscureText ? 'assets/images/btn_menutup.svg' : 'assets/images/btn_melihat.svg',
                    // width: 20, // Optional: add size if needed
                    // height: 20,
                    colorFilter: isDark ? const ColorFilter.mode(Colors.white, BlendMode.srcIn) : null,
                  ),
                  onPressed: onToggleVisibility,
                )
              : null,
        ),
      ),
    );
  }
}
