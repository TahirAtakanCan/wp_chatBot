import 'package:flutter/services.dart';

/// Telefon numaralarını (555) 123 4567 formatında gösteren formatter.
/// Her satır ayrı bir numara olarak formatlanır.
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Cursor öncesindeki anlamlı karakter sayısını hesapla (rakam + satır sonu)
    int sigBeforeCursor = 0;
    final cursorPos =
        newValue.selection.baseOffset.clamp(0, newValue.text.length);
    for (int i = 0; i < cursorPos; i++) {
      if (_isSignificant(newValue.text[i])) sigBeforeCursor++;
    }

    // Her satırı ayrı ayrı formatla
    final lines = newValue.text.split('\n');
    final formattedLines = lines.map(_formatLine).toList();
    final formatted = formattedLines.join('\n');

    // Yeni cursor pozisyonunu bul
    int newCursor = 0;
    int counted = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (counted >= sigBeforeCursor) break;
      if (_isSignificant(formatted[i])) counted++;
      newCursor = i + 1;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: newCursor.clamp(0, formatted.length),
      ),
    );
  }

  bool _isSignificant(String char) {
    return RegExp(r'[0-9\n]').hasMatch(char);
  }

  String _formatLine(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    final len = digits.length > 10 ? 10 : digits.length;

    if (len <= 3) {
      return '(${digits.substring(0, len)}';
    } else if (len <= 6) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, len)}';
    } else {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)} ${digits.substring(6, len)}';
    }
  }
}
