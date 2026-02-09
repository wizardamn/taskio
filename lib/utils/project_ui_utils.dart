import 'package:flutter/material.dart';

class ProjectUIUtils {
  static IconData getFileIcon(String mimeType) {
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('doc')) return Icons.description;
    if (mimeType.contains('image')) return Icons.image;
    return Icons.insert_drive_file;
  }

  static Color getFileColor(String mimeType) {
    if (mimeType.contains('pdf')) return Colors.red;
    if (mimeType.contains('word')) return Colors.blue;
    if (mimeType.contains('image')) return Colors.purple;
    return Colors.grey;
  }
}