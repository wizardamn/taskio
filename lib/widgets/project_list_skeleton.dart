import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ProjectListSkeleton extends StatelessWidget {
  const ProjectListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      itemCount: 6,
      itemBuilder: (_, index) {
        return ProjectCardSkeleton(
          index: index,
        );
      },
    );
  }
}

class ProjectCardSkeleton extends StatelessWidget {
  final int index;

  const ProjectCardSkeleton({
    super.key,
    required this.index,
  });

  double _titleWidth() {
    switch (index % 4) {
      case 0:
        return 180;
      case 1:
        return 220;
      case 2:
        return 150;
      default:
        return 200;
    }
  }

  double _messageWidth() {
    switch (index % 4) {
      case 0:
        return 240;
      case 1:
        return 170;
      case 2:
        return 210;
      default:
        return 190;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: 6,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SkeletonBox(
                  width: 12,
                  height: 12,
                  radius: 999,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: SkeletonBox(
                    width: _titleWidth(),
                    height: 18,
                    radius: 8,
                    alignment: Alignment.centerLeft,
                  ),
                ),

                const SizedBox(width: 8),

                const SkeletonBox(
                  width: 36,
                  height: 36,
                  radius: 999,
                ),

                const SizedBox(width: 4),

                const SkeletonBox(
                  width: 36,
                  height: 36,
                  radius: 999,
                ),

                const SizedBox(width: 4),

                const SkeletonBox(
                  width: 28,
                  height: 28,
                  radius: 999,
                ),
              ],
            ),

            const SizedBox(height: 12),

            SkeletonBox(
              width: _messageWidth(),
              height: 12,
              radius: 6,
            ),

            const SizedBox(height: 12),

            const SkeletonBox(
              width: double.infinity,
              height: 6,
              radius: 6,
            ),

            const SizedBox(height: 8),

            const SkeletonBox(
              width: 42,
              height: 10,
              radius: 6,
            ),

            const SizedBox(height: 12),

            const Row(
              children: [
                SkeletonBox(
                  width: 28,
                  height: 28,
                  radius: 999,
                ),
                SizedBox(width: 6),
                SkeletonBox(
                  width: 28,
                  height: 28,
                  radius: 999,
                ),
                SizedBox(width: 6),
                SkeletonBox(
                  width: 28,
                  height: 28,
                  radius: 999,
                ),
              ],
            ),

            const SizedBox(height: 12),

            SkeletonBox(
              width: screenWidth * 0.45,
              height: 12,
              radius: 6,
            ),

            const SizedBox(height: 6),

            SkeletonBox(
              width: screenWidth * 0.35,
              height: 12,
              radius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  final Alignment alignment;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 12,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final color = theme.colorScheme.surfaceContainerHighest;

    return Align(
      alignment: alignment,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        ),
      )
          .animate(
        onPlay: (controller) {
          controller.repeat(
            reverse: true,
          );
        },
      )
          .fade(
        begin: 0.45,
        end: 0.95,
        duration: 900.ms,
      ),
    );
  }
}