import 'package:flutter/material.dart';

class CustomLoadingWidget extends StatelessWidget {
  const CustomLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/icon_looding.png',
            width: 100, // Adjust size as needed based on design
            height: 100,
          ),
          const SizedBox(height: 16),
          const Text(
            'Tunggu sebentar yaa...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold, // Matches design
              color: Color(0xFF1D3557), // Matches typical text color in app
            ),
          ),
        ],
      ),
    );
  }
}
