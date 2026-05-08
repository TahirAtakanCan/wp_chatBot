import 'package:flutter/material.dart';

import 'wa_colors.dart';

class WATextStyles {
  static const String fontFamily = 'Roboto';

  // Titles
  static const TextStyle screenTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: WAColors.textPrimary,
  );

  // Inbox
  static const TextStyle conversationName = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: WAColors.textPrimary,
  );
  static const TextStyle conversationPreview = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: WAColors.textSecondary,
    height: 1.3,
  );
  static const TextStyle conversationTime = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: WAColors.textTertiary,
  );

  // Chat header
  static const TextStyle chatTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: WAColors.textPrimary,
  );
  static const TextStyle chatSubtitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: WAColors.textSecondary,
  );

  // Bubble
  static const TextStyle messageBody = TextStyle(
    fontSize: 14.2,
    fontWeight: FontWeight.w400,
    color: WAColors.textPrimary,
    height: 1.4,
  );
  static const TextStyle messageTime = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: WAColors.textTertiary,
  );

  // Date chip
  static const TextStyle dateChip = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: WAColors.dateChipText,
  );

  // Empty state
  static const TextStyle emptyTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w300,
    color: WAColors.textSecondary,
  );
  static const TextStyle emptySubtitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: WAColors.textTertiary,
    height: 1.5,
  );
}
