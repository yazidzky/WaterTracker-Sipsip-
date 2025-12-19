import 'package:flutter/material.dart';


enum NotificationType {
  loginSuccess,
  loginFailed,
  registerFailed,
  welcome,
  updateSuccess,
  updateFailed,
}

class CustomNotificationWidget extends StatelessWidget {
  final NotificationType type;

  const CustomNotificationWidget({
    super.key,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    String assetName;
    
    switch (type) {
      case NotificationType.loginSuccess:
        assetName = 'assets/images/notif_berhasillogin.png';
        break;
      case NotificationType.loginFailed:
        assetName = 'assets/images/notif_gagalmasuk.png';
        break;
      case NotificationType.registerFailed:
        assetName = 'assets/images/notif_gagaldaftar.png';
        break;
      case NotificationType.welcome:
        assetName = 'assets/images/notif_selamatdatang.png';
        break;
      case NotificationType.updateSuccess:
        assetName = 'assets/images/notif_update_berhasil.png'; // Fixed case
        break;
      case NotificationType.updateFailed:
        assetName = 'assets/images/notif_Update_gagal.png';
        break;
    }

    // Since the SVGs likely contain the entire design (banner + text),
    // we just display the SVG. We add a subtle shadow and border radius
    // if the SVG itself doesn't provide the "floating" feel, but
    // usually it's safer to wrap it in a Material to ensure it looks good
    // over other content.
    
    return Material(
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            height: 80, // Fix infinite height issue
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20), // Match the likely radius of the design
              child: Image.asset(
                assetName,
                fit: BoxFit.fill, // Ensure it fills the width
              ),
            ),
          ),
        ),
      ),
    );
  }
}
