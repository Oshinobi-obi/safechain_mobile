import 'package:flutter/material.dart';

class BatteryIndicator extends StatelessWidget {
  final int charge;

  const BatteryIndicator({
    super.key,
    required this.charge,
  });

  Color _getBatteryColor() {
    if (charge > 40) {
      return const Color(0xFF20C997);
    } else if (charge > 20) {
      return const Color(0xFFFFA500);
    } else {
      return const Color(0xFFF87171);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color batteryColor = _getBatteryColor();
    final double chargeLevel = charge / 100.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$charge%',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: batteryColor,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 32,
          height: 16,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(
              color: batteryColor,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          // Inner Charge Level
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: (32 - 3 - 3) * chargeLevel,
              decoration: BoxDecoration(
                color: batteryColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}