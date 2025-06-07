import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/theme/app_theme.dart';

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
            0.0,
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 768;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBlue.withOpacity(0.05),
              Colors.white,
              AppTheme.primaryBlue.withOpacity(0.02),
            ],
          ),
        ),
        child: Column(
          children: [
            // Modern Header
            _buildModernHeader(context, isTablet),

            // Messages Area
            Expanded(
              child: _isLoading
                  ? _buildLoadingState(context, isTablet)
                  : _error != null
                      ? _buildErrorState(context, isTablet)
                      : _messages.isEmpty
                          ? _buildEmptyState(context, isTablet)
                          : _buildMessagesList(context, isTablet),
            ),

            // Message Input
            _buildMessageInput(context, isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Back Button
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            SizedBox(width: isTablet ? 16 : 12),

            // Avatar
            Container(
              width: isTablet ? 48 : 40,
              height: isTablet ? 48 : 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.successGreen,
                    AppTheme.successGreen.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.successGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: isTablet ? 24 : 20,
              ),
            ),
            SizedBox(width: isTablet ? 16 : 12),

            // Title and Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _conversation != null ? _getOtherParticipantName() : 'Chat',
                    style: TextStyle(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Online',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.call, color: Colors.white, size: 20),
                    onPressed: () {
                      // TODO: Implement call functionality
                    },
                  ),
                ),
                SizedBox(width: isTablet ? 8 : 6),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {
                      // TODO: Show chat options menu
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, bool isTablet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.withOpacity(0.1),
                  AppTheme.primaryBlue.withOpacity(0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: isTablet ? 24 : 20),
          Text(
            'Loading messages...',
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isTablet) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(isTablet ? 40 : 32),
        margin: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.errorRed.withOpacity(0.1),
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.errorRed.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: isTablet ? 48 : 40,
                color: AppTheme.errorRed,
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Text(
              'Failed to load messages',
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.errorRed,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTablet ? 12 : 8),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTablet ? 20 : 16),
            ElevatedButton.icon(
              onPressed: _loadMessages,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 20,
                  vertical: isTablet ? 12 : 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isTablet) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(isTablet ? 40 : 32),
        margin: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBlue.withOpacity(0.1),
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.primaryBlue.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: isTablet ? 48 : 40,
                color: AppTheme.primaryBlue,
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Text(
              'No messages yet',
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTablet ? 12 : 8),
            Text(
              'Start the conversation by sending a message',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(BuildContext context, bool isTablet) {
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[_messages.length - 1 - index];
        final isCurrentUser = message['sender_id'] ==
            supabase.Supabase.instance.client.auth.currentUser?.id;

        return _buildMessageBubble(message, isCurrentUser, context, isTablet);
      },
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> message,
    bool isCurrentUser,
    BuildContext context,
    bool isTablet,
  ) {
    final content = message['content'] as String;
    final sentAt = message['sent_at'] as String;
    final sender = message['sender'] as Map<String, dynamic>?;
    final senderName = sender?['full_name'] as String? ?? 'Unknown';

    return Container(
      margin: EdgeInsets.only(
        bottom: isTablet ? 16 : 12,
        left: isCurrentUser ? (isTablet ? 80 : 60) : 0,
        right: isCurrentUser ? 0 : (isTablet ? 80 : 60),
      ),
      child: Column(
        crossAxisAlignment:
            isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            Padding(
              padding: EdgeInsets.only(
                left: isTablet ? 16 : 12,
                bottom: isTablet ? 8 : 6,
              ),
              child: Text(
                senderName,
                style: TextStyle(
                  fontSize: isTablet ? 12 : 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          ],

          // Message Bubble
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 12 : 10,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isCurrentUser
                    ? [
                        AppTheme.primaryBlue,
                        AppTheme.primaryBlue.withOpacity(0.8),
                      ]
                    : [
                        Colors.white,
                        Colors.grey[50]!,
                      ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isCurrentUser ? 20 : 4),
                bottomRight: Radius.circular(isCurrentUser ? 4 : 20),
              ),
              border: Border.all(
                color: isCurrentUser
                    ? AppTheme.primaryBlue.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isCurrentUser
                      ? AppTheme.primaryBlue.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
                if (isCurrentUser)
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Text(
              content,
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: isCurrentUser ? Colors.white : Colors.grey[800],
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),

          // Timestamp
          Padding(
            padding: EdgeInsets.only(
              top: isTablet ? 8 : 6,
              left: isCurrentUser ? 0 : (isTablet ? 16 : 12),
              right: isCurrentUser ? (isTablet ? 16 : 12) : 0,
            ),
            child: Text(
              _formatMessageTime(sentAt),
              style: TextStyle(
                fontSize: isTablet ? 11 : 10,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(BuildContext context, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            AppTheme.primaryBlue.withOpacity(0.02),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attachment Button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue.withOpacity(0.1),
                    AppTheme.primaryBlue.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryBlue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.attach_file,
                  color: AppTheme.primaryBlue,
                  size: isTablet ? 24 : 20,
                ),
                onPressed: () {
                  // TODO: Implement file attachment
                },
              ),
            ),
            SizedBox(width: isTablet ? 12 : 8),

            // Message Input Field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      Colors.grey[50]!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: Colors.grey[500],
                      fontSize: isTablet ? 16 : 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 16,
                      vertical: isTablet ? 12 : 10,
                    ),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            SizedBox(width: isTablet ? 12 : 8),

            // Send Button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.primaryBlue.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  Icons.send,
                  color: Colors.white,
                  size: isTablet ? 24 : 20,
                ),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getOtherParticipantName() {
    if (_conversation == null) return 'Chat';

    final participants = _conversation!['participants'] as List?;
    if (participants == null || participants.isEmpty) return 'Chat';

    final currentUserId =
        supabase.Supabase.instance.client.auth.currentUser?.id;

    for (final participant in participants) {
      final user = participant['user'] as Map<String, dynamic>?;
      if (user != null && user['id'] != currentUserId) {
        return user['full_name'] as String? ?? 'Unknown User';
      }
    }

    return 'Chat';
  }

  String _formatMessageTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else {
        return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
