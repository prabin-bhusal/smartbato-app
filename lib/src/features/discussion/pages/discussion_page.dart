import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_page_shell.dart';
import '../../auth/auth_controller.dart';

class DiscussionPage extends StatefulWidget {
  const DiscussionPage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<DiscussionPage> createState() => _DiscussionPageState();
}

class _DiscussionPageState extends State<DiscussionPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _syncTimer;
  bool _syncInFlight = false;

  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _courseName = 'Course Discussion';
  int _memberCount = 0;
  int? _replyingToMessageId;
  String? _replyingToPreview;
  List<Map<String, dynamic>> _messages = const [];
  bool _hasMoreMessages = true;
  bool _loadingOlderMessages = false;
  final Set<int> _loadingRepliesFor = <int>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMessages();
    _attachRealtime();
    _startAutoSync();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _syncTimer?.cancel();
    final realtime = widget.authController.realtimeSocket;
    realtime.off('connect', _handleSocketConnect);
    realtime.off('discussion:new_message', _handleRealtimeMessage);
    realtime.off('receive_message', _handleRealtimeMessage);
    realtime.off('discussion:poll_updated', _handlePollUpdated);
    realtime.off('discussion:message_liked', _handleMessageLiked);
    realtime.off('message_liked', _handleMessageLiked);
    realtime.off('error:event', _handleRealtimeError);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients ||
        _loadingOlderMessages ||
        !_hasMoreMessages) {
      return;
    }

    if (_scrollController.position.pixels <= 120) {
      _loadOlderMessages();
    }
  }

  bool _messageHasMoreReplies(Map<String, dynamic> message) {
    final meta =
        (message['replies_meta'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    return (meta['has_more'] as bool?) ?? false;
  }

  int _messageId(Map<String, dynamic> message) {
    return (message['id'] as num?)?.toInt() ?? 0;
  }

  void _attachRealtime() {
    widget.authController.ensureRealtimeConnected();
    final realtime = widget.authController.realtimeSocket;

    realtime.off('connect', _handleSocketConnect);
    realtime.off('discussion:new_message', _handleRealtimeMessage);
    realtime.off('receive_message', _handleRealtimeMessage);
    realtime.off('discussion:poll_updated', _handlePollUpdated);
    realtime.off('discussion:message_liked', _handleMessageLiked);
    realtime.off('message_liked', _handleMessageLiked);
    realtime.off('error:event', _handleRealtimeError);

    realtime.on('connect', _handleSocketConnect);
    realtime.on('discussion:new_message', _handleRealtimeMessage);
    realtime.on('receive_message', _handleRealtimeMessage);
    realtime.on('discussion:poll_updated', _handlePollUpdated);
    realtime.on('discussion:message_liked', _handleMessageLiked);
    realtime.on('message_liked', _handleMessageLiked);
    realtime.on('error:event', _handleRealtimeError);

    // If socket is already connected, join the room immediately.
    // Otherwise _handleSocketConnect will fire once it connects.
    final courseId = widget.authController.currentCourseId ?? 0;
    if (realtime.isConnected && courseId > 0) {
      realtime.joinDiscussionCourse(courseId);
    }
  }

  void _handleSocketConnect(dynamic _) {
    if (!mounted) return;
    final courseId = widget.authController.currentCourseId ?? 0;
    if (courseId > 0) {
      widget.authController.realtimeSocket.joinDiscussionCourse(courseId);
    }
  }

  void _startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _silentSyncFromBackend();
    });
  }

  Future<void> _silentSyncFromBackend() async {
    if (!mounted || _syncInFlight || _busy) return;
    _syncInFlight = true;
    try {
      final payload = await widget.authController.loadDiscussionMessages();
      final raw = payload['messages'] as List<dynamic>? ?? const [];
      final incoming = raw.whereType<Map<String, dynamic>>().toList(
        growable: false,
      );
      if (incoming.isNotEmpty && mounted) {
        _mergeTopLevelBatch(incoming);
      }
    } catch (_) {
      // Silent sync is best-effort. Realtime/socket remains primary.
    } finally {
      _syncInFlight = false;
    }
  }

  void _mergeTopLevelBatch(List<Map<String, dynamic>> incoming) {
    final beforeCount = _totalMessageCount(_messages);
    final nextMessages = List<Map<String, dynamic>>.from(_messages);
    var changed = false;

    for (final item in incoming) {
      final parentMessageId = (item['parent_message_id'] as num?)?.toInt();
      if (parentMessageId != null && parentMessageId > 0) {
        continue;
      }

      final normalized = Map<String, dynamic>.from(item);
      normalized['replies'] =
          (normalized['replies'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);

      final id = (normalized['id'] as num?)?.toInt() ?? 0;
      if (id <= 0) continue;

      final existingIndex = nextMessages.indexWhere(
        (m) => ((m['id'] as num?)?.toInt() ?? 0) == id,
      );

      if (existingIndex >= 0) {
        nextMessages[existingIndex] = normalized;
      } else {
        nextMessages.add(normalized);
      }

      changed = true;
    }

    if (!changed) return;

    nextMessages.sort(
      (left, right) => ((left['id'] as num?)?.toInt() ?? 0).compareTo(
        (right['id'] as num?)?.toInt() ?? 0,
      ),
    );

    if (mounted) {
      setState(() => _messages = nextMessages);
      final afterCount = _totalMessageCount(nextMessages);
      if (afterCount > beforeCount) {
        _scrollToBottom();
      }
    }
  }

  int _totalMessageCount(List<Map<String, dynamic>> items) {
    var total = items.length;
    for (final item in items) {
      final replies = (item['replies'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .length;
      total += replies;
    }
    return total;
  }

  void _handleRealtimeMessage(dynamic payload) {
    if (!mounted || payload is! Map) return;
    _mergeMessage(Map<String, dynamic>.from(payload.cast<String, dynamic>()));
  }

  void _handlePollUpdated(dynamic payload) {
    if (!mounted || payload is! Map) return;
    final event = Map<String, dynamic>.from(payload.cast<String, dynamic>());
    final messageId = (event['message_id'] as num?)?.toInt() ?? 0;
    final poll = event['poll'];
    if (messageId <= 0 || poll is! Map<String, dynamic>) return;
    _updatePoll(messageId, poll);
  }

  void _handleRealtimeError(dynamic payload) {
    if (!mounted || payload is! Map) return;
    final item = Map<String, dynamic>.from(payload.cast<String, dynamic>());
    final code = (item['code'] ?? '').toString();
    if (!code.startsWith('DISCUSSION_') && !code.startsWith('POLL_')) return;
    setState(() {
      _error = (item['message'] ?? 'Unable to update the discussion.')
          .toString();
    });
  }

  void _handleMessageLiked(dynamic payload) {
    if (!mounted || payload is! Map) return;
    final event = Map<String, dynamic>.from(payload.cast<String, dynamic>());
    final messageId = (event['message_id'] as num?)?.toInt() ?? 0;
    final parentMessageId = (event['parent_message_id'] as num?)?.toInt();
    final likesCount = (event['likes_count'] as num?)?.toInt() ?? 0;
    final likedByMe = (event['liked_by_me'] as bool?) ?? false;
    if (messageId <= 0) return;
    _applyLikeUpdate(
      messageId: messageId,
      parentMessageId: parentMessageId,
      likesCount: likesCount,
      likedByMe: likedByMe,
    );
  }

  void _mergeMessage(Map<String, dynamic> message) {
    final parentMessageId = (message['parent_message_id'] as num?)?.toInt();
    if (parentMessageId != null && parentMessageId > 0) {
      _mergeReply(parentMessageId, message);
      return;
    }

    final normalized = Map<String, dynamic>.from(message);
    normalized['replies'] =
        (normalized['replies'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);

    final nextMessages = List<Map<String, dynamic>>.from(_messages);
    final existingIndex = nextMessages.indexWhere(
      (item) =>
          ((item['id'] as num?)?.toInt() ?? 0) ==
          ((normalized['id'] as num?)?.toInt() ?? 0),
    );

    if (existingIndex >= 0) {
      nextMessages[existingIndex] = normalized;
    } else {
      nextMessages.add(normalized);
      nextMessages.sort(
        (left, right) => ((left['id'] as num?)?.toInt() ?? 0).compareTo(
          (right['id'] as num?)?.toInt() ?? 0,
        ),
      );
    }

    setState(() => _messages = nextMessages);
    _scrollToBottom();
  }

  void _mergeReply(int parentMessageId, Map<String, dynamic> reply) {
    final nextMessages = List<Map<String, dynamic>>.from(_messages);
    final parentIndex = nextMessages.indexWhere(
      (item) => ((item['id'] as num?)?.toInt() ?? 0) == parentMessageId,
    );
    if (parentIndex < 0) return;

    final parent = Map<String, dynamic>.from(nextMessages[parentIndex]);
    final replies = ((parent['replies'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: true);
    final replyId = (reply['id'] as num?)?.toInt() ?? 0;
    final existingReplyIndex = replies.indexWhere(
      (item) => ((item['id'] as num?)?.toInt() ?? 0) == replyId,
    );

    if (existingReplyIndex >= 0) {
      replies[existingReplyIndex] = reply;
    } else {
      replies.add(reply);
      replies.sort(
        (left, right) => ((left['id'] as num?)?.toInt() ?? 0).compareTo(
          (right['id'] as num?)?.toInt() ?? 0,
        ),
      );
    }

    parent['replies'] = replies;
    nextMessages[parentIndex] = parent;
    setState(() => _messages = nextMessages);
    _scrollToBottom();
  }

  void _updatePoll(int messageId, Map<String, dynamic> poll) {
    final nextMessages = List<Map<String, dynamic>>.from(_messages);
    final idx = nextMessages.indexWhere(
      (item) => ((item['id'] as num?)?.toInt() ?? 0) == messageId,
    );
    if (idx < 0) return;
    final message = Map<String, dynamic>.from(nextMessages[idx]);
    message['poll'] = poll;
    nextMessages[idx] = message;
    setState(() => _messages = nextMessages);
  }

  void _applyLikeUpdate({
    required int messageId,
    int? parentMessageId,
    required int likesCount,
    required bool likedByMe,
  }) {
    final nextMessages = List<Map<String, dynamic>>.from(_messages);

    if (parentMessageId != null && parentMessageId > 0) {
      final parentIndex = nextMessages.indexWhere(
        (item) => ((item['id'] as num?)?.toInt() ?? 0) == parentMessageId,
      );
      if (parentIndex >= 0) {
        final parent = Map<String, dynamic>.from(nextMessages[parentIndex]);
        final replies = ((parent['replies'] as List<dynamic>?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: true);
        final replyIndex = replies.indexWhere(
          (item) => ((item['id'] as num?)?.toInt() ?? 0) == messageId,
        );
        if (replyIndex >= 0) {
          final reply = Map<String, dynamic>.from(replies[replyIndex]);
          reply['likes_count'] = likesCount;
          reply['liked_by_me'] = likedByMe;
          replies[replyIndex] = reply;
          parent['replies'] = replies;
          nextMessages[parentIndex] = parent;
          setState(() => _messages = nextMessages);
        }
      }
      return;
    }

    final idx = nextMessages.indexWhere(
      (item) => ((item['id'] as num?)?.toInt() ?? 0) == messageId,
    );
    if (idx < 0) return;

    final item = Map<String, dynamic>.from(nextMessages[idx]);
    item['likes_count'] = likesCount;
    item['liked_by_me'] = likedByMe;
    nextMessages[idx] = item;
    setState(() => _messages = nextMessages);
  }

  void _startReply(Map<String, dynamic> message) {
    final id = (message['id'] as num?)?.toInt() ?? 0;
    if (id <= 0) return;
    final body = (message['body'] ?? message['poll_question'] ?? '').toString();
    setState(() {
      _replyingToMessageId = id;
      _replyingToPreview = body.trim().isEmpty
          ? 'Replying to message'
          : body.trim();
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessageId = null;
      _replyingToPreview = null;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await widget.authController.loadDiscussionMessages(
        limit: 20,
      );
      final raw = payload['messages'] as List<dynamic>? ?? const [];
      final course = payload['course'] as Map<String, dynamic>? ?? const {};
      final hasMore = (payload['has_more'] as bool?) ?? false;
      if (!mounted) return;
      setState(() {
        _courseName = (course['name'] ?? 'Course Discussion').toString();
        _memberCount = (course['member_count'] as num?)?.toInt() ?? 0;
        _messages = raw.whereType<Map<String, dynamic>>().toList(
          growable: false,
        );
        _hasMoreMessages = hasMore;
      });
      final courseId = widget.authController.currentCourseId ?? 0;
      if (courseId > 0) {
        widget.authController.realtimeSocket.joinDiscussionCourse(courseId);
      }
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_messages.isEmpty || _loadingOlderMessages || !_hasMoreMessages) {
      return;
    }

    final oldestId = (_messages.first['id'] as num?)?.toInt() ?? 0;
    if (oldestId <= 0) {
      return;
    }

    setState(() => _loadingOlderMessages = true);
    final previousMaxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final previousPixels = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;

    try {
      final payload = await widget.authController.loadDiscussionMessages(
        beforeId: oldestId,
        limit: 20,
      );
      final raw = payload['messages'] as List<dynamic>? ?? const [];
      final incoming = raw.whereType<Map<String, dynamic>>().toList(
        growable: false,
      );
      final hasMore = (payload['has_more'] as bool?) ?? false;

      if (!mounted) {
        return;
      }

      if (incoming.isNotEmpty) {
        final existingIds = _messages
            .map((m) => (m['id'] as num?)?.toInt() ?? 0)
            .toSet();
        final deduped = incoming
            .where(
              (m) => !existingIds.contains((m['id'] as num?)?.toInt() ?? 0),
            )
            .toList(growable: false);

        if (deduped.isNotEmpty) {
          setState(() {
            _messages = [...deduped, ..._messages];
            _hasMoreMessages = hasMore;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_scrollController.hasClients) return;
            final newMaxExtent = _scrollController.position.maxScrollExtent;
            final delta = newMaxExtent - previousMaxExtent;
            _scrollController.jumpTo(previousPixels + delta);
          });
        } else {
          setState(() {
            _hasMoreMessages = hasMore;
          });
        }
      } else {
        setState(() {
          _hasMoreMessages = hasMore;
        });
      }
    } catch (_) {
      // Keep current feed state if older-page fetch fails.
    } finally {
      if (mounted) {
        setState(() => _loadingOlderMessages = false);
      } else {
        _loadingOlderMessages = false;
      }
    }
  }

  Future<void> _loadMoreReplies(int messageId) async {
    if (messageId <= 0 || _loadingRepliesFor.contains(messageId)) {
      return;
    }

    final parentIndex = _messages.indexWhere((m) => _messageId(m) == messageId);
    if (parentIndex < 0) {
      return;
    }

    final parent = _messages[parentIndex];
    if (!_messageHasMoreReplies(parent)) {
      return;
    }

    final currentReplies = (parent['replies'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final beforeReplyId = currentReplies.isEmpty
        ? null
        : ((currentReplies.first['id'] as num?)?.toInt() ?? 0);

    setState(() {
      _loadingRepliesFor.add(messageId);
    });

    try {
      final payload = await widget.authController.loadDiscussionReplies(
        messageId: messageId,
        beforeReplyId: beforeReplyId,
        limit: 10,
      );
      final raw = payload['replies'] as List<dynamic>? ?? const [];
      final hasMore = (payload['has_more'] as bool?) ?? false;
      final incoming = raw.whereType<Map<String, dynamic>>().toList(
        growable: false,
      );

      if (!mounted) return;

      final nextMessages = List<Map<String, dynamic>>.from(_messages);
      final idx = nextMessages.indexWhere((m) => _messageId(m) == messageId);
      if (idx < 0) {
        return;
      }

      final nextParent = Map<String, dynamic>.from(nextMessages[idx]);
      final existingReplies =
          (nextParent['replies'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map((r) => Map<String, dynamic>.from(r))
              .toList(growable: true);
      final existingIds = existingReplies
          .map((r) => (r['id'] as num?)?.toInt() ?? 0)
          .toSet();
      final dedupedIncoming = incoming
          .where((r) => !existingIds.contains((r['id'] as num?)?.toInt() ?? 0))
          .toList(growable: false);

      nextParent['replies'] = [...dedupedIncoming, ...existingReplies];
      nextParent['replies_meta'] = <String, dynamic>{'has_more': hasMore};
      nextMessages[idx] = nextParent;

      setState(() {
        _messages = nextMessages;
      });
    } catch (_) {
      // Keep current replies if pagination fetch fails.
    } finally {
      if (mounted) {
        setState(() {
          _loadingRepliesFor.remove(messageId);
        });
      } else {
        _loadingRepliesFor.remove(messageId);
      }
    }
  }

  Future<void> _postMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty) return;

    final myId = widget.authController.user?.id ?? 0;
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final optimistic = <String, dynamic>{
      'id': tempId,
      'course_id': widget.authController.currentCourseId ?? 0,
      'parent_message_id': _replyingToMessageId,
      'message_type': 'text',
      'body': body,
      'user': {'id': myId, 'name': widget.authController.user?.name ?? 'You'},
      'created_at': DateTime.now().toIso8601String(),
      'likes_count': 0,
      'liked_by_me': false,
      'replies': const <Map<String, dynamic>>[],
      '_local_pending': true,
    };

    _mergeMessage(optimistic);
    _messageController.clear();

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payload = await widget.authController.postDiscussionMessage(
        body,
        parentMessageId: _replyingToMessageId,
      );

      final nextMessages = List<Map<String, dynamic>>.from(_messages)
        ..removeWhere((item) => ((item['id'] as num?)?.toInt() ?? 0) == tempId);
      if (mounted) {
        setState(() => _messages = nextMessages);
      }

      _cancelReply();
      final item = payload['item'];
      if (item is Map<String, dynamic>) _mergeMessage(item);
    } catch (error) {
      final nextMessages = List<Map<String, dynamic>>.from(_messages)
        ..removeWhere((item) => ((item['id'] as num?)?.toInt() ?? 0) == tempId);
      if (mounted) {
        setState(() => _messages = nextMessages);
      }
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createPoll(String question, List<String> options) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payload = await widget.authController.createDiscussionPoll(
        question: question,
        options: options,
      );
      final item = payload['item'];
      if (item is Map<String, dynamic>) _mergeMessage(item);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _vote(Map<String, dynamic> message, int optionId) async {
    final messageId = (message['id'] as num?)?.toInt() ?? 0;
    if (messageId <= 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final payload = await widget.authController.voteDiscussionPoll(
        messageId: messageId,
        optionId: optionId,
      );
      final item = payload['item'];
      if (item is Map<String, dynamic>) _mergeMessage(item);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> message) async {
    final messageId = (message['id'] as num?)?.toInt() ?? 0;
    if (messageId <= 0) return;

    final optimisticLiked = !((message['liked_by_me'] as bool?) ?? false);
    final optimisticCount =
        ((message['likes_count'] as num?)?.toInt() ?? 0) +
        (optimisticLiked ? 1 : -1);

    _applyLikeUpdate(
      messageId: messageId,
      parentMessageId: (message['parent_message_id'] as num?)?.toInt(),
      likesCount: optimisticCount < 0 ? 0 : optimisticCount,
      likedByMe: optimisticLiked,
    );

    try {
      final payload = await widget.authController.toggleDiscussionLike(
        messageId: messageId,
      );
      final item = payload['item'];
      if (item is Map<String, dynamic>) {
        _applyLikeUpdate(
          messageId: (item['message_id'] as num?)?.toInt() ?? messageId,
          parentMessageId: (item['parent_message_id'] as num?)?.toInt(),
          likesCount: (item['likes_count'] as num?)?.toInt() ?? 0,
          likedByMe: (item['liked_by_me'] as bool?) ?? false,
        );
      }
    } catch (error) {
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
      _applyLikeUpdate(
        messageId: messageId,
        parentMessageId: (message['parent_message_id'] as num?)?.toInt(),
        likesCount: (message['likes_count'] as num?)?.toInt() ?? 0,
        likedByMe: (message['liked_by_me'] as bool?) ?? false,
      );
    }
  }

  void _openPollModal() {
    final questionCtrl = TextEditingController();
    final optionCtrls = List.generate(4, (_) => TextEditingController());
    bool sending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0891B2).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.poll_rounded,
                      color: Color(0xFF0891B2),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Create Poll',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Ask the community a question with up to 4 options.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              _modalField(
                questionCtrl,
                'Poll question *',
                Icons.help_outline_rounded,
              ),
              const SizedBox(height: 10),
              for (int i = 0; i < 4; i++) ...[
                _modalField(
                  optionCtrls[i],
                  i < 2 ? 'Option ${i + 1} *' : 'Option ${i + 1} (optional)',
                  Icons.radio_button_unchecked_rounded,
                ),
                if (i < 3) const SizedBox(height: 8),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: sending
                      ? null
                      : () async {
                          final question = questionCtrl.text.trim();
                          final options = optionCtrls
                              .map((c) => c.text.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                          if (question.length < 3 || options.length < 2) return;
                          setModal(() => sending = true);
                          Navigator.pop(ctx);
                          await _createPoll(question, options);
                        },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text(
                    'Create Poll',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0891B2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modalField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = widget.authController.user?.id ?? 0;

    return Column(
      children: [
        // ── header ──────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF16A34A), Color(0xFF0891B2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const Icon(Icons.forum_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _courseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _memberCount > 0
                            ? '$_memberCount members'
                            : 'Live course chat',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_loading)
                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _loadMessages,
                    tooltip: 'Refresh',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ),

        // ── error banner ────────────────────────────────────────────────
        if (_error != null)
          Container(
            width: double.infinity,
            color: const Color(0xFFFEF2F2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFB91C1C),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  onPressed: () => setState(() => _error = null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

        // ── messages ────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AppSurfaceCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.forum_outlined,
                              size: 52,
                              color: Color(0xFF94A3B8),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No posts yet.\nBe the first to start a conversation!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  itemCount: _messages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      if (_loadingOlderMessages) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Center(
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      if (!_hasMoreMessages) {
                        return const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Center(
                            child: Text(
                              'No older messages',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox(height: 8);
                    }
                    return _buildMessageBubble(_messages[index - 1], myId);
                  },
                ),
        ),

        if (_replyingToMessageId != null)
          Container(
            width: double.infinity,
            color: const Color(0xFFF0FDF4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.reply_rounded,
                  size: 16,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _replyingToPreview ?? 'Replying…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF166534),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _cancelReply,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Color(0xFF166534),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

        // ── compose bar ─────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 12,
            right: 8,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 10,
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Poll icon
                _ComposeIconBtn(
                  icon: Icons.poll_rounded,
                  color: const Color(0xFF0891B2),
                  tooltip: 'Create Poll',
                  onTap: _busy ? null : _openPollModal,
                ),
                const SizedBox(width: 6),
                // Text field
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Write a message…',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _busy ? null : _postMessage(),
                  ),
                ),
                const SizedBox(width: 6),
                // Send button
                AnimatedOpacity(
                  opacity: _busy ? 0.5 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: GestureDetector(
                    onTap: _busy ? null : _postMessage,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF16A34A), Color(0xFF0891B2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(21),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, int myId) {
    final user =
        (message['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final senderId = (user['id'] as num?)?.toInt() ?? 0;
    final senderName = (user['name'] ?? 'User').toString();
    final type = (message['message_type'] ?? 'text').toString();
    final replies = (message['replies'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final isMe = senderId == myId;
    final createdAt = _formatTime((message['created_at'] ?? '').toString());
    final likesCount = (message['likes_count'] as num?)?.toInt() ?? 0;
    final likedByMe = (message['liked_by_me'] as bool?) ?? false;
    final isPending = (message['_local_pending'] as bool?) ?? false;
    final messageId = _messageId(message);
    final hasMoreReplies = _messageHasMoreReplies(message);
    final repliesLoading = _loadingRepliesFor.contains(messageId);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Sender label (only for others)
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 3),
              child: Text(
                senderName,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF16A34A),
                ),
              ),
            ),

          // Bubble
          GestureDetector(
            onLongPress: () => _startReply(message),
            child: Row(
              mainAxisAlignment: isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Avatar for others
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 4),
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: const Color(
                        0xFF16A34A,
                      ).withValues(alpha: 0.15),
                      child: Text(
                        senderName.isNotEmpty
                            ? senderName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ),

                // Content
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: type == 'poll'
                          ? const Color(0xFFF0F9FF)
                          : (isMe ? const Color(0xFF16A34A) : Colors.white),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      border: type == 'poll'
                          ? Border.all(
                              color: const Color(
                                0xFF0891B2,
                              ).withValues(alpha: 0.3),
                            )
                          : (isMe
                                ? null
                                : Border.all(color: const Color(0xFFE2E8F0))),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(type == 'poll' ? 12 : 11),
                    child: type == 'poll'
                        ? _buildPollContent(message)
                        : Text(
                            (message['body'] ?? '').toString(),
                            style: TextStyle(
                              color: isMe
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                              fontSize: 14.5,
                              height: 1.4,
                            ),
                          ),
                  ),
                ),

                // Avatar for me (optional — keeps spacing)
                if (isMe) const SizedBox(width: 4),
              ],
            ),
          ),

          // Timestamp
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0 : 48,
              right: isMe ? 8 : 0,
              top: 3,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  createdAt,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                if (isPending) ...[
                  const SizedBox(width: 6),
                  const Text(
                    'Sending…',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _startReply(message),
                  child: const Text(
                    'Reply',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0891B2),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _toggleLike(message),
                  child: Row(
                    children: [
                      Icon(
                        likedByMe
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 13,
                        color: likedByMe
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF94A3B8),
                      ),
                      if (likesCount > 0) ...[
                        const SizedBox(width: 3),
                        Text(
                          '$likesCount',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: likedByMe
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Replies
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: replies
                    .map((reply) => _buildReplyChip(reply, myId))
                    .toList(growable: false),
              ),
            ),

          if (hasMoreReplies || repliesLoading)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 2),
              child: TextButton.icon(
                onPressed: repliesLoading
                    ? null
                    : () => _loadMoreReplies(messageId),
                icon: repliesLoading
                    ? const SizedBox(
                        height: 12,
                        width: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.expand_less_rounded,
                        size: 15,
                        color: Color(0xFF0891B2),
                      ),
                label: Text(
                  repliesLoading ? 'Loading replies...' : 'See more replies',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0891B2),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPollContent(Map<String, dynamic> message) {
    final poll = (message['poll'] as Map<String, dynamic>?);
    final options = (poll?['options'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final myVoteOptionId = (poll?['my_option_id'] as num?)?.toInt();
    final totalVotes = (poll?['total_votes'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.poll_rounded, size: 15, color: Color(0xFF0891B2)),
            const SizedBox(width: 5),
            const Text(
              'POLL',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0891B2),
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            Text(
              '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          (message['poll_question'] ?? '').toString(),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        ...options.map((option) {
          final optionId = (option['id'] as num?)?.toInt() ?? 0;
          final votes = (option['votes'] as num?)?.toInt() ?? 0;
          final isSelected = myVoteOptionId == optionId;
          final percent = totalVotes > 0 ? votes / totalVotes : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: GestureDetector(
              onTap: _busy ? null : () => _vote(message, optionId),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0891B2).withValues(alpha: 0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0891B2)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Stack(
                  children: [
                    // Progress fill
                    FractionallySizedBox(
                      widthFactor: percent,
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF0891B2,
                          ).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    // Label + count
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: Row(
                        children: [
                          if (isSelected)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: Color(0xFF0891B2),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              (option['text'] ?? '').toString(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? const Color(0xFF0891B2)
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$votes',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? const Color(0xFF0891B2)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReplyChip(Map<String, dynamic> reply, int myId) {
    final user =
        (reply['user'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final senderId = (user['id'] as num?)?.toInt() ?? 0;
    final senderName = (user['name'] ?? 'User').toString();
    final isMe = senderId == myId;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.subdirectory_arrow_right_rounded,
            size: 13,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                children: [
                  TextSpan(
                    text: isMe ? 'You: ' : '$senderName: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isMe
                          ? const Color(0xFF16A34A)
                          : const Color(0xFF0891B2),
                    ),
                  ),
                  TextSpan(text: (reply['body'] ?? '').toString()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        final hh = dt.hour.toString().padLeft(2, '0');
        final mm = dt.minute.toString().padLeft(2, '0');
        return '$hh:$mm';
      }
      if (diff.inDays == 1) return 'Yesterday';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }
}

class _ComposeIconBtn extends StatelessWidget {
  const _ComposeIconBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(21),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}
