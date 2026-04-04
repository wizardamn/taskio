import 'package:flutter/material.dart';

class LoadingOverlay extends StatefulWidget {
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.child,
  });

  static final GlobalKey<_LoadingOverlayState> _overlayKey =
  GlobalKey<_LoadingOverlayState>();

  /// Обёртка для main.dart
  static Widget init({required Widget child}) {
    return LoadingOverlay(
      key: _overlayKey,
      child: child,
    );
  }

  static void show([String? message]) {
    _overlayKey.currentState?._show(message);
  }

  static void hide() {
    _overlayKey.currentState?._hide();
  }

  @override
  State<LoadingOverlay> createState() =>
      _LoadingOverlayState();
}

class _LoadingOverlayState
    extends State<LoadingOverlay>
    with SingleTickerProviderStateMixin {
  bool _isVisible = false;
  String? _message;

  void _show(String? message) {
    if (!mounted) return;

    setState(() {
      _isVisible = true;
      _message = message;
    });
  }

  void _hide() {
    if (!mounted) return;

    setState(() {
      _isVisible = false;
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        // 🔥 Overlay
        AnimatedOpacity(
          opacity: _isVisible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: !_isVisible,
            child: Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}