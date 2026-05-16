import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../theme/wa_colors.dart';
import '../utils/message_media_url.dart';

/// Korunan ve public medya URL'lerini yukler.
class AuthenticatedNetworkImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;

  const AuthenticatedNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  @override
  State<AuthenticatedNetworkImage> createState() =>
      _AuthenticatedNetworkImageState();
}

class _AuthenticatedNetworkImageState extends State<AuthenticatedNetworkImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
      _bytes = null;
    });

    try {
      final response = await _fetchImage(allowRetry: true);
      if (!mounted) return;

      if (response != null && response.bodyBytes.isNotEmpty) {
        setState(() {
          _bytes = response.bodyBytes;
          _loading = false;
        });
        return;
      }

      setState(() {
        _failed = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<http.Response?> _fetchImage({required bool allowRetry}) async {
    final headers = isPublicMediaUrl(widget.url)
        ? <String, String>{}
        : await _mediaAuthHeaders();

    var response = await http.get(Uri.parse(widget.url), headers: headers);

    if ((response.statusCode == 401 || response.statusCode == 403) &&
        !isPublicMediaUrl(widget.url) &&
        allowRetry) {
      response = await http.get(
        Uri.parse(widget.url),
        headers: await _mediaAuthHeaders(),
      );
    }

    if (response.statusCode == 200) return response;
    return null;
  }

  Future<Map<String, String>> _mediaAuthHeaders() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      return {};
    }
    return AppConfig.mediaAuthHeaders(token);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Container(
        color: WAColors.composerBg,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_failed || _bytes == null) {
      return Container(
        color: WAColors.composerBg,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: WAColors.textTertiary),
            SizedBox(height: 4),
            Text('Resim yuklenemedi', style: TextStyle(fontSize: 11)),
          ],
        ),
      );
    }

    return Image.memory(
      _bytes!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
    );
  }
}
