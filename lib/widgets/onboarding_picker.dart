import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:watertracker/providers/theme_provider.dart';

class OnboardingPicker extends StatefulWidget {
  final int minValue;
  final int maxValue;
  final int initialValue;
  final String suffix;
  final Function(int) onChanged;

  const OnboardingPicker({
    super.key,
    required this.minValue,
    required this.maxValue,
    required this.initialValue,
    this.suffix = '',
    required this.onChanged,
  });

  @override
  State<OnboardingPicker> createState() => _OnboardingPickerState();
}

class _OnboardingPickerState extends State<OnboardingPicker> {
  late FixedExtentScrollController _controller;
  late int _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialValue;
    _controller = FixedExtentScrollController(
      initialItem: widget.initialValue - widget.minValue,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isDark = themeProvider.themeMode == ThemeMode.dark;

    return SizedBox(
      height: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Selection Indicator Lines
          Container(
            height: 60,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, width: 1),
                bottom: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300, width: 1),
              ),
            ),
          ),
          
          ListWheelScrollView.useDelegate(
            controller: _controller,
            itemExtent: 60,
            perspective: 0.005,
            diameterRatio: 1.2,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) {
              final value = widget.minValue + index;
              setState(() {
                _selectedValue = value;
              });
              widget.onChanged(value);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.maxValue - widget.minValue + 1,
              builder: (context, index) {
                final value = widget.minValue + index;
                final isSelected = value == _selectedValue;
                
                return Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        value.toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: isSelected ? 32 : 24,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? const Color(0xFF65C9F6) : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                        ),
                      ),
                      if (isSelected && widget.suffix.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          widget.suffix,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF65C9F6),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
