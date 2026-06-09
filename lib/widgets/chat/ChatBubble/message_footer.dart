import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class MessageFooter extends StatelessWidget {
  final DateTime time;
  final bool isMe;
  final bool isRead;
  final bool isEdited;

  const MessageFooter({
    super.key,
    required this.time,
    required this.isMe,
    required this.isRead,
    this.isEdited = false,
  });

  // =========================================================
  // HELPERS
  // =========================================================

  String _formatTime(DateTime date) {
    final local = date.toLocal();

    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final baseColor = isMe
        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.72)
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.78);

    final readColor = isRead
        ? const Color(0xFF29B6F6)
        : baseColor.withValues(alpha: 0.72);

    final textStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 10,
      height: 1.15,
      color: baseColor,
      fontWeight: FontWeight.w500,
    ) ??
        TextStyle(
          fontSize: 10,
          height: 1.15,
          color: baseColor,
          fontWeight: FontWeight.w500,
        );

    return DefaultTextStyle(
      style: textStyle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _formatTime(time),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
          ),

          if (isEdited) ...[
            const SizedBox(width: 4),
            Text(
              '• ${'chat.edited'.tr()}',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          if (isMe) ...[
            const SizedBox(width: 4),
            Icon(
              isRead ? Icons.done_all_rounded : Icons.done_rounded,
              size: 14,
              color: readColor,
            ),
          ],
        ],
      ),
    );
  }
}