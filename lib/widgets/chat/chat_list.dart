import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../models/message_model.dart';
import '../../providers/chat_provider.dart';
import '../../services/ai_service.dart';
import '../chat/chat_skeleton.dart';
import 'chat_bubble.dart';

class ChatList extends StatefulWidget {
  final String projectId;
  final Function(MessageModel) onReply;

  const ChatList({
    super.key,
    required this.projectId,
    required this.onReply,
  });

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final ItemScrollController _scrollController =
  ItemScrollController();

  final ItemPositionsListener _positionsListener =
  ItemPositionsListener.create();

  final AIService _aiService = AIService();

  bool _isLoadingMore = false;
  bool _isLoadMoreScheduled = false;
  bool _isUserScrollingUp = false;
  bool _initialScrollDone = false;

  String? _highlightedMessageId;

  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();

    _positionsListener.itemPositions.addListener(
      _handleScrollPosition,
    );
  }

  @override
  void dispose() {
    _positionsListener.itemPositions.removeListener(
      _handleScrollPosition,
    );

    super.dispose();
  }

  // =========================================================
  // SAFE STATE
  // =========================================================

  void _safeSetState(VoidCallback callback) {
    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      setState(callback);
    });
  }

  void _setLoadingMore(bool value) {
    if (_isLoadingMore == value) {
      return;
    }

    _isLoadingMore = value;

    _safeSetState(() {});
  }

  void _setHighlightedMessage(String? messageId) {
    if (_highlightedMessageId == messageId) {
      return;
    }

    _highlightedMessageId = messageId;

    _safeSetState(() {});
  }

  // =========================================================
  // POSITION TRACKING
  // =========================================================

  void _handleScrollPosition() {
    if (!mounted) {
      return;
    }

    final positions =
        _positionsListener.itemPositions.value;

    if (positions.isEmpty) {
      return;
    }

    final visible = positions
        .where(
          (position) => position.itemTrailingEdge > 0,
    )
        .toList();

    if (visible.isEmpty) {
      return;
    }

    final minIndex = visible
        .map((position) => position.index)
        .reduce((a, b) => a < b ? a : b);

    _isUserScrollingUp = minIndex > 2;
  }

  // =========================================================
  // LOAD MORE
  // =========================================================

  void _scheduleLoadMore() {
    if (_isLoadingMore ||
        _isLoadMoreScheduled ||
        !mounted) {
      return;
    }

    _isLoadMoreScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _isLoadMoreScheduled = false;

      if (!mounted || _isLoadingMore) {
        return;
      }

      await _loadMore();
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !mounted) {
      return;
    }

    _setLoadingMore(true);

    try {
      await context
          .read<ChatProvider>()
          .loadMore(widget.projectId);
    } catch (_) {
      // Ошибку здесь не показываем, чтобы не спамить snackbar при скролле.
    } finally {
      if (mounted) {
        _setLoadingMore(false);
      }
    }
  }

  // =========================================================
  // AUTO SCROLL
  // =========================================================

  void _handleAutoScroll(
      List<MessageModel> messages,
      ) {
    if (!_scrollController.isAttached) {
      return;
    }

    if (!_initialScrollDone && messages.isNotEmpty) {
      _initialScrollDone = true;
      _lastMessageCount = messages.length;

      try {
        _scrollController.jumpTo(index: 0);
      } catch (_) {
        // Контроллер мог отцепиться во время перестроения списка.
      }

      return;
    }

    final hasNewMessage =
        messages.length > _lastMessageCount;

    if (hasNewMessage && !_isUserScrollingUp) {
      try {
        _scrollController.scrollTo(
          index: 0,
          duration: const Duration(
            milliseconds: 250,
          ),
        );
      } catch (_) {
        // Безопасно игнорируем, если список уже перестроился.
      }
    }

    _lastMessageCount = messages.length;
  }

  void _scheduleAutoScroll(
      List<MessageModel> messages,
      ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _handleAutoScroll(messages);
    });
  }

  // =========================================================
  // DATE GROUPING
  // =========================================================

  bool _isNewDay(
      int index,
      List<MessageModel> messages,
      ) {
    if (index == messages.length - 1) {
      return true;
    }

    final current = messages[index].createdAt;
    final next = messages[index + 1].createdAt;

    return current.day != next.day ||
        current.month != next.month ||
        current.year != next.year;
  }

  String _formatDateGroup(
      BuildContext context,
      DateTime date,
      ) {
    final now = DateTime.now();
    final locale = context.locale.toString();

    if (date.year == now.year) {
      return DateFormat(
        'd MMMM',
        locale,
      ).format(date);
    }

    return DateFormat(
      'd MMMM yyyy',
      locale,
    ).format(date);
  }

  // =========================================================
  // SCROLL TO MESSAGE
  // =========================================================

  void _scrollToMessage(
      String messageId,
      List<MessageModel> messages,
      ) {
    final index = messages.indexWhere(
          (message) => message.id == messageId,
    );

    if (index == -1 ||
        !_scrollController.isAttached) {
      return;
    }

    _setHighlightedMessage(messageId);

    try {
      _scrollController.scrollTo(
        index: index,
        duration: const Duration(
          milliseconds: 300,
        ),
        alignment: 0.3,
      );
    } catch (_) {
      return;
    }

    Future.delayed(
      const Duration(seconds: 2),
          () {
        if (!mounted) {
          return;
        }

        if (_highlightedMessageId == messageId) {
          _setHighlightedMessage(null);
        }
      },
    );
  }

  // =========================================================
  // SCROLL NOTIFICATION
  // =========================================================

  bool _handleScrollNotification(
      ScrollNotification notification,
      ) {
    if (_isLoadingMore || _isLoadMoreScheduled) {
      return false;
    }

    if (notification is! ScrollUpdateNotification &&
        notification is! OverscrollNotification) {
      return false;
    }

    final metrics = notification.metrics;

    if (metrics.maxScrollExtent <= 0) {
      return false;
    }

    final isNearOldMessages =
        metrics.pixels >= metrics.maxScrollExtent - 200;

    if (isNearOldMessages) {
      _scheduleLoadMore();
    }

    return false;
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();

    final currentUserId = provider.currentUserId;
    final messages = provider.cachedMessages;

    if (messages.isEmpty &&
        provider.messagesStream == null) {
      return const ChatSkeleton();
    }

    _scheduleAutoScroll(messages);

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: ScrollablePositionedList.builder(
        itemScrollController: _scrollController,
        itemPositionsListener: _positionsListener,
        reverse: true,
        itemCount: messages.length +
            (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (_isLoadingMore &&
              index == messages.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
            );
          }

          if (index < 0 || index >= messages.length) {
            return const SizedBox.shrink();
          }

          final msg = messages[index];

          return Column(
            children: [
              if (_isNewDay(index, messages))
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                  ),
                  child: Center(
                    child: Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatDateGroup(
                          context,
                          msg.createdAt,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),

              ChatBubble(
                message: msg,
                isMe: msg.senderId == currentUserId,
                isRead: provider.otherReadMessages
                    .contains(msg.id),
                onReply: () => widget.onReply(msg),
                onScrollTo: (id) => _scrollToMessage(
                  id,
                  messages,
                ),
                aiService: _aiService,
                isHighlighted:
                msg.id == _highlightedMessageId,
              ),
            ],
          );
        },
      ),
    );
  }
}