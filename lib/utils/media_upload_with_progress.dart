import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/media_upload_result.dart';
import '../services/chat_media_service.dart';
import '../utils/media_size_helper.dart';
import '../widgets/upload_progress_dialog.dart';

/// Dosyayı progress dialog ile yükler.
Future<MediaUploadResult?> uploadMediaWithProgressDialog({
  required BuildContext context,
  required PlatformFile file,
  required String dialogTitle,
}) async {
  final sizeBytes = resolvePickerFileSize(
    pickerSize: file.size,
    bytes: file.bytes,
  );
  final dialogKey = GlobalKey<UploadProgressDialogState>();
  final cancelToken = CancelToken();
  var progressDialogOpen = false;

  progressDialogOpen = true;
  // ignore: unawaited_futures
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: UploadProgressDialog(
        key: dialogKey,
        title: dialogTitle,
        filename: file.name,
        sizeFormatted: formatFileSizeDisplay(sizeBytes),
        totalBytes: sizeBytes,
        onCancel: () {
          cancelToken.cancel('Kullanıcı iptal etti');
          Navigator.of(dialogContext).pop();
        },
      ),
    ),
  ).whenComplete(() => progressDialogOpen = false);

  final service = ChatMediaService();
  try {
    return await service.uploadMedia(
      file,
      onProgress: (sent, total) {
        dialogKey.currentState?.updateProgress(sent, total);
      },
      cancelToken: cancelToken,
    );
  } on DioException catch (e) {
    if (CancelToken.isCancel(e)) return null;
    rethrow;
  } finally {
    if (progressDialogOpen && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
