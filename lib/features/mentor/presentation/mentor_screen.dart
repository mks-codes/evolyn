import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:evolyn/core/widgets/top_message.dart';
import 'package:evolyn/l10n/app_localizations.dart';
import 'package:evolyn/features/roadmap/providers/roadmap_cache_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AARYA mentor chat.
///
/// Conversations and messages are stored in Supabase. Recent messages and the
/// active conversation ID are cached locally so the conversation can appear
/// immediately on re-open. Realtime keeps this screen current across devices.
class MentorScreen extends ConsumerStatefulWidget {
  const MentorScreen({super.key});

  @override
  ConsumerState<MentorScreen> createState() => _MentorScreenState();
}

class _MentorScreenState extends ConsumerState<MentorScreen> {
  static const Color _background = Color(0xFF050614);
  static const Color _panel = Color(0xFF101124);
  static const Color _border = Color(0xFF292A46);
  static const Color _purple = Color(0xFFA78BFA);
  static const Color _teal = Color(0xFF65D9DC);

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final List<_MentorMessage> _messages = <_MentorMessage>[];
  SupabaseClient get _supabase => Supabase.instance.client;

  String? _userId;
  String? _conversationId;
  RealtimeChannel? _messageChannel;
  Future<void>? _initializationFuture;
  Future<void> _cacheWriteQueue = Future<void>.value();

  bool _isInitializing = true;
  bool _isSending = false;
  bool _isRefreshing = false;
  String? _loadError;
  String? _connectionNotice;
  String? _sendError;

  bool _isFollowingBottom = true;
  static const double _bottomThreshold = 100.0;
  bool _scrollUpdateScheduled = false;
  Timer? _streamCharacterTimer;
  final Queue<String> _streamCharacterQueue = Queue<String>();
  String? _activeStreamingId;
  Map<String, dynamic>? _pendingAssistantRow;
  bool _streamDone = false;
  Completer<void>? _streamDrainCompleter;

  @override
  void initState() {
    super.initState();
    _userId = _supabase.auth.currentUser?.id;
    // Start after the first frame so localization lookups have a valid
    // inherited Localizations ancestor, including when the user is signed out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initializationFuture = _initialize();
      unawaited(_initializationFuture!);
    });
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _streamCharacterTimer?.cancel();
    final channel = _messageChannel;
    if (channel != null) unawaited(_supabase.removeChannel(channel));
    super.dispose();
  }

  String _formatMentorMarkdown(String text) => text
      .split('\n')
      .map((line) {
        final match = RegExp(r'^\s*\*\*(.+?)\*\*\s*$').firstMatch(line);
        return match == null ? line : '## ${match.group(1)!.trim()}';
      })
      .join('\n');

  String _conversationCacheKey(String userId) =>
      'evolyn.mentor.active_conversation.$userId.v1';

  String _messagesCacheKey(String userId, String conversationId) =>
      'evolyn.mentor.messages.$userId.$conversationId.v1';

  Future<void> _initialize() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _loadError = _l10n.mentorSignInToChat;
      });
      return;
    }

    _userId = user.id;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedConversationId = prefs.getString(_conversationCacheKey(user.id));
      if (cachedConversationId != null && cachedConversationId.isNotEmpty) {
        if (mounted) setState(() => _conversationId = cachedConversationId);
        final cachedJson = prefs.getString(
          _messagesCacheKey(user.id, cachedConversationId),
        );
        if (cachedJson != null && mounted) {
          final decoded = jsonDecode(cachedJson);
          if (decoded is List) {
            final cachedMessages = decoded
                .whereType<Map>()
                .map((item) => _MentorMessage.fromJsonCache(
                      Map<String, dynamic>.from(item),
                    ))
                .toList();
            setState(() {
              _conversationId = cachedConversationId;
              _messages
                ..clear()
                ..addAll(cachedMessages);
            });
          }
        }
      }
    } catch (error) {
      debugPrint('[AARYA] Could not read local chat cache: $error');
    }

    try {
      final latest = await _supabase
          .from('mentor_conversations')
          .select('id')
          .eq('user_id', user.id)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final String conversationId;
      if (latest != null && latest['id'] != null) {
        conversationId = latest['id'].toString();
      } else {
        final created = await _supabase
            .from('mentor_conversations')
            .insert(<String, dynamic>{
              'user_id': user.id,
              'title': _l10n.mentorNewConversationTitle,
            })
            .select('id')
            .single();
        conversationId = created['id'].toString();
      }

      await _switchConversation(conversationId, refreshFromServer: true);
      if (!mounted) return;
      setState(() => _loadError = null);
    } catch (error, stackTrace) {
      debugPrint('[AARYA] Chat initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        if (_conversationId == null) {
          _loadError = _l10n.mentorConnectionFailed;
        } else {
          _connectionNotice = _l10n.mentorOfflineConversation;
        }
      });
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    _isFollowingBottom = distanceFromBottom <= _bottomThreshold;
  }

  Future<void> _switchConversation(
    String conversationId, {
    required bool refreshFromServer,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    final previousConversationId = _conversationId;
    final oldChannel = _messageChannel;
    _messageChannel = null;
    if (oldChannel != null) {
      try {
        await _supabase.removeChannel(oldChannel);
      } catch (error) {
        debugPrint('[AARYA] Could not remove old channel: $error');
      }
    }

    if (!mounted) return;
    setState(() {
      _conversationId = conversationId;
      if (previousConversationId != conversationId) _messages.clear();
      _loadError = null;
      _sendError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_conversationCacheKey(userId), conversationId);
      final cachedJson = prefs.getString(_messagesCacheKey(userId, conversationId));
      if (cachedJson != null && mounted && _conversationId == conversationId) {
        final decoded = jsonDecode(cachedJson);
        if (decoded is List) {
          final cached = decoded
              .whereType<Map>()
              .map((item) => _MentorMessage.fromJsonCache(
                    Map<String, dynamic>.from(item),
                  ))
              .toList();
          setState(() {
            _messages
              ..clear()
              ..addAll(cached);
          });
        }
      }
    } catch (error) {
      debugPrint('[AARYA] Could not load conversation cache: $error');
    }

    _messageChannel = _supabase
        .channel('aarya-mentor-$userId-$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mentor_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) _acceptRemoteRow(record);
          },
        )
        .subscribe();

    if (refreshFromServer) await _refreshMessages(showSpinner: false);
  }

  Future<void> _refreshMessages({bool showSpinner = true}) async {
    final userId = _userId;
    final conversationId = _conversationId;
    if (userId == null || conversationId == null || _isRefreshing) return;
    if (showSpinner && mounted) setState(() => _isRefreshing = true);
    try {
      final rows = await _supabase
          .from('mentor_messages')
          .select('id, conversation_id, user_id, role, content, created_at')
          .eq('user_id', userId)
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(300);

      if (!mounted || _conversationId != conversationId) return;
      final byId = <String, _MentorMessage>{
        for (final message in _messages)
          if (!message.isPending) message.id: message,
      };
      for (final row in rows) {
        final message = _MentorMessage.fromJson(Map<String, dynamic>.from(row));
        byId[message.id] = message;
      }
      final merged = byId.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      setState(() {
        _messages
          ..clear()
          ..addAll(merged);
        _connectionNotice = null;
      });
      await _persistMessagesCache();
      _scrollToBottom();
    } catch (error) {
      debugPrint('[AARYA] Could not refresh chat messages: $error');
      if (mounted) {
        setState(() {
          _connectionNotice = _messages.isEmpty
              ? _l10n.mentorHistoryLoadFailed
              : _l10n.mentorOfflineMessages;
        });
      }
    } finally {
      if (mounted && showSpinner) setState(() => _isRefreshing = false);
    }
  }

  void _acceptRemoteRow(Map<String, dynamic> row) {
    if (!mounted || row['id'] == null || row['content'] == null) return;
    final incoming = _MentorMessage.fromJson(row);
    if (incoming.role == _MessageRole.assistant && _activeStreamingId != null) {
      _pendingAssistantRow = Map<String, dynamic>.from(row);
      return;
    }

    setState(() {
      if (incoming.role == _MessageRole.user) {
        final pendingIndex = _messages.indexWhere((item) =>
            item.role == _MessageRole.user &&
            item.isPending &&
            item.text == incoming.text);
        if (pendingIndex >= 0) _messages.removeAt(pendingIndex);

        final streamingIndex = _messages.indexWhere((item) => item.isStreaming);
        if (streamingIndex >= 0) {
          final streaming = _messages[streamingIndex];
          final correctedTime = incoming.createdAt.isAfter(streaming.createdAt)
              ? incoming.createdAt.add(const Duration(microseconds: 1))
              : streaming.createdAt;
          _messages[streamingIndex] = _MentorMessage(
            id: streaming.id,
            role: streaming.role,
            text: streaming.text,
            createdAt: correctedTime,
            isPending: streaming.isPending,
            isStreaming: streaming.isStreaming,
          );
        }
      } else {
        _messages.removeWhere((item) => item.isStreaming);
      }

      final existingIndex = _messages.indexWhere(
        (item) => !item.isPending && item.id == incoming.id,
      );
      if (existingIndex >= 0) {
        _messages[existingIndex] = incoming;
      } else {
        _messages.add(incoming);
      }
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    });
    unawaited(_persistMessagesCache());
    _scrollToBottom();
  }

  Future<void> _persistMessagesCache() {
    final userId = _userId;
    final conversationId = _conversationId;
    if (userId == null || conversationId == null) return Future<void>.value();
    final snapshot = _messages
        .where((message) => !message.isPending)
        .map((message) => message.toJson())
        .toList();
    final key = _messagesCacheKey(userId, conversationId);
    _cacheWriteQueue = _cacheWriteQueue.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_userId == userId && _conversationId == conversationId) {
          await prefs.setString(key, jsonEncode(snapshot));
        }
      } catch (error) {
        debugPrint('[AARYA] Could not save local chat cache: $error');
      }
    });
    return _cacheWriteQueue;
  }

  Future<void> _sendMessage({String? prompt}) async {
    if (_isSending) return;
    final text = (prompt ?? _messageController.text).trim();
    if (text.isEmpty) return;
    if (text.length > 4000) {
      _showMessage(_l10n.mentorMessageTooLong);
      return;
    }

    if (_conversationId == null) await _initializationFuture;
    final conversationId = _conversationId;
    final userId = _userId;
    final session = _supabase.auth.currentSession;
    if (conversationId == null || userId == null || session == null) {
      if (mounted) setState(() => _sendError = _l10n.mentorNoActiveConversation);
      return;
    }

    final pendingId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final streamingId = 'streaming-$pendingId';
    _streamCharacterTimer?.cancel();
    _streamCharacterQueue.clear();
    _activeStreamingId = streamingId;
    _pendingAssistantRow = null;
    _streamDone = false;
    _streamDrainCompleter = Completer<void>();

    final now = DateTime.now();
    setState(() {
      _messages.add(_MentorMessage(
        id: pendingId,
        role: _MessageRole.user,
        text: text,
        createdAt: now,
        isPending: true,
      ));
      _messages.add(_MentorMessage(
        id: streamingId,
        role: _MessageRole.assistant,
        text: '',
        createdAt: now,
        isPending: true,
        isStreaming: true,
      ));
      _isSending = true;
      _sendError = null;
      _connectionNotice = null;
    });
    _messageController.clear();
    _scrollToBottom();

    final client = http.Client();
    var gotFinalMessage = false;
    String? streamError;
    var sseBuffer = '';

    void handleEventLine(String rawLine) {
      final line = rawLine.replaceAll('\r', '').trimRight();
      if (!line.startsWith('data:')) return;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') return;
      dynamic decoded;
      try {
        decoded = jsonDecode(payload);
      } on FormatException {
        return;
      }
      if (decoded is! Map) return;
      final event = Map<String, dynamic>.from(decoded);
      final type = event['type']?.toString();
      if (type == 'user_message') {
        final row = event['user_message'];
        if (row is Map) _acceptRemoteRow(Map<String, dynamic>.from(row));
        return;
      }
      if (type == 'token') {
        final delta = event['text'];
        if (delta is String && delta.isNotEmpty && mounted) {
          _enqueueStreamingDelta(streamingId, delta);
        }
        return;
      }
      if (type == 'done') {
        final row = event['assistant_message'];
        if (row is Map) {
          gotFinalMessage = true;
          _pendingAssistantRow = Map<String, dynamic>.from(row);
          _streamDone = true;
          _finishStreamingIfReady(streamingId);
        } else {
          streamError = _l10n.mentorMissingSavedReply;
        }
        return;
      }
      if (type == 'error') {
        streamError = event['message']?.toString() ?? _l10n.mentorResponseFailed;
      }
    }

    try {
      final apiKey = _supabase.auth.headers['apikey'];
      if (apiKey == null || apiKey.isEmpty) {
        throw StateError(_l10n.mentorApiKeyUnavailable);
      }
      final supabaseBaseUrl = _supabase.rest.url.replaceFirst('/rest/v1', '');
      final functionUri = Uri.parse('$supabaseBaseUrl/functions/v1/aarya-mentor-chat');
      final request = http.Request('POST', functionUri)
        ..headers.addAll(<String, String>{
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream, application/json',
          'apikey': apiKey,
          'Authorization': 'Bearer ${session.accessToken}',
        })
        ..body = jsonEncode(<String, dynamic>{
          'conversation_id': conversationId,
          'message': text,
        });

      final response = await client.send(request).timeout(const Duration(seconds: 75));
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw StateError(_responseErrorMessage(body, response.statusCode));
      }

      if (!contentType.contains('text/event-stream')) {
        final body = await response.stream.bytesToString();
        dynamic decoded;
        try {
          decoded = jsonDecode(body);
        } on FormatException {
          throw FormatException(_l10n.mentorInvalidResponse);
        }
        if (decoded is! Map || decoded['success'] != true) {
          throw StateError(_responseErrorMessage(body, response.statusCode));
        }
        final userRow = decoded['user_message'];
        final assistantRow = decoded['assistant_message'];
        if (userRow is Map) _acceptRemoteRow(Map<String, dynamic>.from(userRow));
        if (assistantRow is Map) {
          _pendingAssistantRow = Map<String, dynamic>.from(assistantRow);
          _streamDone = true;
          _finishStreamingIfReady(streamingId);
          gotFinalMessage = true;
        } else {
          throw FormatException(_l10n.mentorReplyMissing);
        }
      } else {
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          if (!mounted || _conversationId != conversationId) break;
          sseBuffer += chunk;
          var newline = sseBuffer.indexOf('\n');
          while (newline >= 0) {
            final line = sseBuffer.substring(0, newline);
            sseBuffer = sseBuffer.substring(newline + 1);
            handleEventLine(line);
            newline = sseBuffer.indexOf('\n');
          }
        }
        if (sseBuffer.trim().isNotEmpty) handleEventLine(sseBuffer);
        if (streamError != null) throw StateError(streamError!);
        if (!gotFinalMessage) throw FormatException(_l10n.mentorStreamEndedEarly);
        await _streamDrainCompleter?.future;
      }
    } catch (error, stackTrace) {
      debugPrint('[AARYA] Streaming message failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        final rawMessage = error.toString()
            .replaceFirst('Bad state: ', '')
            .replaceFirst('FormatException: ', '');
        setState(() {
          _messages.removeWhere((message) => message.id == streamingId);
          _sendError = error is StateError || error is FormatException
              ? rawMessage
              : _l10n.mentorGenericReplyFailed;
        });
        unawaited(_refreshMessages(showSpinner: false));
      }
    } finally {
      _cancelStreaming(streamingId);
      client.close();
      if (mounted) setState(() => _isSending = false);
      unawaited(_persistMessagesCache());
      _scrollToBottom();
    }
  }

  void _enqueueStreamingDelta(String streamingId, String delta) {
    if (!mounted || _activeStreamingId != streamingId) return;
    for (final rune in delta.runes) {
      _streamCharacterQueue.add(String.fromCharCode(rune));
    }
    if (_streamCharacterTimer?.isActive ?? false) return;
    _streamCharacterTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted || _activeStreamingId != streamingId) {
        timer.cancel();
        if (identical(_streamCharacterTimer, timer)) _streamCharacterTimer = null;
        return;
      }
      if (_streamCharacterQueue.isNotEmpty) {
        _appendStreamingCharacter(streamingId, _streamCharacterQueue.removeFirst());
      }
      if (_streamCharacterQueue.isEmpty) {
        timer.cancel();
        if (identical(_streamCharacterTimer, timer)) _streamCharacterTimer = null;
        _finishStreamingIfReady(streamingId);
      }
    });
  }

  void _appendStreamingCharacter(String streamingId, String character) {
    final index = _messages.indexWhere((message) => message.id == streamingId && message.isStreaming);
    if (index < 0 || !mounted) return;
    final previous = _messages[index];
    setState(() {
      _messages[index] = _MentorMessage(
        id: previous.id,
        role: _MessageRole.assistant,
        text: previous.text + character,
        createdAt: previous.createdAt,
        isPending: true,
        isStreaming: true,
      );
    });
    _scrollToBottom(duration: Duration.zero);
  }

  void _finishStreamingIfReady(String streamingId) {
    if (_activeStreamingId != streamingId || !_streamDone || _streamCharacterQueue.isNotEmpty) return;
    _streamCharacterTimer?.cancel();
    _streamCharacterTimer = null;
    final assistantRow = _pendingAssistantRow;
    _activeStreamingId = null;
    _pendingAssistantRow = null;
    _streamDone = false;
    if (mounted) {
      setState(() => _messages.removeWhere((message) => message.id == streamingId));
      if (assistantRow != null) _acceptRemoteRow(assistantRow);
      _scrollToBottom();
    }
    final completer = _streamDrainCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _cancelStreaming(String streamingId) {
    if (_activeStreamingId != streamingId) return;
    _streamCharacterTimer?.cancel();
    _streamCharacterTimer = null;
    _streamCharacterQueue.clear();
    _activeStreamingId = null;
    _pendingAssistantRow = null;
    _streamDone = false;
    final completer = _streamDrainCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  String _responseErrorMessage(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] != null) return decoded['message'].toString();
      if (decoded is Map && decoded['error'] is Map) {
        final error = Map<String, dynamic>.from(decoded['error'] as Map);
        if (error['message'] != null) return error['message'].toString();
      }
    } catch (_) {
      // Use a localized status fallback if the body is not JSON.
    }
    return _l10n.mentorRequestFailed(statusCode);
  }

  Future<void> _createNewConversation() async {
    final userId = _userId;
    if (userId == null || _isSending) return;
    try {
      final row = await _supabase
          .from('mentor_conversations')
          .insert(<String, dynamic>{
            'user_id': userId,
            'title': _l10n.mentorNewConversationTitle,
          })
          .select('id')
          .single();
      await _switchConversation(row['id'].toString(), refreshFromServer: false);
    } catch (error) {
      debugPrint('[AARYA] Could not create conversation: $error');
      _showMessage(_l10n.mentorCreateConversationFailed);
    }
  }

  Future<void> _showConversationHistory() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final rows = await _supabase
          .from('mentor_conversations')
          .select('id, title, updated_at, created_at')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: _panel,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_l10n.mentorConversationHistory, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(child: Text(_l10n.mentorNoConversations, style: const TextStyle(color: Colors.white60)))
                        : ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, __) => const Divider(color: _border, height: 1),
                            itemBuilder: (context, index) {
                              final row = Map<String, dynamic>.from(rows[index] as Map);
                              final id = row['id'].toString();
                              final rawTitle = row['title']?.toString() ?? '';
                              final title = rawTitle.trim().isNotEmpty ? rawTitle : _l10n.mentorDefaultConversationTitle;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFF211A40),
                                  child: Icon(Icons.chat_bubble_outline_rounded, color: _purple),
                                ),
                                title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                                subtitle: Text(_formatDate(row['updated_at'] ?? row['created_at']), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                trailing: id == _conversationId
                                    ? const Icon(Icons.check_circle, color: _teal)
                                    : const Icon(Icons.chevron_right, color: Colors.white54),
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  unawaited(_switchConversation(id, refreshFromServer: true));
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(_createNewConversation());
                      },
                      icon: const Icon(Icons.add_comment_outlined),
                      label: Text(_l10n.mentorStartNewConversation),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      debugPrint('[AARYA] Could not load conversation history: $error');
      _showMessage(_l10n.mentorHistoryFailed);
    }
  }

  void _showMoreOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_l10n.mentorOptions, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _optionTile(
                icon: Icons.history_rounded,
                title: _l10n.mentorConversationHistory,
                subtitle: _l10n.mentorOpenPreviousChat,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_showConversationHistory());
                },
              ),
              _optionTile(
                icon: Icons.add_comment_outlined,
                title: _l10n.mentorNewConversation,
                subtitle: _l10n.mentorStartSeparateChat,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_createNewConversation());
                },
              ),
              _optionTile(
                icon: Icons.refresh_rounded,
                title: _l10n.mentorRefreshMessages,
                subtitle: _l10n.mentorSyncChat,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_refreshMessages());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _nextTaskTitle(RoadmapRow? row) {
    if (row == null) return null;
    final rawRoadmap = row['roadmap_data'];
    final roadmap = rawRoadmap is Map ? Map<String, dynamic>.from(rawRoadmap) : row;
    final phases = roadmap['phases'];
    if (phases is List) {
      for (final phaseValue in phases) {
        if (phaseValue is! Map) continue;
        final phase = Map<String, dynamic>.from(phaseValue);
        final tasks = phase['tasks'];
        if (tasks is! List) continue;
        for (final taskValue in tasks) {
          if (taskValue is! Map) continue;
          final task = Map<String, dynamic>.from(taskValue);
          if (task['completed'] != true && task['title']?.toString().trim().isNotEmpty == true) {
            return task['title'].toString();
          }
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final userId = _supabase.auth.currentUser?.id;
    final roadmapRow = userId == null ? null : ref.watch(userRoadmapProvider(userId)).asData?.value;
    final nextTaskTitle = _nextTaskTitle(roadmapRow);

    return Scaffold(
      backgroundColor: _background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildMentorContext(nextTaskTitle),
            if (_connectionNotice != null) _buildConnectionNotice(),
            if (_loadError != null && _messages.isEmpty)
              Expanded(child: _buildLoadError())
            else
              Expanded(child: _buildConversation()),
            if (_sendError != null) _buildSendError(),
            if (!keyboardVisible) _buildSuggestedPrompts(nextTaskTitle),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Row(
        children: [
          const _AaryaAvatar(size: 46),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AARYA', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
                const SizedBox(height: 4),
                Text(
                  _isInitializing ? _l10n.mentorLoadingConversation : _l10n.mentorSubtitle,
                  style: TextStyle(color: Colors.white.withOpacity(0.44), fontSize: 10.5),
                ),
              ],
            ),
          ),
          _headerAction(icon: Icons.add_comment_outlined, tooltip: _l10n.mentorNewConversation, onTap: _createNewConversation),
          const SizedBox(width: 8),
          _headerAction(icon: Icons.more_horiz_rounded, tooltip: _l10n.mentorOptions, onTap: _showMoreOptions),
        ],
      ),
    );
  }

  Widget _headerAction({required IconData icon, required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFF111226),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: const BorderSide(color: _border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 19, color: const Color(0xFFB9B0D8))),
        ),
      ),
    );
  }

  Widget _buildMentorContext(String? nextTaskTitle) {
    final hasTask = nextTaskTitle != null;
    final l10n = _l10n;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _sendMessage(
          prompt: hasTask ? l10n.mentorAskNextTaskPrompt(nextTaskTitle) : l10n.mentorChooseNextStepPrompt,
        ),
        borderRadius: BorderRadius.circular(17),
        child: Container(
          margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF171832), Color(0xFF111E2B)]),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFF343052)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: _purple.withOpacity(0.14), borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.track_changes_rounded, color: Color(0xFFB8A4FF), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.mentorCurrentFocus, style: const TextStyle(color: Color(0xFFA99BE6), fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                    const SizedBox(height: 4),
                    Text(
                      nextTaskTitle ?? l10n.mentorAskNextStep,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF8F84B8)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionNotice() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF15132B), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF332A59))),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: _purple, size: 14),
          const SizedBox(width: 7),
          Expanded(child: Text(_connectionNotice!, style: const TextStyle(color: Colors.white70, fontSize: 9))),
          TextButton(onPressed: () => _refreshMessages(), child: Text(_l10n.mentorRetry, style: const TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, color: _purple, size: 38),
            const SizedBox(height: 12),
            Text(_loadError ?? _l10n.mentorConversationUnavailable, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.4)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isInitializing = true;
                  _loadError = null;
                });
                _initializationFuture = _initialize();
                unawaited(_initializationFuture!);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_l10n.mentorRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation() {
    if (_isInitializing && _messages.isEmpty) return const Center(child: CircularProgressIndicator(color: _purple));
    final showWelcome = _messages.isEmpty && !_isSending;
    final itemCount = 1 + (showWelcome ? 1 : _messages.length);
    return RefreshIndicator(
      onRefresh: () => _refreshMessages(),
      color: _purple,
      backgroundColor: _panel,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == 0) return _buildDayDivider();
          if (showWelcome && index == 1) return _buildWelcome();
          final message = _messages[index - 1];
          if (message.isStreaming && message.text.isEmpty) return _buildTypingIndicator();
          return _buildMessage(message);
        },
      ),
    );
  }

  Widget _buildWelcome() {
    final l10n = _l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 24),
      child: Column(
        children: [
          const _AaryaAvatar(size: 64),
          const SizedBox(height: 16),
          Text(l10n.mentorWelcomeTitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(l10n.mentorWelcomeDescription, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.48), fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildDayDivider() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white.withOpacity(0.07))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(_l10n.mentorConversationDivider, style: TextStyle(color: Colors.white.withOpacity(0.27), fontSize: 8, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
          ),
          Expanded(child: Divider(color: Colors.white.withOpacity(0.07))),
        ],
      ),
    );
  }

  Widget _buildMessage(_MentorMessage message) {
    final isMentor = message.role == _MessageRole.assistant;
    final status = message.isStreaming ? _l10n.mentorTyping : message.isPending ? _l10n.mentorSending : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Row(
        mainAxisAlignment: isMentor ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isMentor) ...[const _AaryaAvatar(size: 29), const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: isMentor ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMentor ? _panel : const Color(0xFF34245E),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMentor ? 5 : 16),
                      bottomRight: Radius.circular(isMentor ? 16 : 5),
                    ),
                    border: Border.all(color: isMentor ? _border : const Color(0xFF57418B)),
                  ),
                  child: isMentor
                      ? MarkdownBody(
                          data: _formatMentorMarkdown(message.text) + (message.isStreaming ? '▍' : ''),
                          selectable: true,
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12.5, height: 1.5),
                            strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            em: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
                            h1: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700, height: 1.35),
                            h2: const TextStyle(color: Color(0xFFC6B8FF), fontSize: 16, fontWeight: FontWeight.w700, height: 1.4),
                            h3: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, height: 1.4),
                            h2Padding: const EdgeInsets.only(top: 6, bottom: 4),
                            h3Padding: const EdgeInsets.only(top: 5, bottom: 3),
                            code: const TextStyle(color: Color(0xFFE1D9FF), fontSize: 11.5, fontFamily: 'monospace', backgroundColor: Color(0xFF25213D)),
                            codeblockDecoration: BoxDecoration(color: const Color(0xFF08091A), borderRadius: BorderRadius.circular(9), border: Border.all(color: _border)),
                            codeblockPadding: const EdgeInsets.all(10),
                            blockSpacing: 8,
                            listBullet: const TextStyle(color: _purple, fontSize: 12.5),
                          ),
                        )
                      : Text(message.text, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12.5, height: 1.5)),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_formatTime(message.createdAt)}${status == null ? '' : ' · $status'}',
                  style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 8.5),
                ),
              ],
            ),
          ),
          if (!isMentor) const SizedBox(width: 3),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 37),
      child: Row(
        children: [
          const _AaryaAvatar(size: 27),
          const SizedBox(width: 8),
          Text(_l10n.mentorThinking, style: const TextStyle(color: Colors.white60, fontSize: 10)),
          const SizedBox(width: 8),
          const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.6, color: _purple)),
        ],
      ),
    );
  }

  Widget _buildSendError() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFF351A2A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF78354E))),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 15, color: Color(0xFFFFA5B5)),
          const SizedBox(width: 7),
          Expanded(child: Text(_sendError!, style: const TextStyle(color: Color(0xFFFFC1CB), fontSize: 9.5))),
          IconButton(visualDensity: VisualDensity.compact, onPressed: () => setState(() => _sendError = null), icon: const Icon(Icons.close, size: 15), color: Colors.white54),
        ],
      ),
    );
  }

  Widget _buildSuggestedPrompts(String? nextTaskTitle) {
    final l10n = _l10n;
    final prompts = <String>[
      if (nextTaskTitle != null) l10n.mentorSuggestedRoadmapTask,
      l10n.mentorSuggestedExplainConcept,
      l10n.mentorSuggestedStudySession,
      l10n.mentorSuggestedInterview,
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ActionChip(
          onPressed: _isSending
              ? null
              : () {
                  final selected = prompts[index];
                  final String message;
                  if (nextTaskTitle != null && selected == l10n.mentorSuggestedRoadmapTask) {
                    message = l10n.mentorSuggestedTaskPrompt(nextTaskTitle);
                  } else if (selected == l10n.mentorSuggestedExplainConcept) {
                    message = l10n.mentorExplainConceptPrompt;
                  } else if (selected == l10n.mentorSuggestedStudySession) {
                    message = l10n.mentorStudySessionPrompt;
                  } else {
                    message = l10n.mentorInterviewPrompt;
                  }
                  _sendMessage(prompt: message);
                },
          backgroundColor: const Color(0xFF101126),
          side: const BorderSide(color: _border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          label: Text(prompts[index], style: const TextStyle(color: Color(0xFFB9B0D8), fontSize: 10, fontWeight: FontWeight.w500)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final l10n = _l10n;
    final canSend = !_isSending && !_isInitializing && _userId != null && _conversationId != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 12),
      decoration: BoxDecoration(color: const Color(0xFF08091A), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, maxHeight: 120),
              decoration: BoxDecoration(color: const Color(0xFF111226), borderRadius: BorderRadius.circular(15), border: Border.all(color: _border)),
              child: TextField(
                controller: _messageController,
                focusNode: _inputFocusNode,
                enabled: canSend,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: canSend ? l10n.mentorInputHint : _isSending ? l10n.mentorWaitingForReply : l10n.mentorConnecting,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 12),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: canSend ? const Color(0xFF8B5CF6) : const Color(0xFF302947),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: canSend ? _sendMessage : null,
              child: SizedBox(width: 44, height: 44, child: Icon(_isSending ? Icons.hourglass_top_rounded : Icons.arrow_upward_rounded, color: Colors.white, size: 20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: const Color(0xFF211A40), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: const Color(0xFFB7A5FF), size: 19),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.42), fontSize: 10)),
      onTap: onTap,
    );
  }

  void _scrollToBottom({Duration duration = const Duration(milliseconds: 180), bool force = false}) {
    if (!mounted || !_scrollController.hasClients) return;
    if (!_isFollowingBottom && !force) return;
    if (_scrollUpdateScheduled) return;
    _scrollUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollUpdateScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;
      if (!_isFollowingBottom && !force) return;
      final position = _scrollController.position;
      final target = position.maxScrollExtent;
      if ((position.pixels - target).abs() < 1.0) return;
      if (duration == Duration.zero) {
        _scrollController.jumpTo(target);
      } else {
        _scrollController.animateTo(target, duration: duration, curve: Curves.easeOutCubic);
      }
    });
  }

  String _formatTime(DateTime value) {
    final time = TimeOfDay.fromDateTime(value.toLocal());
    return MaterialLocalizations.of(context).formatTimeOfDay(time);
  }

  String _formatDate(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return _l10n.mentorSavedConversation;
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

void _showMessage(String text) {
  if (!mounted) return;
  TopMessage.show(context, text);
}
}

class _AaryaAvatar extends StatelessWidget {
  final double size;
  const _AaryaAvatar({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF9B83FF), width: 1.2),
        boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.16), blurRadius: 10)],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/female_mentor.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFF211A40),
            alignment: Alignment.center,
            child: Icon(Icons.auto_awesome_rounded, color: const Color(0xFFC7BCFF), size: size * 0.48),
          ),
        ),
      ),
    );
  }
}

enum _MessageRole { user, assistant }

class _MentorMessage {
  const _MentorMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.isPending = false,
    this.isStreaming = false,
  });

  final String id;
  final _MessageRole role;
  final String text;
  final DateTime createdAt;
  final bool isPending;
  final bool isStreaming;

  factory _MentorMessage.fromJson(Map<String, dynamic> json) => _MentorMessage(
        id: json['id']?.toString() ?? 'local-${DateTime.now().microsecondsSinceEpoch}',
        role: json['role']?.toString() == 'assistant' ? _MessageRole.assistant : _MessageRole.user,
        text: json['content']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      );

  factory _MentorMessage.fromJsonCache(Map<String, dynamic> json) => _MentorMessage(
        id: json['id']?.toString() ?? '',
        role: json['role'] == 'assistant' ? _MessageRole.assistant : _MessageRole.user,
        text: json['text']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'role': role == _MessageRole.assistant ? 'assistant' : 'user',
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };
}
