import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/auth_service.dart';

class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _messageController = TextEditingController();
  late final StreamSubscription<List<Map<String, dynamic>>>
      _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messagesSubscription.cancel();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await Supabase.instance.client
          .from('messages')
          .select('*')
          .eq('conversation_id', widget.conversationId)
          .order('sent_at', ascending: true);

      _messages = List<Map<String, dynamic>>.from(data);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load messages: ${e.toString()}';
        _isLoading = false;
      });
      print('Error fetching messages: $e');
    }
  }

  void _subscribeToMessages() {
    _messagesSubscription = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .order('sent_at', ascending: true)
        .listen((List<Map<String, dynamic>> data) {
          // This stream provides the entire list of messages whenever there's a change
          setState(() {
            _messages = data;
          });
        }, onError: (error) {
          print('Error in messages stream: $error');
          // Handle stream errors if necessary
        });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final currentUser = AuthService().currentUser; // Get the current user
    if (currentUser == null) {
      // Handle case where user is not logged in (shouldn't happen if navigated correctly)
      print('Error: Cannot send message, user not logged in.');
      return;
    }

    final newMessage = {
      'conversation_id': widget.conversationId,
      'sender_id': currentUser.id,
      'content': _messageController.text.trim(),
      // sent_at is defaulted by the database
    };

    try {
      // Insert the new message
      await Supabase.instance.client.from('messages').insert(newMessage);
      // The stream listener will pick up the new message and update the UI
      _messageController.clear();
    } catch (e) {
      print('Error sending message: $e');
      // Show an error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: ${e.toString()}'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser =
        AuthService().currentUser; // Get the current user for comparison

    return Scaffold(
      appBar: AppBar(
        title:
            Text('Conversation: ${widget.conversationId}'), // Placeholder title
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.defaultPadding),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isSender =
                              message['sender_id'] == currentUser?.id;

                          return Align(
                            alignment: isSender
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              margin: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 8),
                              decoration: BoxDecoration(
                                color: isSender
                                    ? AppTheme.primaryBlue
                                    : AppTheme.textGrey.withOpacity(0.2),
                                borderRadius: isSender
                                    ? const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      )
                                    : const BorderRadius.only(
                                        topRight: Radius.circular(12),
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                              ),
                              child: Text(
                                message['content'] as String,
                                style: TextStyle(
                                  color: isSender
                                      ? AppTheme.backgroundWhite
                                      : AppTheme.textDark,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.defaultPadding),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Enter message',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: AppTheme.textGrey.withOpacity(0.1),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                              onSubmitted: (_) =>
                                  _sendMessage(), // Send on enter key
                            ),
                          ),
                          const SizedBox(width: 8),
                          FloatingActionButton.small(
                            onPressed: _sendMessage,
                            backgroundColor: AppTheme.primaryBlue,
                            child: const Icon(Icons.send,
                                color: AppTheme.backgroundWhite),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
