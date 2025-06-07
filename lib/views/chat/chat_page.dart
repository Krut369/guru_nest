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

      // Fetch conversation members
      final membersData = await supabase.Supabase.instance.client
          .from('conversation_members')
          .select('''
            user_id,
            users!inner(id, full_name, avatar_url)
          ''').eq('conversation_id', widget.conversationId);

      final members = List<Map<String, dynamic>>.from(membersData);
      _groupMembers.clear();
      _groupMembers.addAll(
          members.map((m) => m['users'] as Map<String, dynamic>).toList());

      // Fetch messages
      print('Fetching messages for conversation ID: ${widget.conversationId}');
      final messagesData = await supabase.Supabase.instance.client
          .from('messages')
          .select('''*,sender:sender_id (id,
        full_name,
        avatar_url,
        role
      )
    ''')
          .eq('conversation_id', widget.conversationId)
          .order('sent_at', ascending: true); // Corrected typo

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

    // Check if current user is a student - check both role enum and string
    final isStudent =
        _currentUser?.role.toString().toLowerCase().contains('student') ==
                true ||
            _currentUser?.role == 'student';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2196F3),
        actions: [
          if (_conversation?['is_group'] == true)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) async {
                switch (value) {
                  case 'delete_group':
                    if (!isStudent) {
                      await _showDeleteGroupDialog();
                    }
                    break;
                  case 'edit_members':
                    if (!isStudent) {
                      await _showEditMembersDialog();
                    }
                    break;
                  case 'leave_group':
                    await _leaveGroup();
                    break;
                  case 'clear_chat':
                    await _showClearChatDialog();
                    break;
                }
              },
              itemBuilder: (context) => [
                // Only show Edit Members and Delete Group for teachers
                if (!isStudent) ...[
                  const PopupMenuItem(
                    value: 'edit_members',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit Members'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete_group',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete Group',
                            style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                // Show Leave Group for all users
                const PopupMenuItem(
                  value: 'leave_group',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app),
                      SizedBox(width: 8),
                      Text('Leave Group'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_chat',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Clear Chat',
                          style: TextStyle(color: Colors.orange)),
                    ],
                  ),
                ),
              ],
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) async {
                switch (value) {
                  case 'clear_chat':
                    await _showClearChatDialog();
                    break;
                  case 'delete_chat':
                    await _showDeleteSingleChatDialog();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear_chat',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Clear Chat',
                          style: TextStyle(color: Colors.orange)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete_chat',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Chat', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
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
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Members',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                              if (_conversation?['is_group'] == true &&
                                  !isStudent)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) async {
                                    Navigator.pop(
                                        context); // Close the modal first
                                    switch (value) {
                                      case 'edit_members':
                                        await _showEditMembersDialog();
                                        break;
                                      case 'delete_group':
                                        await _showDeleteGroupDialog();
                                        break;
                                      case 'leave_group':
                                        await _leaveGroup();
                                        break;
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    // Only show Edit Members and Delete Group for teachers
                                    if (!isStudent) ...[
                                      const PopupMenuItem(
                                        value: 'edit_members',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit),
                                            SizedBox(width: 8),
                                            Text('Edit Members'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete_group',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete,
                                                color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete Group',
                                                style: TextStyle(
                                                    color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                    // Show Leave Group for all users
                                    const PopupMenuItem(
                                      value: 'leave_group',
                                      child: Row(
                                        children: [
                                          Icon(Icons.exit_to_app),
                                          SizedBox(width: 8),
                                          Text('Leave Group'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 16),
                          if (_groupMembers.isEmpty)
                            const Text('No members found')
                          else
                            Expanded(
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _groupMembers.length,
                                itemBuilder: (context, index) {
                                  final member = _groupMembers[index];
                                  final isCurrentUser =
                                      member['id'] == _currentUserId;
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF2196F3),
                                      child: member['avatar_url'] != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(25),
                                              child: Image.network(
                                                member['avatar_url'],
                                                width: 50,
                                                height: 50,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error,
                                                    stackTrace) {
                                                  return const Icon(
                                                      Icons.person,
                                                      color: Colors.white);
                                                },
                                              ),
                                            )
                                          : const Icon(Icons.person,
                                              color: Colors.white),
                                    ),
                                    title: Text(
                                      member['full_name'] ?? 'Unknown',
                                      style: TextStyle(
                                        fontWeight: isCurrentUser
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: isCurrentUser
                                        ? const Text('You')
                                        : null,
                                    trailing: _conversation?['is_group'] ==
                                                true &&
                                            !isCurrentUser &&
                                            !isStudent
                                        ? PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert),
                                            onSelected: (value) async {
                                              switch (value) {
                                                case 'remove_member':
                                                  await _removeMemberFromGroup(
                                                      member['id']);
                                                  break;
                                                case 'view_profile':
                                                  // TODO: Implement view profile
                                                  break;
                                              }
                                            },
                                            itemBuilder: (context) => [
                                              const PopupMenuItem(
                                                value: 'view_profile',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.person),
                                                    SizedBox(width: 8),
                                                    Text('View Profile'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'remove_member',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.remove_circle,
                                                        color: Colors.red),
                                                    SizedBox(width: 8),
                                                    Text('Remove from Group',
                                                        style: TextStyle(
                                                            color: Colors.red)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          )
                                        : null,
                                  );
                                },
                              ),
                            ),
                          if (_conversation?['is_group'] == true && !isStudent)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _showEditMembersDialog();
                                      },
                                      icon: const Icon(Icons.person_add),
                                      label: const Text('Add Members'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF2196F3),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
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
                          reverse: true,
                          itemBuilder: (context, index) {
                            return _buildMessageBubble(
                                _messages[_messages.length - 1 - index]);
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
    final sentAt = message['sent_at']?.toString();
    String formattedTime = '';
    if (sentAt != null) {
      final date = DateTime.tryParse(sentAt);
      if (date != null) {
        formattedTime =
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }
    }

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: const Color(0xFF2196F3),
                    child: sender?['avatar_url'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              sender!['avatar_url'],
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.person,
                                    color: Colors.white, size: 16);
                              },
                            ),
                          )
                        : const Icon(Icons.person,
                            color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    senderName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formattedTime,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                ],
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
            if (isCurrentUser)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  formattedTime,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
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

  Future<void> _showDeleteGroupDialog() async {
    // Check if current user is a student
    final isStudent =
        _currentUser?.role.toString().toLowerCase().contains('student') ==
                true ||
            _currentUser?.role == 'student';

    if (isStudent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Students cannot delete groups'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
          'Are you sure you want to delete this group? This action cannot be undone and all messages will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteGroup();
    }
  }

  Future<void> _deleteGroup() async {
    // Check if current user is a student
    final isStudent =
        _currentUser?.role.toString().toLowerCase().contains('student') ==
                true ||
            _currentUser?.role == 'student';

    if (isStudent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Students cannot delete groups'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Delete all messages in the conversation
      await supabase.Supabase.instance.client
          .from('messages')
          .delete()
          .eq('conversation_id', widget.conversationId);

      // Delete all conversation members
      await supabase.Supabase.instance.client
          .from('conversation_members')
          .delete()
          .eq('conversation_id', widget.conversationId);

      // Delete the conversation itself
      await supabase.Supabase.instance.client
          .from('conversations')
          .delete()
          .eq('id', widget.conversationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditMembersDialog() async {
    // Check if current user is a student
    final isStudent =
        _currentUser?.role.toString().toLowerCase().contains('student') ==
                true ||
            _currentUser?.role == 'student';

    if (isStudent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Students cannot edit group members'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => _EditMembersDialog(
        conversationId: widget.conversationId,
        currentMembers: _groupMembers,
        currentUserId: _currentUserId ?? '',
        isStudent: isStudent,
      ),
    );
    // Refresh the members list
    await _loadConversation();
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text(
          'Are you sure you want to leave this group? You will no longer receive messages from this group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true && _currentUserId != null) {
      try {
        // Remove the current user from conversation members
        await supabase.Supabase.instance.client
            .from('conversation_members')
            .delete()
            .eq('conversation_id', widget.conversationId)
            .eq('user_id', _currentUserId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have left the group'),
              backgroundColor: Colors.orange,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error leaving group: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _removeMemberFromGroup(String userId) async {
    // Check if current user is a student
    final isStudent =
        _currentUser?.role.toString().toLowerCase().contains('student') ==
                true ||
            _currentUser?.role == 'student';

    if (isStudent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Students cannot remove members from groups'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await supabase.Supabase.instance.client
          .from('conversation_members')
          .delete()
          .eq('conversation_id', widget.conversationId)
          .eq('user_id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member removed from group'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showClearChatDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
            'Are you sure you want to clear all messages in this chat? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _clearChat();
    }
  }

  Future<void> _clearChat() async {
    try {
      await supabase.Supabase.instance.client
          .from('messages')
          .delete()
          .eq('conversation_id', widget.conversationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat cleared successfully'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadConversation();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteSingleChatDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text(
          'Are you sure you want to delete this chat? This action cannot be undone and all messages will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteSingleChat();
    }
  }

  Future<void> _deleteSingleChat() async {
    try {
      // Delete all messages in the conversation
      await supabase.Supabase.instance.client
          .from('messages')
          .delete()
          .eq('conversation_id', widget.conversationId);

      // Delete all conversation members
      await supabase.Supabase.instance.client
          .from('conversation_members')
          .delete()
          .eq('conversation_id', widget.conversationId);

      // Delete the conversation itself
      await supabase.Supabase.instance.client
          .from('conversations')
          .delete()
          .eq('id', widget.conversationId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chat deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _EditMembersDialog extends StatefulWidget {
  final String conversationId;
  final List<Map<String, dynamic>> currentMembers;
  final String currentUserId;
  final bool isStudent;

  const _EditMembersDialog({
    required this.conversationId,
    required this.currentMembers,
    required this.currentUserId,
    required this.isStudent,
  });

  @override
  State<_EditMembersDialog> createState() => _EditMembersDialogState();
}

class _EditMembersDialogState extends State<_EditMembersDialog> {
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _currentMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentMembers = List.from(widget.currentMembers);
    _loadAllUsers();
  }

  Future<void> _loadAllUsers() async {
    try {
      // Fetch all users from Supabase, no auth logic, no filtering
      final users = await supabase.Supabase.instance.client
          .from('users')
          .select('id, full_name, email')
          .order('full_name');

      setState(() {
        _allUsers = List<Map<String, dynamic>>.from(users);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addMember(String userId) async {
    if (widget.isStudent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Students cannot add members to groups'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await supabase.Supabase.instance.client
          .from('conversation_members')
          .insert({
        'conversation_id': widget.conversationId,
        'user_id': userId,
      });

      // Add to local list
      final user = _allUsers.firstWhere((u) => u['id'] == userId);
      setState(() {
        _currentMembers.add(user);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user['full_name']} added to group'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeMember(String userId) async {
    if (widget.isStudent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Students cannot remove members from groups'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await supabase.Supabase.instance.client
          .from('conversation_members')
          .delete()
          .eq('conversation_id', widget.conversationId)
          .eq('user_id', userId);

      // Remove from local list
      setState(() {
        _currentMembers.removeWhere((member) => member['id'] == userId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member removed from group'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Group Members'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Current members section
                  const Text(
                    'Current Members',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _currentMembers.length,
                      itemBuilder: (context, index) {
                        final member = _currentMembers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              member['full_name']
                                      ?.substring(0, 1)
                                      .toUpperCase() ??
                                  'U',
                            ),
                          ),
                          title: Text(member['full_name'] ?? 'Unknown'),
                          subtitle: Text(member['email'] ?? ''),
                          trailing: !widget.isStudent
                              ? IconButton(
                                  icon: const Icon(Icons.remove_circle,
                                      color: Colors.red),
                                  onPressed: () => _removeMember(member['id']),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  // Add members section
                  const Text(
                    'Add Members',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _allUsers.length,
                      itemBuilder: (context, index) {
                        final user = _allUsers[index];
                        final isAlreadyMember = _currentMembers
                            .any((member) => member['id'] == user['id']);

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              user['full_name']
                                      ?.substring(0, 1)
                                      .toUpperCase() ??
                                  'U',
                            ),
                          ),
                          title: Text(user['full_name'] ?? 'Unknown'),
                          subtitle: Text(user['email'] ?? ''),
                          trailing: isAlreadyMember
                              ? const Icon(Icons.check, color: Colors.green)
                              : !widget.isStudent
                                  ? IconButton(
                                      icon: const Icon(Icons.add_circle,
                                          color: Colors.blue),
                                      onPressed: () => _addMember(user['id']),
                                    )
                                  : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
