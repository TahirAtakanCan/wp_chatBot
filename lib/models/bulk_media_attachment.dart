enum BulkMediaKind {
  image,
  video,
  document;

  String get apiValue => name.toUpperCase();

  bool get isTemplateSupported => this == BulkMediaKind.image;
}

class BulkMediaAttachment {
  final String url;
  final BulkMediaKind kind;
  final String filename;
  final int sizeBytes;

  const BulkMediaAttachment({
    required this.url,
    required this.kind,
    required this.filename,
    required this.sizeBytes,
  });
}
