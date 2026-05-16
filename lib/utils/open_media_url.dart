import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openMediaUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    throw Exception('Geçersiz medya adresi.');
  }

  final launched = await launchUrl(
    uri,
    mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
  );
  if (!launched) {
    throw Exception('Medya açılamadı.');
  }
}
