import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _conversations = [];
  String? _error;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson == null) {
        throw Exception('User not authenticated');
      }

      final userData = jsonDecode(userJson) as Map<String, dynamic>;
      _userId = userData['id'] as String;

      if (_userId == null) {
        throw Exception('User ID not found');
      }

      final response = await supabase.Supabase.instance.client
          .from('conversations')
          .select('''
            *,
            messages:messages(
              id,
              content,
              sent_at,
              is_read,
              sender:users(
                id,
                full_name,
                avatar_url
              )
            ),
            members:conversation_members(
              user:users(
                id,
                full_name,
                avatar_url
              )
            )
          ''')
          .eq('conversation_members.user_id', _userId!)
          .order('created_at', ascending: false);

      setState(() {
        _conversations = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewConversation({bool isGroup = false}) async {
    try {
      if (_userId == null) {
        throw Exception('User not authenticated');
      }

      if (isGroup) {
        // Show dialog to select group members and set group name
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => _GroupChatDialog(currentUserId: _userId!),
        );

        if (result == null) return; // User cancelled

        final conversationId = const Uuid().v4();
        final selectedMembers = result['members'] as List<String>;
        final groupName = result['name'] as String;

        // Create the conversation
        await supabase.Supabase.instance.client.from('conversations').insert({
          'id': conversationId,
          'title': groupName,
          'is_group': true,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Add all members to the conversation, including the current user
        final allMembers = [...selectedMembers, _userId!];
        for (final memberId in allMembers) {
          await supabase.Supabase.instance.client
              .from('conversation_members')
              .insert({
            'conversation_id': conversationId,
            'user_id': memberId,
          });
        }

        if (mounted) {
          context.push('/chat/$conversationId');
          await _loadConversations();
        }
      } else {
        // Show dialog to select user for individual chat
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => _IndividualChatDialog(currentUserId: _userId!),
        );

        if (result == null) return; // User cancelled

        final selectedUserId = result['user_id'] as String;
        final selectedUserName = result['user_name'] as String;

        final conversationId = const Uuid().v4();

        await supabase.Supabase.instance.client.from('conversations').insert({
          'id': conversationId,
          'title': 'Chat with $selectedUserName',
          'is_group': false,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Add both users to the conversation
        await supabase.Supabase.instance.client
            .from('conversation_members')
            .insert([
          {
            'conversation_id': conversationId,
            'user_id': _userId!,
          },
          {
            'conversation_id': conversationId,
            'user_id': selectedUserId,
          },
        ]);

        if (mounted) {
          context.push('/chat/$conversationId');
          await _loadConversations();
        }
      }
    } catch (e) {
      print('Error creating conversation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create conversation: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Messages'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _conversations.isEmpty
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
                            'No conversations yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = _conversations[index];
                        final participants = List<Map<String, dynamic>>.from(
                            conversation['members'] ?? []);
                        final isGroup = conversation['is_group'] ?? false;

                        // Get the title based on conversation type
                        String title;
                        if (isGroup) {
                          title = conversation['title'] ?? 'Unnamed Group';
                        } else {
                          // Get the other participant (not the current user)
                          final otherParticipant = participants.firstWhere(
                            (p) => p['user']['id'] != _userId,
                            orElse: () => {
                              'user': {'full_name': 'Unknown User'}
                            },
                          );
                          title = otherParticipant['user']['full_name'] ??
                              'Unknown User';
                        }

                        // Get the last message safely
                        final messages = List<Map<String, dynamic>>.from(
                            conversation['messages'] ?? []);
                        final lastMessage =
                            messages.isNotEmpty ? messages.last : null;
                        final isUnread = lastMessage != null &&
                            lastMessage['is_read'] == false;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppTheme.primaryBlue.withOpacity(0.1),
                              child: isGroup
                                  ? const Icon(Icons.group,
                                      color: AppTheme.primaryBlue)
                                  : participants.firstWhere(
                                            (p) => p['user']['id'] != _userId,
                                            orElse: () => {
                                              'user': {'avatar_url': null}
                                            },
                                          )['user']['avatar_url'] !=
                                          null
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(25),
                                          child: Image.network(
                                            participants.firstWhere(
                                              (p) => p['user']['id'] != _userId,
                                              orElse: () => {
                                                'user': {'avatar_url': null}
                                              },
                                            )['user']['avatar_url'],
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.person,
                                                color: AppTheme.primaryBlue,
                                              );
                                            },
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          color: AppTheme.primaryBlue,
                                        ),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              lastMessage != null
                                  ? '${lastMessage['sender']['full_name']}: ${lastMessage['content']}'
                                  : 'No messages yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: isUnread
                                ? Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlue,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'New',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : null,
                            onTap: () {
                              context.push('/chat/${conversation['id']}');
                            },
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return SimpleDialog(
                title: const Text('Create New Chat'),
                children: [
                  SimpleDialogOption(
                    onPressed: () {
                      Navigator.pop(context);
                      _createNewConversation(isGroup: true);
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.group_add),
                        SizedBox(width: 8),
                        Text('Create Group Chat'),
                      ],
                    ),
                  ),
                  SimpleDialogOption(
                    onPressed: () {
                      Navigator.pop(context);
                      _createNewConversation(isGroup: false);
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.person_add),
                        SizedBox(width: 8),
                        Text('New Individual Chat'),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GroupChatDialog extends StatefulWidget {
  final String currentUserId;

  const _GroupChatDialog({required this.currentUserId});

  @override
  State<_GroupChatDialog> createState() => _GroupChatDialogState();
}

class _GroupChatDialogState extends State<_GroupChatDialog> {
  final _nameController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  final List<String> _selectedUserIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await supabase.Supabase.instance.client
          .from('users')
          .select()
          .neq('id', widget.currentUserId)
          .order('full_name');

      setState(() {
        _users = List<Map<String, dynamic>>.from(users);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Group Chat'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'Enter group name',
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final isSelected = _selectedUserIds.contains(user['id']);

                    return CheckboxListTile(
                      title: Text(user['full_name']),
                      subtitle: Text(user['email']),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedUserIds.add(user['id']);
                          } else {
                            _selectedUserIds.remove(user['id']);
                          }
                        });
                      },
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
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedUserIds.isEmpty || _nameController.text.isEmpty
              ? null
              : () {
                  Navigator.pop(context, {
                    'name': _nameController.text,
                    'members': _selectedUserIds,
                  });
                },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _IndividualChatDialog extends StatefulWidget {
  final String currentUserId;

  const _IndividualChatDialog({required this.currentUserId});

  @override
  State<_IndividualChatDialog> createState() => _IndividualChatDialogState();
}

class _IndividualChatDialogState extends State<_IndividualChatDialog> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await supabase.Supabase.instance.client
          .from('users')
          .select()
          .neq('id', widget.currentUserId)
          .order('full_name');

      setState(() {
        _users = List<Map<String, dynamic>>.from(users);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select User'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                      child: user['avatar_url'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(25),
                              child: Image.network(
                                user['avatar_url'],
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.person,
                                    color: AppTheme.primaryBlue,
                                  );
                                },
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              color: AppTheme.primaryBlue,
                            ),
                    ),
                    title: Text(user['full_name']),
                    subtitle: Text(user['email']),
                    onTap: () {
                      Navigator.pop(context, {
                        'user_id': user['id'],
                        'user_name': user['full_name'],
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
