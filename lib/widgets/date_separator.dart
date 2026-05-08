import 'package:flutter/material.dart';

import '../theme/wa_colors.dart';
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: WAColors.dateChipBg,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 2,
                offset: Offset(0, 1),
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
