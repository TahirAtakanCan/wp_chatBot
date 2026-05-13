import 'package:flutter/material.dart';

import '../models/delivery_record.dart';

class DeliveryStatusIcon extends StatelessWidget {
  final DeliveryStatus? status;

  const DeliveryStatusIcon({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox(width: 20);

    switch (status!) {
      case DeliveryStatus.sent:
        return const Icon(Icons.done, size: 16, color: Colors.grey);
      case DeliveryStatus.delivered:
        return const Icon(Icons.done_all, size: 16, color: Colors.grey);
      case DeliveryStatus.read:
        return const Icon(Icons.done_all, size: 16, color: Color(0xFF34B7F1));
      case DeliveryStatus.failed:
        return Tooltip(
          message: 'Mesaj iletilemedi',
          child: Icon(Icons.error_outline, size: 16, color: Colors.red.shade400),
        );
    }
  }
}
