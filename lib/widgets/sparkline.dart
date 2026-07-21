import 'package:flutter/material.dart';

/// Tiny 4-bar sparkline: last bar highlighted, or error-colored when trending down.
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color barColor;
  final Color downColor;

  const Sparkline({
    super.key,
    required this.values,
    required this.barColor,
    required this.downColor,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final maxAbs = values.map((v) => v.abs()).fold<double>(1, (a, b) => a > b ? a : b);
    final trendingDown = values.length > 1 && values.last < values.first;

    return SizedBox(
      width: 28,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Container(
                width: 4,
                height: (values[i].abs() / maxAbs * 18).clamp(3, 18),
                decoration: BoxDecoration(
                  color: i == values.length - 1
                      ? (trendingDown ? downColor : barColor)
                      : barColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
