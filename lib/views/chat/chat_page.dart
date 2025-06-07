import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;

  const ChatPage({
    super.key,
    required this.conversationId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _error;
  final _messageController = TextEditingController();
  Map<String, dynamic>? _conversation;
  final List<Map<String, dynamic>> _groupMembers = [];
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();
  String? _currentUserId;
  User? _currentUser;
  final _uuid = const Uuid();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    try {
      print('Initializing chat page...');
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');

      if (userJson == null) {
        throw Exception('User not authenticated');
      }

      final userData = jsonDecode(userJson) as Map<String, dynamic>;
      _currentUser = User.fromJson(userData);
      _currentUserId = _currentUser!.id;

      print('Using user with ID: $_currentUserId');

      if (_currentUserId == null) {
        throw Exception('User ID is null');
      }

      // Check if user exists in users table
      final existingUser = await supabase.Supabase.instance.client
          .from('users')
          .select()
          .eq('id', _currentUserId!)
          .maybeSingle();

      if (existingUser == null) {
        // Create user in users table if not exists
        final userData = {
          'id': _currentUser!.id,
          'full_name': _currentUser!.fullName,
          'email': _currentUser!.email,
          'password': _currentUser!.password ?? 'default_password',
          'role': _currentUser!.role.toString().split('.').last,
          'avatar_url': _currentUser!.avatarUrl,
          'created_at': _currentUser!.createdAt.toIso8601String(),
        };

        await supabase.Supabase.instance.client.from('users').insert(userData);
      }

      setState(() {
        _isLoading = false;
      });

      // Load conversation
      await _loadConversation();
    } catch (e) {
      print('Error initializing user: $e');
      setState(() {
        _error = 'Error initializing chat: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadConversation() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch conversation details
      print('Fetching conversation details for ID: ${widget.conversationId}');
      final conversationData = await supabase.Supabase.instance.client
          .from('conversations')
          .select()
          .eq('id', widget.conversationId)
          .single();

      print('Conversation data fetched: $conversationData');

      // Fetch messages
      print('Fetching messages for conversation ID: ${widget.conversationId}');
      final messagesData =
          await supabase.Supabase.instance.client.from('messages').select('''
            *,
            sender:sender_id (
              id,
              full_name,
              avatar_url,
              role
            )
          ''').eq('conversation_id', widget.conversationId).order('sent_at');

      print('Raw messages data fetched: $messagesData');
      print('Number of messages fetched: ${messagesData.length}');

      if (!mounted) return;

      setState(() {
        _conversation = conversationData;
        _messages = List<Map<String, dynamic>>.from(messagesData);
        _isLoading = false;
      });

      // Scroll to bottom after loading messages
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
      print('Error loading conversation: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load conversation: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    if (_isSending) return;

    try {
      setState(() {
        _isSending = true;
      });

      if (_currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Create message data
      final message = {
        'conversation_id': widget.conversationId,
        'content': _messageController.text.trim(),
        'sent_at': DateTime.now().toIso8601String(),
        'sender_id': _currentUser!.id,
        'is_read': false,
      };

      print('Sending message with data: $message');

      // Insert message into database
      final response = await supabase.Supabase.instance.client
          .from('messages')
          .insert(message)
          .select()
          .single();

      print('Message sent successfully: $response');

      _messageController.clear();
      await _loadConversation();
    } catch (e) {
      print('Error sending message: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: ${e.toString()}'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chat'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.errorRed),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_error == 'Please log in to access chat')
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Go to Login'),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2196F3),
        title: Row(
          children: [
            if (_conversation?['is_group'] == true && _groupMembers.isNotEmpty)
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Text(
                  _groupMembers.length.toString(),
                  style: const TextStyle(
                    color: Color(0xFF2196F3),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.person,
                  color: Color(0xFF2196F3),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _conversation?['title'] ?? 'Chat',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_conversation?['is_group'] == true)
                    Text(
                      '${_groupMembers.length} members',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'No messages yet. Start the conversation!',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding:
                              const EdgeInsets.all(AppTheme.defaultPadding),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessageBubble(_messages[index]);
                          },
                        ),
                ),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isCurrentUser = message['sender_id'] == _currentUserId;
    final sender = message['sender'] as Map<String, dynamic>?;
    final senderName = sender?['full_name']?.toString() ?? 'Unknown';
    final content = message['content']?.toString() ?? '';

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isCurrentUser ? const Color(0xFF2196F3) : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isCurrentUser ? const Radius.circular(12) : Radius.zero,
            bottomRight:
                isCurrentUser ? Radius.zero : const Radius.circular(12),
          ),
        ),
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment:
              isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isCurrentUser)
              Text(
                senderName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            Padding(
              padding: EdgeInsets.only(top: !isCurrentUser ? 4.0 : 0.0),
              child: Text(
                content,
                style: TextStyle(
                  fontSize: 16,
                  color: isCurrentUser ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.defaultPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(25),
            ),
            child: IconButton(
              onPressed: () {
                // TODO: Implement attachment functionality
              },
              icon: const Icon(Icons.attach_file),
              color: const Color(0xFF2196F3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                style: const TextStyle(color: Colors.black87),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3),
              borderRadius: BorderRadius.circular(25),
            ),
            child: IconButton(
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
