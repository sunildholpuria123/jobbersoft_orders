
import 'package:flutter/material.dart';

class ShipmentProgressHeader extends StatelessWidget {
  final int currentStep;

  const ShipmentProgressHeader({
    super.key,
    required this.currentStep,
  });

  static const List<String> _labels = [
    'Orders',
    'Truck',
    'Load',
    'Review',
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      child: Row(
        children: List.generate(4, (index) {
          final step = index + 1;
          final completed = step <= currentStep;

          return Expanded(
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                      completed ? primary : Colors.grey.shade400,
                      child: Text(
                        '$step',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _labels[index],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: step == currentStep
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                if (index < 3)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Container(
                        height: 2,
                        color: step < currentStep
                            ? primary
                            : Colors.grey.shade300,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
