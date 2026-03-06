import 'package:flutter/material.dart';

class SectionDivider extends StatelessWidget {
  final double height;
  final bool showLine;

  const SectionDivider({
    super.key,
    this.height = 24,
    this.showLine = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showLine) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: height / 2),
        child: Divider(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
          thickness: 0.5,
        ),
      );
    }
    return SizedBox(height: height);
  }
}
