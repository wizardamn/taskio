import 'package:flutter/material.dart';

class ChatSkeleton extends StatelessWidget {
  const ChatSkeleton({super.key});

  double _bubbleWidth(int index, double maxWidth) {
    final width = switch (index % 4) {
      0 => 180.0,
      1 => 140.0,
      2 => 220.0,
      _ => 160.0,
    };

    return width.clamp(
      100.0,
      maxWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final skeletonColor =
        theme.colorScheme.surfaceContainerHighest;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxBubbleWidth = constraints.maxWidth * 0.75;

          return ListView.builder(
            reverse: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              vertical: 8,
            ),
            itemCount: 10,
            itemBuilder: (_, index) {
              final isMe = index.isEven;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 12,
                ),
                child: Row(
                  mainAxisAlignment: isMe
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    Container(
                      width: _bubbleWidth(
                        index,
                        maxBubbleWidth,
                      ),
                      height: 40,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}