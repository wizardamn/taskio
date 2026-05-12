import 'package:flutter/material.dart';

class ChatSkeleton extends StatelessWidget {
  const ChatSkeleton({super.key});

  double _bubbleWidth(int index) {
    switch (index % 4) {
      case 0:
        return 180;
      case 1:
        return 140;
      case 2:
        return 220;
      default:
        return 160;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final skeletonColor =
        theme.colorScheme.surfaceContainerHighest;

    return SafeArea(
      child: ListView.builder(
        reverse: true,
        physics:
        const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          vertical: 8,
        ),
        itemCount: 10,
        itemBuilder: (_, index) {
          final isMe = index.isEven;

          return Padding(
            padding:
            const EdgeInsets.symmetric(
              vertical: 6,
              horizontal: 12,
            ),
            child: Row(
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                Container(
                  width: _bubbleWidth(index),
                  height: 40,
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    borderRadius:
                    BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}