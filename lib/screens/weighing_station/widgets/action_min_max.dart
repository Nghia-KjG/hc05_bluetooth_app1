import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class ActionBar extends StatelessWidget {
  final double selectedPercentage;
  final Function(double) onPercentageChanged;

  const ActionBar({
    super.key, 
    required this.selectedPercentage,
    required this.onPercentageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          value: selectedPercentage,
          items: const [
            DropdownMenuItem(value: 0.1, child: Text('100g')),
            DropdownMenuItem(value: 1.0, child: Text('1.0%')),
            DropdownMenuItem(value: 2.0, child: Text('2.0%')),
            DropdownMenuItem(value: 5.0, child: Text('5.0%')),
            if (kDebugMode) ...[  
              DropdownMenuItem(value: 90.0, child: Text('test%')),
            ],
          ],
          onChanged: (value) {
            if (value != null) {
              onPercentageChanged(value);
            }
          },
        ),
      ),
    );
  }
}