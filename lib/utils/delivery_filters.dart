import '../models/delivery_record.dart';

/// Gönderim raporlarında 2 günden eski kayıtlar gösterilmez / silinir.
const Duration deliveryRetention = Duration(days: 2);

bool isWithinDeliveryRetention(DateTime sentAt) {
  final cutoff = DateTime.now().subtract(deliveryRetention);
  return !sentAt.isBefore(cutoff);
}

List<DeliveryRecord> filterDeliveryRecords(
  List<DeliveryRecord> records, {
  DeliveryStatus? status,
}) {
  return records.where((record) {
    if (!isWithinDeliveryRetention(record.sentAt)) return false;
    if (status != null && record.status != status) return false;
    return true;
  }).toList();
}
