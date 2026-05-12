import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../models/message_model.dart';

class BubbleContent extends StatelessWidget {
  final MessageModel message;
  final Color textColor;
  final Function(String url) onOpenImage;

  const BubbleContent({
    super.key,
    required this.message,
    required this.textColor,
    required this.onOpenImage,
  });

  /// ✅ более строгая проверка URL
  String? _safeImageUrl() {
    final url = message.previewUrl?.isNotEmpty == true
        ? message.previewUrl!
        : message.content;

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.isAbsolute) return null;

    if (uri.scheme != 'http' && uri.scheme != 'https') return null;

    return url;
  }

  /// ✅ безопасное открытие ссылки
  Future<void> _openFile(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    /// ❌ УДАЛЕНОЕ
    if (message.isDeleted) {
      return Text(
        'chat.deleted'.tr(),
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.6),
        ),
      );
    }

    /// 📷 ИЗОБРАЖЕНИЕ
    if (message.isImage) {
      final url = _safeImageUrl();

      if (url == null) {
        return const Icon(Icons.broken_image);
      }

      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onOpenImage(url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: url,
            height: 150,
            width: 150,
            fit: BoxFit.cover,
            placeholder: (_, __) => const SizedBox(
              height: 150,
              width: 150,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (_, __, ___) =>
            const Icon(Icons.broken_image),
          ),
        ),
      );
    }

    /// 📎 ФАЙЛ
    if (message.isFile) {
      return InkWell(
        onTap: () => _openFile(message.content),
        child: Text(
          message.fileName ?? 'file',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            decoration: TextDecoration.underline,
            color: textColor,
          ),
        ),
      );
    }

    /// 💬 ТЕКСТ
    return Text(
      message.displayContent,
      softWrap: true,
      style: TextStyle(color: textColor),
    );
  }
}