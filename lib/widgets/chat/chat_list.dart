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

  ChatProvider? _chatProvider;

  bool _isLoadingMore = false;
  bool _isLoadMoreScheduled = false;
  bool _isUserScrollingUp = false;
  bool _initialScrollDone = false;
  bool _disposed = false;

  String? _highlightedMessageId;

  int _lastMessageCount = 0;

  // =========================================================
  // DEPENDENCIES
  // =========================================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _chatProvider ??= context.read<ChatProvider>();
  }

  @override
  void initState() {
    super.initState();

    _positionsListener.itemPositions.addListener(
      _handleScrollPosition,
    );
  }

  @override
  void dispose() {
    _disposed = true;

    _positionsListener.itemPositions.removeListener(
      _handleScrollPosition,
    );

    super.dispose();
  }

  // =========================================================
  // SAFE STATE
  // =========================================================

  void _safeSetState(VoidCallback callback) {
    if (_disposed || !mounted) {
      return;
    }

    setState(callback);
  }

  void _setLoadingMore(bool value) {
    if (_isLoadingMore == value) {
      return;
    }

    _safeSetState(() {
      _isLoadingMore = value;
    });
  }

  void _setHighlightedMessage(String? messageId) {
    if (_highlightedMessageId == messageId) {
      return;
    }

    _safeSetState(() {
      _highlightedMessageId = messageId;
    });
  }

  // =========================================================
  // POSITION TRACKING
  // =========================================================

  void _handleScrollPosition() {
    if (_disposed || !mounted) {
      return;
    }

    final positions = _positionsListener.itemPositions.value;

    if (positions.isEmpty) {
      return;
    }

    final visible = positions
        .where(
          (position) =>
      position.itemTrailingEdge > 0 &&
          position.itemLeadingEdge < 1,
    )
        .toList();

    if (visible.isEmpty) {
      return;
    }

    final minIndex = visible
        .map(
          (position) => position.index,
    )
        .reduce(
          (a, b) => a < b ? a : b,
    );

    _isUserScrollingUp = minIndex > 2;
  }

  // =========================================================
  // LOAD MORE
  // =========================================================

  void _scheduleLoadMore() {
    if (_disposed ||
        !mounted ||
        _isLoadingMore ||
        _isLoadMoreScheduled) {
      return;
    }

    _isLoadMoreScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _isLoadMoreScheduled = false;

      if (_disposed || !mounted || _isLoadingMore) {
        return;
      }

      await _loadMore();
    });
  }

  Future<void> _loadMore() async {
    if (_disposed || !mounted || _isLoadingMore) {
      return;
    }

    final chatProvider = _chatProvider;

    if (chatProvider == null) {
      return;
    }

    _setLoadingMore(true);

    try {
      await chatProvider.loadMore(
        widget.projectId,
      );
    } catch (_) {
      // При скролле не показываем snackbar, чтобы не спамить ошибками.
    } finally {
      if (!_disposed && mounted) {
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
    if (_disposed || !_scrollController.isAttached) {
      return;
    }

    if (!_initialScrollDone && messages.isNotEmpty) {
      _initialScrollDone = true;
      _lastMessageCount = messages.length;

      try {
        _scrollController.jumpTo(
          index: 0,
        );
      } catch (_) {
        // Контроллер мог отцепиться во время перестроения списка.
      }

      return;
    }

    final hasNewMessage = messages.length > _lastMessageCount;

    if (hasNewMessage && !_isUserScrollingUp) {
      try {
        _scrollController.scrollTo(
          index: 0,
          duration: const Duration(
            milliseconds: 220,
          ),
          curve: Curves.easeOut,
        );
      } catch (_) {
        // Список мог перестроиться.
      }
    }

    _lastMessageCount = messages.length;
  }

  void _scheduleAutoScroll(
      List<MessageModel> messages,
      ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !mounted) {
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

    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    final yesterday = now.subtract(
      const Duration(days: 1),
    );

    final isYesterday = date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;

    if (isToday) {
      return context.locale.languageCode == 'ru'
          ? 'Сегодня'
          : 'Today';
    }

    if (isYesterday) {
      return context.locale.languageCode == 'ru'
          ? 'Вчера'
          : 'Yesterday';
    }

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
    if (_disposed || !_scrollController.isAttached) {
      return;
    }

    final index = messages.indexWhere(
          (message) => message.id == messageId,
    );

    if (index == -1) {
      return;
    }

    _setHighlightedMessage(messageId);

    try {
      _scrollController.scrollTo(
        index: index,
        duration: const Duration(
          milliseconds: 300,
        ),
        curve: Curves.easeOut,
        alignment: 0.35,
      );
    } catch (_) {
      return;
    }

    Future.delayed(
      const Duration(seconds: 2),
          () {
        if (_disposed || !mounted) {
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
    if (_disposed ||
        _isLoadingMore ||
        _isLoadMoreScheduled) {
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
        metrics.pixels >= metrics.maxScrollExtent - 220;

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

    if (messages.isEmpty && provider.messagesStream == null) {
      return const ChatSkeleton();
    }

    _scheduleAutoScroll(messages);

    if (messages.isEmpty) {
      return _buildEmptyChat(context);
    }

    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surface,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: ScrollablePositionedList.builder(
          itemScrollController: _scrollController,
          itemPositionsListener: _positionsListener,
          reverse: true,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(
            top: 8,
            bottom: 8,
          ),
          itemCount: messages.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (_isLoadingMore && index == messages.length) {
              return _buildLoadingMoreIndicator(context);
            }

            if (index < 0 || index >= messages.length) {
              return const SizedBox.shrink();
            }

            final message = messages[index];
            final isMe = message.senderId == currentUserId;

            final isRead = isMe
                ? provider.otherReadMessages.contains(message.id)
                : message.isRead;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isNewDay(index, messages))
                  _buildDateDivider(
                    context,
                    message.createdAt,
                  ),
                ChatBubble(
                  message: message,
                  isMe: isMe,
                  isRead: isRead,
                  onReply: () => widget.onReply(message),
                  onScrollTo: (id) => _scrollToMessage(
                    id,
                    messages,
                  ),
                  aiService: _aiService,
                  isHighlighted:
                  message.id == _highlightedMessageId,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingMoreIndicator(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
      ),
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateDivider(
      BuildContext context,
      DateTime date,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.75,
            ),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(
                alpha: 0.6,
              ),
              width: 0.5,
            ),
          ),
          child: Text(
            _formatDateGroup(
              context,
              date,
            ),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChat(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ColoredBox(
      color: colorScheme.surface,
      child: ListView(
        reverse: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 62,
            color: colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'chat.no_messages'.tr(),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.locale.languageCode == 'ru'
                ? 'Напишите первое сообщение в проекте'
                : 'Write the first message in the project',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}