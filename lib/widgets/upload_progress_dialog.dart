import 'package:flutter/material.dart';

import '../theme/wa_colors.dart';
import '../utils/media_size_helper.dart';

class UploadProgressDialog extends StatefulWidget {
  final String title;
  final String filename;
  final String sizeFormatted;
  final int totalBytes;
  final VoidCallback? onCancel;

  const UploadProgressDialog({
    super.key,
    required this.title,
    required this.filename,
    required this.sizeFormatted,
    required this.totalBytes,
    this.onCancel,
  });

  @override
  State<UploadProgressDialog> createState() => UploadProgressDialogState();
}

class UploadProgressDialogState extends State<UploadProgressDialog> {
  double _progress = 0;
  int _sentBytes = 0;
  int _totalBytes = 0;

  @override
  void initState() {
    super.initState();
    _totalBytes = widget.totalBytes;
  }

  void updateProgress(int sent, int total) {
    if (!mounted) return;
    setState(() {
      _sentBytes = sent;
      _totalBytes = total > 0 ? total : widget.totalBytes;
      _progress = _totalBytes > 0 ? (sent / _totalBytes).clamp(0.0, 1.0) : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).clamp(0, 100).toStringAsFixed(0);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.upload_file_rounded, color: WAColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.filename,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: WAColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            widget.sizeFormatted,
            style: const TextStyle(
              color: WAColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              minHeight: 8,
              backgroundColor: WAColors.divider,
              color: WAColors.accent,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatFileSizeDisplay(_sentBytes)} / ${formatFileSizeDisplay(_totalBytes)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: WAColors.textSecondary,
                ),
              ),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: WAColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'İnternet hızınıza göre 30-90 saniye sürebilir',
            style: TextStyle(
              fontSize: 11,
              color: WAColors.textTertiary,
            ),
          ),
        ],
      ),
      actions: widget.onCancel != null
          ? [
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('İptal'),
              ),
            ]
          : null,
    );
  }
}
