import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';

class ChatDetailPage extends StatefulWidget {
  final String conversationId;

  const ChatDetailPage({
    super.key,
    required this.conversationId,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _messages = [];
  String? _error;
  Map<String, dynamic>? _conversation;

  @override
  void initState() {
    super.initState();
    _loadConversation();
    _loadMessages();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    supabase.Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .listen((data) {
          if (data.isNotEmpty) {
            _loadMessages();
          }
        });
  }

  Future<void> _loadConversation() async {
    try {
      final response = await supabase.Supabase.instance.client
          .from('conversations')
          .select('''
            *,
            participants:conversation_participants(
              user:users(
                id,
                full_name,
                avatar_url
              )
            )
          ''')
          .eq('id', widget.conversationId)
          .single();

      setState(() {
        _conversation = response;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMessages() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await supabase.Supabase.instance.client
          .from('messages')
          .select('''
            *,
            sender:users(
              id,
              full_name,
              avatar_url
            )
          ''')
          .eq('conversation_id', widget.conversationId)
          .order('sent_at', ascending: true);

      setState(() {
        _messages = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      // Scroll to bottom after messages load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final user = supabase.Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.Supabase.instance.client.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': user.id,
        'content': _messageController.text.trim(),
      });

      // Update conversation's last_message and updated_at
      await supabase.Supabase.instance.client.from('conversations').update({
        'last_message': _messageController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.conversationId);

      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        supabase.Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: CustomAppBar(
        title: _conversation != null ? _getOtherParticipantName() : 'Chat',
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: Show chat options menu
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No messages yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final isMe =
                                  message['sender_id'] == currentUserId;

                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? AppTheme.primaryBlue
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.75,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe) ...[
                                        Text(
                                          message['sender']['full_name'] ??
                                              'Unknown User',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                      ],
                                      Text(
                                        message['content'],
                                        style: TextStyle(
                                          color: isMe
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatTime(message['sent_at']),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isMe
                                              ? Colors.white.withOpacity(0.7)
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  color: AppTheme.primaryBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getOtherParticipantName() {
    if (_conversation == null) return 'Chat';
    final participants =
        List<Map<String, dynamic>>.from(_conversation!['participants'] ?? []);
    final currentUserId =
        supabase.Supabase.instance.client.auth.currentUser?.id;
    final otherParticipant = participants.firstWhere(
      (p) => p['user']['id'] != currentUserId,
      orElse: () => {
        'user': {'full_name': 'Unknown User'}
      },
    );
    return otherParticipant['user']['full_name'] ?? 'Unknown User';
  }

  String _formatTime(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}
