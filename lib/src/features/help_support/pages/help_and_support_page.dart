import 'package:flutter/material.dart';

import '../../auth/auth_controller.dart';
import '../../../core/theme/app_page_shell.dart';

class HelpAndSupportPage extends StatefulWidget {
  const HelpAndSupportPage({super.key, required this.authController});

  final AuthController authController;

  @override
  State<HelpAndSupportPage> createState() => _HelpAndSupportPageState();
}

class _HelpAndSupportPageState extends State<HelpAndSupportPage> {
  final TextEditingController _messageController = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  bool _loadingMoreThreads = false;
  bool _hasMoreThreads = true;
  int _currentThreadsPage = 1;
  String? _error;
  List<Map<String, dynamic>> _threads = const [];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final payload = await widget.authController.loadSupportThreads(
        page: 1,
        perPage: 20,
      );
      final raw = payload['threads'] as List<dynamic>? ?? const [];
      final meta =
          (payload['meta'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      if (!mounted) {
        return;
      }
      setState(() {
        _threads = raw.whereType<Map<String, dynamic>>().toList(
          growable: false,
        );
        _currentThreadsPage = (meta['current_page'] as num?)?.toInt() ?? 1;
        _hasMoreThreads = (meta['has_more_pages'] as bool?) ?? false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMoreThreads() async {
    if (_loadingMoreThreads || !_hasMoreThreads) {
      return;
    }

    setState(() {
      _loadingMoreThreads = true;
    });

    try {
      final payload = await widget.authController.loadSupportThreads(
        page: _currentThreadsPage + 1,
        perPage: 20,
      );
      final raw = payload['threads'] as List<dynamic>? ?? const [];
      final incoming = raw.whereType<Map<String, dynamic>>().toList(
        growable: false,
      );
      final meta =
          (payload['meta'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};

      if (!mounted) {
        return;
      }

      setState(() {
        _threads = [..._threads, ...incoming];
        _currentThreadsPage =
            (meta['current_page'] as num?)?.toInt() ?? _currentThreadsPage + 1;
        _hasMoreThreads = (meta['has_more_pages'] as bool?) ?? false;
      });
    } catch (_) {
      // Keep current list if loading next page fails.
    } finally {
      if (mounted) {
        setState(() {
          _loadingMoreThreads = false;
        });
      }
    }
  }

  Future<void> _openThread() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await widget.authController.createSupportThread(message);
      _messageController.clear();
      await _loadThreads();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _openMessages(Map<String, dynamic> thread) async {
    final threadId = (thread['id'] as num?)?.toInt() ?? 0;
    if (threadId <= 0) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SupportMessagesPage(
          authController: widget.authController,
          threadId: threadId,
          title: 'Thread #$threadId',
        ),
      ),
    );

    await _loadThreads();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      maxWidth: 860,
      children: [
        const AppHeroBanner(
          title: 'Help & Support',
          subtitle:
              'Send a message to the admin support team and track replies here.',
          icon: Icons.support_agent_rounded,
          colors: [Color(0xFFDC2626), Color(0xFFEA580C)],
        ),
        const SizedBox(height: 14),
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create New Support Request',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _messageController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Describe your issue',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _openThread,
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Open Ticket'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Support Threads',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFFB91C1C)),
                  ),
                )
              else if (_threads.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No support threads yet. Send your first message above.',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                )
              else
                Column(
                  children: [
                    ..._threads.map((thread) {
                      final status = (thread['status'] ?? 'open').toString();
                      final preview = (thread['last_message_preview'] ?? '')
                          .toString();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.mark_chat_unread_rounded),
                        title: Text('Thread #${thread['id']}'),
                        subtitle: Text(
                          preview.isEmpty ? 'No messages yet.' : preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Chip(label: Text(status.toUpperCase())),
                        onTap: () => _openMessages(thread),
                      );
                    }),
                    if (_hasMoreThreads) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _loadingMoreThreads
                            ? null
                            : _loadMoreThreads,
                        icon: _loadingMoreThreads
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.expand_more_rounded),
                        label: Text(
                          _loadingMoreThreads ? 'Loading...' : 'Load more',
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SupportMessagesPage extends StatefulWidget {
  const _SupportMessagesPage({
    required this.authController,
    required this.threadId,
    required this.title,
  });

  final AuthController authController;
  final int threadId;
  final String title;

  @override
  State<_SupportMessagesPage> createState() => _SupportMessagesPageState();
}

class _SupportMessagesPageState extends State<_SupportMessagesPage> {
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _sending = false;
  bool _loadingOlderMessages = false;
  bool _hasMoreMessages = true;
  String? _error;
  List<Map<String, dynamic>> _messages = const [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _attachRealtime();
  }

  @override
  void dispose() {
    final realtime = widget.authController.realtimeSocket;
    realtime.off('support:new_message', _handleRealtimeMessage);
    realtime.off('error:event', _handleRealtimeError);
    _composerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _attachRealtime() {
    widget.authController.ensureRealtimeConnected();
    final realtime = widget.authController.realtimeSocket;
    realtime.off('support:new_message', _handleRealtimeMessage);
    realtime.off('error:event', _handleRealtimeError);
    realtime.on('support:new_message', _handleRealtimeMessage);
    realtime.on('error:event', _handleRealtimeError);
    realtime.joinSupportThread(widget.threadId);
  }

  void _handleRealtimeMessage(dynamic payload) {
    if (!mounted || payload is! Map) {
      return;
    }

    final item = Map<String, dynamic>.from(payload.cast<String, dynamic>());
    final threadId = (item['thread_id'] as num?)?.toInt() ?? 0;
    if (threadId != widget.threadId) {
      return;
    }

    _mergeMessage(item);
  }

  void _handleRealtimeError(dynamic payload) {
    if (!mounted || payload is! Map) {
      return;
    }

    final item = Map<String, dynamic>.from(payload.cast<String, dynamic>());
    final code = (item['code'] ?? '').toString();
    if (!code.startsWith('SUPPORT_')) {
      return;
    }

    setState(() {
      _error = (item['message'] ?? 'Unable to update this support thread.')
          .toString();
    });
  }

  void _mergeMessage(Map<String, dynamic> item) {
    final messageId = (item['id'] as num?)?.toInt() ?? 0;
    if (messageId <= 0) {
      return;
    }

    final nextMessages = List<Map<String, dynamic>>.from(_messages);
    final existingIndex = nextMessages.indexWhere(
      (message) => ((message['id'] as num?)?.toInt() ?? 0) == messageId,
    );

    if (existingIndex >= 0) {
      nextMessages[existingIndex] = item;
    } else {
      nextMessages.add(item);
      nextMessages.sort(
        (left, right) => ((left['id'] as num?)?.toInt() ?? 0).compareTo(
          (right['id'] as num?)?.toInt() ?? 0,
        ),
      );
    }

    setState(() {
      _messages = nextMessages;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
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
      final payload = await widget.authController.loadSupportMessages(
        widget.threadId,
        limit: 20,
      );
      final raw = payload['messages'] as List<dynamic>? ?? const [];
      final hasMore = (payload['has_more'] as bool?) ?? false;
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = raw.whereType<Map<String, dynamic>>().toList(
          growable: false,
        );
        _hasMoreMessages = hasMore;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlderMessages || !_hasMoreMessages || _messages.isEmpty) {
      return;
    }

    final beforeId = (_messages.first['id'] as num?)?.toInt() ?? 0;
    if (beforeId <= 0) {
      return;
    }

    final prevMaxExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final prevPixels = _scrollController.hasClients
        ? _scrollController.position.pixels
        : 0.0;

    setState(() {
      _loadingOlderMessages = true;
    });

    try {
      final payload = await widget.authController.loadSupportMessages(
        widget.threadId,
        beforeId: beforeId,
        limit: 20,
      );
      final raw = payload['messages'] as List<dynamic>? ?? const [];
      final hasMore = (payload['has_more'] as bool?) ?? false;
      final incoming = raw.whereType<Map<String, dynamic>>().toList(
        growable: false,
      );

      if (!mounted) {
        return;
      }

      final existingIds = _messages
          .map((m) => (m['id'] as num?)?.toInt() ?? 0)
          .toSet();
      final deduped = incoming
          .where((m) => !existingIds.contains((m['id'] as num?)?.toInt() ?? 0))
          .toList(growable: false);

      setState(() {
        _messages = [...deduped, ..._messages];
        _hasMoreMessages = hasMore;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final nextMaxExtent = _scrollController.position.maxScrollExtent;
        final delta = nextMaxExtent - prevMaxExtent;
        _scrollController.jumpTo(prevPixels + delta);
      });
    } catch (_) {
      // Keep current messages on pagination failure.
    } finally {
      if (mounted) {
        setState(() {
          _loadingOlderMessages = false;
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _composerController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final payload = await widget.authController.sendSupportMessage(
        threadId: widget.threadId,
        message: text,
      );
      _composerController.clear();
      final item = payload['item'];
      if (item is Map<String, dynamic>) {
        _mergeMessage(item);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: AppSurfaceCard(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFB91C1C)),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        if (_loadingOlderMessages) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        if (_hasMoreMessages) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Center(
                              child: TextButton.icon(
                                onPressed: _loadOlderMessages,
                                icon: const Icon(Icons.expand_less_rounded),
                                label: const Text('Load older messages'),
                              ),
                            ),
                          );
                        }
                        return const SizedBox(height: 8);
                      }

                      final item = _messages[index - 1];
                      final sender =
                          (item['sender'] as Map<String, dynamic>?) ??
                          const <String, dynamic>{};
                      final isAdmin =
                          item['is_admin'] == true || item['is_admin'] == 1;
                      return Align(
                        alignment: isAdmin
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppSurfaceCard(
                            padding: const EdgeInsets.all(10),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (sender['name'] ?? 'User').toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text((item['body'] ?? '').toString()),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composerController,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Write a message...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    child: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
