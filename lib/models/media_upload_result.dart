class MediaUploadResult {
  final String url;
  final int sizeBytes;
  final String filename;

  const MediaUploadResult({
    required this.url,
    required this.sizeBytes,
    required this.filename,
  });

  double get sizeMegabytes => sizeBytes / (1024 * 1024);
}

enum VideoSendMode {
  inlineVideo,
  asDocument,
}
