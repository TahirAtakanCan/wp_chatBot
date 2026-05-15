import 'package:flutter/material.dart';

import '../theme/wa_text_styles.dart';
import '../utils/date_format.dart';

class DateSeparator extends StatefulWidget {
  final DateTime dateTime;

  const DateSeparator({
    super.key,
    required this.dateTime,
  });

  @override
  State<DateSeparator> createState() => _DateSeparatorState();
}

class _DateSeparatorState extends State<DateSeparator> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _visible = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            formatDateChip(widget.dateTime),
            style: WATextStyles.dateChip,
          ),
        ),
      ),
    );
  }
}
