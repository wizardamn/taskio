import 'package:flutter/material.dart';

class HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;

  const HighlightText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        style: style,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    final spans = <TextSpan>[];

    int start = 0;

    while (true) {
      final index = lowerText.indexOf(
        lowerQuery,
        start,
      );

      if (index < 0) {
        if (start < text.length) {
          spans.add(
            TextSpan(
              text: text.substring(start),
              style: style,
            ),
          );
        }
        break;
      }

      if (index > start) {
        spans.add(
          TextSpan(
            text: text.substring(
              start,
              index,
            ),
            style: style,
          ),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(
            index,
            index + query.length,
          ),
          style:
          highlightStyle ??
              style?.copyWith(
                backgroundColor:
                Colors.blue.withValues(
                  alpha: 0.5,
                ),
                fontWeight:
                FontWeight.bold,
              ) ??
              TextStyle(
                backgroundColor:
                Colors.blue.withValues(
                  alpha: 0.5,
                ),
                fontWeight:
                FontWeight.bold,
              ),
        ),
      );

      start = index + query.length;
    }

    return RichText(
      text: TextSpan(
        children: spans,
      ),
    );
  }
}