import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ChangeCupSheet extends StatefulWidget {
  final int currentAmount;
  final String currentAssetBase;
  final Function(int, String) onChanged;

  const ChangeCupSheet({
    super.key,
    required this.currentAmount,
    required this.currentAssetBase,
    required this.onChanged,
  });

  @override
  State<ChangeCupSheet> createState() => _ChangeCupSheetState();
}

class _ChangeCupSheetState extends State<ChangeCupSheet> {
  late int _selectedAmount;
  late String _selectedAssetBase;
  late double _sliderValue;
  final TextEditingController _customAmountController = TextEditingController();

  final List<Map<String, dynamic>> _options = [
    {'amount': 100, 'asset': 'Cup', 'label': '100ml'},
    {'amount': 150, 'asset': 'Mug', 'label': '150ml'},
    {'amount': 200, 'asset': 'Glass', 'label': '200ml'},
    {'amount': 400, 'asset': 'Bottle', 'label': '400ml'},
    {'amount': -1, 'asset': 'Jug', 'label': 'Atur jumlah'}, // -1 for custom
  ];

  @override
  void initState() {
    super.initState();
    _selectedAmount = widget.currentAmount;
    _selectedAssetBase = widget.currentAssetBase;
    _sliderValue = widget.currentAmount.toDouble();
    _customAmountController.text = widget.currentAmount.toString();
  }

  void _handleOptionSelect(int amount, String asset) {
    setState(() {
      _selectedAssetBase = asset;
      // If choosing pre-set, update amount. If "Atur jumlah", keep current slider value
      if (amount != -1) {
        _selectedAmount = amount;
        _sliderValue = amount.toDouble();
        _customAmountController.text = amount.toString();
      }
    });
  }

  void _handleSave() {
    widget.onChanged(_sliderValue.toInt(), _selectedAssetBase);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 550),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Header
          const Text(
            'Ganti gelas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D3557),
            ),
          ),
          const SizedBox(height: 24),

          // Grid Options
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: _options.length,
            itemBuilder: (context, index) {
              final option = _options[index];
              final isSelected = option['asset'] == _selectedAssetBase;
              
              // Special handling for labels to match design (image below icon)
              return GestureDetector(
                onTap: () => _handleOptionSelect(option['amount'], option['asset']),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isSelected && option['asset'] == 'Glass')
                           // Selected highlight specific to design (blue fill if needed, or just bold label)
                           // Design shows only label bolding/color change, or potentially icon change
                           Container(), 
                        
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: SvgPicture.asset(
                            // Special case for "Atur jumlah" (amount -1) to use Add icon
                            option['amount'] == -1
                                ? 'assets/images/icon_addjumlah.svg'
                                : (isSelected
                                    ? 'assets/images/${option['asset']}_Filled.svg'
                                    : 'assets/images/${option['asset']}_Empty.svg'),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option['label'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? const Color(0xFF1D3557) : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Simpan button - Only visible for preset cup options (not "Atur jumlah")
          if (_selectedAssetBase != 'Jug' && _selectedAssetBase != widget.currentAssetBase)
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF65C9F6),
                  foregroundColor: Colors.white,
                  shadowColor: const Color(0xFF65C9F6).withOpacity(0.3),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text(
                  'Simpan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          
          if (_selectedAssetBase != 'Jug' && _selectedAssetBase != widget.currentAssetBase)
            const SizedBox(height: 24),

          // Custom Amount Slider Section - Only show when "Atur jumlah" is selected
          if (_selectedAssetBase == 'Jug')
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F7FA).withOpacity(0.5), // Light blue bg
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, size: 20, color: Color(0xFF65C9F6)),
                      const SizedBox(width: 8),
                      const Text(
                        'Atur jumlah',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF1D3557),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Value Display
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                           _sliderValue.toInt().toString(),
                           style: const TextStyle(
                             fontSize: 24,
                             fontWeight: FontWeight.bold,
                             color: Color(0xFF1D3557),
                           ),
                        ),
                        const Text(
                          'ml',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D3557),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF65C9F6),
                      inactiveTrackColor: Colors.grey.shade300,
                      thumbColor: const Color(0xFF65C9F6),
                      trackHeight: 6.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                      overlayColor: const Color(0xFF65C9F6).withOpacity(0.2),
                    ),
                    child: Slider(
                      value: _sliderValue,
                      min: 0,
                      max: 1000,
                      divisions: 100,
                      onChanged: (value) {
                        setState(() {
                           _sliderValue = value;
                           _selectedAmount = value.toInt();
                           _customAmountController.text = value.toInt().toString();
                        });
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  // Simpan button inside the container (white background)
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1D3557),
                        shadowColor: Colors.black.withOpacity(0.1),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: const Text(
                        'Simpan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
    );
  }
}
