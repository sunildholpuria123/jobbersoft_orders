
import 'package:flutter/material.dart';

class ShipmentProgressHeader extends StatelessWidget {
  final int currentStep;
  final List<String> labels;

  const ShipmentProgressHeader({
    super.key,
    required this.currentStep,
    this.labels = const ['Orders', 'Truck', 'Load', 'Review'],
  });

  @override

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(labels.length, (index) {
          final step = index + 1;
          final completed = step <= currentStep;

          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 2,
                        color: index == 0
                            ? Colors.transparent
                            : step <= currentStep
                            ? primary
                            : Colors.grey.shade300,
                      ),
                    ),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: completed
                          ? primary
                          : Colors.grey.shade400,
                      child: Text(
                        '$step',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: index == labels.length - 1
                            ? Colors.transparent
                            : step < currentStep
                            ? primary
                            : Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    labels[index],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: step == currentStep
                          ? FontWeight.bold
                          : FontWeight.normal,
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
