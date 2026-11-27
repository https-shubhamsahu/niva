import 'package:flutter/material.dart';

/// One-line disclaimer shown wherever sensor readings appear. Until the FSRs
/// are characterised, every value is a raw relative reading.
class ReadingsNotice extends StatelessWidget {
  const ReadingsNotice({super.key});

  static const text = 'Uncalibrated sensor readings. Not a medical device.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 14,
          color: theme.textTheme.labelSmall?.color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: theme.textTheme.labelSmall?.color,
            ),
          ),
        ),
      ],
    );
  }
}
