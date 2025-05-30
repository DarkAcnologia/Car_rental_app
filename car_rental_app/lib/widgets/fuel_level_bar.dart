import 'package:flutter/material.dart';

class FuelLevelBar extends StatelessWidget {
  final double level; // Уровень топлива от 0 до 100

  const FuelLevelBar({super.key, required this.level});

  Color _getColor() {
    if (level <= 25) return Colors.red;
    if (level <= 50) return Colors.orange;
    if (level <= 75) return Colors.yellow;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("⛽ Уровень топлива", style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Stack(
          children: [
            Container(
              height: 20,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            Container(
              height: 20,
              width: (level.clamp(0, 100) / 100) * MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            Positioned.fill(
              child: Center(
                child: Text(
                  '${level.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            )
          ],
        ),
      ],
    );
  }
}
