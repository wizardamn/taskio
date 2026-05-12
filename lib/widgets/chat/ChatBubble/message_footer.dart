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

  String _formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final textStyle = TextStyle(
      fontSize: 10,
      height: 1.2,
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha:0.8),
    );

    return DefaultTextStyle(
      style: textStyle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// ⏰ ВРЕМЯ
          Text(_formatTime(time)),

          /// ✏️ EDITED
          if (isEdited) ...[
            const SizedBox(width: 4),
            Text('• ${'chat.edited'.tr()}'),
          ],

          /// ✅ ГАЛОЧКИ (как Telegram)
          if (isMe) ...[
            const SizedBox(width: 4),
            Icon(
              isRead ? Icons.done_all : Icons.done,
              size: 14,
              color: isRead
                  ? const Color(0xFF4FC3F7) // Telegram blue
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha:0.6),
            ),
          ],
        ],
      ),
    );
  }
}