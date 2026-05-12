import 'package:flutter/material.dart';

class ProjectUIUtils {
  // =========================================================
  // PUBLIC API
  // =========================================================

  static IconData getFileIcon(String? mimeType,
      {String? fileName}) {
    final type =
    _normalize(mimeType, fileName);

    if (type.contains('pdf')) {
      return Icons.picture_as_pdf;
    }

    if (type.contains('word') ||
        type.contains('doc')) {
      return Icons.description;
    }

    if (type.contains('excel') ||
        type.contains('sheet') ||
        type.contains('xls')) {
      return Icons.table_chart;
    }

    if (type.contains('ppt') ||
        type.contains('presentation')) {
      return Icons.slideshow;
    }

    if (type.contains('image') ||
        _isImageExtension(fileName)) {
      return Icons.image;
    }

    if (type.contains('zip') ||
        type.contains('rar') ||
        type.contains('archive')) {
      return Icons.archive;
    }

    if (type.contains('audio')) {
      return Icons.audiotrack;
    }

    if (type.contains('video')) {
      return Icons.videocam;
    }

    return Icons.insert_drive_file;
  }

  static Color getFileColor(
      BuildContext context,
      String? mimeType, {
        String? fileName,
      }) {
    final type =
    _normalize(mimeType, fileName);

    final scheme =
        Theme.of(context).colorScheme;

    if (type.contains('pdf')) {
      return Colors.red;
    }

    if (type.contains('word') ||
        type.contains('doc')) {
      return Colors.blue;
    }

    if (type.contains('excel') ||
        type.contains('xls')) {
      return Colors.green;
    }

    if (type.contains('ppt')) {
      return Colors.orange;
    }

    if (type.contains('image') ||
        _isImageExtension(fileName)) {
      return Colors.purple;
    }

    if (type.contains('zip') ||
        type.contains('archive')) {
      return scheme.secondary;
    }

    return scheme.outline;
  }

  // =========================================================
  // INTERNAL HELPERS
  // =========================================================

  static String _normalize(
      String? mimeType,
      String? fileName,
      ) {
    final lowerMime =
    (mimeType ?? '').toLowerCase();

    final lowerName =
    (fileName ?? '').toLowerCase();

    return '$lowerMime $lowerName';
  }

  static bool _isImageExtension(
      String? fileName) {
    if (fileName == null) return false;

    final lower =
    fileName.toLowerCase();

    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }
}