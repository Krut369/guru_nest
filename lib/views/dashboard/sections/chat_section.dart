import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';

class _GroupChatDialog extends StatefulWidget {
  final User currentUser;

  const _GroupChatDialog({required this.currentUser});

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

  Future<void> _loadUsers() async {
    try {
      final users = await supabase.Supabase.instance.client
          .from('users')
          .select()
          .neq('id', widget.currentUser.id)
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

class ChatSection extends StatefulWidget {
  const ChatSection({super.key});

  @override
  State<ChatSection> createState() => _ChatSectionState();
}

class _ChatSectionState extends State<ChatSection> {
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String? _error;
  User? _currentUser;
  String? _teacherId;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');

      print(
          'Retrieved user data from SharedPreferences: $userJson'); // Debug log

      if (userJson == null) {
        print('No user data found in SharedPreferences'); // Debug log
        setState(() {
          _isLoading = false;
          _error = 'Please log in to access chat';
        });
        return;
      }

      try {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        print('Decoded user data: $userData'); // Debug log

        _currentUser = User.fromJson(userData);
        print('Created User object: ${_currentUser?.toJson()}'); // Debug log

        if (_currentUser == null || _currentUser!.id.isEmpty) {
          throw Exception('Invalid user data');
        }

        // Check if user exists in users table
        final existingUser = await supabase.Supabase.instance.client
            .from('users')
            .select()
            .eq('id', _currentUser!.id)
            .maybeSingle();

        print('Existing user check result: $existingUser'); // Debug log

        if (existingUser == null) {
          // Create user in users table if not exists
          final insertResult = await supabase.Supabase.instance.client
              .from('users')
              .insert({
                'id': _currentUser!.id,
                'full_name': _currentUser!.fullName,
                'email': _currentUser!.email,
                'role': _currentUser!.role,
                'avatar_url': _currentUser!.avatarUrl,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

          print('Created new user in database: $insertResult'); // Debug log
        }

        await _fetchConversations(_currentUser!);

        setState(() {
          _isLoading = false;
        });
      } catch (e) {
        print('Error processing user data: $e'); // Debug log
        throw Exception('Invalid user data format: $e');
      }
    } catch (e) {
      print('Error initializing chat: $e');
      setState(() {
        _isLoading = false;
        _error = 'Failed to initialize chat: ${e.toString()}';
      });
    }
  }

  Future<void> _fetchConversations(User user) async {
    try {
      final conversations = await supabase.Supabase.instance.client
          .from('conversations')
          .select('''
            *,
            conversation_members!inner (user_id, users!inner(id, full_name, avatar_url, role))
          ''').order('created_at', ascending: false);

      for (var conversation in conversations) {
        final members = List<Map<String, dynamic>>.from(
            conversation['conversation_members'] ?? []);

        if (conversation['is_group'] == true) {
          conversation['title'] = conversation['title'] ?? 'Group Chat';
          conversation['members'] = members.map((m) => m['users']).toList();
        } else {
          final otherUser = members.firstWhere(
            (member) => member['users']['id'] != user.id,
            orElse: () => {
              'users': {
                'full_name': 'Unknown User',
                'avatar_url': null,
                'role': 'user'
              }
            },
          );
          conversation['other_user'] = otherUser['users'];
        }

        // Fetch last message
        final lastMessage = await supabase.Supabase.instance.client
            .from('messages')
            .select('''
              *,
              sender:users!sender_id(id, full_name)
            ''')
            .eq('conversation_id', conversation['id'])
            .order('sent_at', ascending: false)
            .limit(1)
            .maybeSingle();

        conversation['last_message'] = lastMessage;
      }

      if (mounted) {
        setState(() {
          _conversations = List.from(conversations);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load conversations: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createNewConversation({bool isGroup = false}) async {
    try {
      print('Creating new conversation. isGroup: $isGroup'); // Debug log

      if (_currentUser == null) {
        print('Current user is null'); // Debug log
        throw Exception('User not authenticated');
      }

      if (isGroup) {
        print('Opening group chat dialog'); // Debug log
        // Show dialog to select group members and set group name
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => _GroupChatDialog(currentUser: _currentUser!),
        );

        if (result == null) {
          print('User cancelled group chat creation'); // Debug log
          return;
        }

        final conversationId = _uuid.v4();
        final selectedMembers = result['members'] as List<String>;
        final groupName = result['name'] as String;

        print('Creating group chat with ID: $conversationId'); // Debug log
        print('Selected members: $selectedMembers'); // Debug log

        // Create the conversation
        await supabase.Supabase.instance.client.from('conversations').insert({
          'id': conversationId,
          'title': groupName,
          'is_group': true,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Add all members to the conversation, including the current user
        final allMembers = [...selectedMembers, _currentUser!.id];
        print('Adding members to conversation: $allMembers'); // Debug log

        for (final memberId in allMembers) {
          await supabase.Supabase.instance.client
              .from('conversation_members')
              .insert({
            'conversation_id': conversationId,
            'user_id': memberId,
          });
        }

        if (mounted) {
          print('Navigating to chat page'); // Debug log
          context.push('/chat/$conversationId');
          await _fetchConversations(_currentUser!);
        }
      } else {
        print('Creating individual chat'); // Debug log
        // Individual chat logic remains the same
        final conversationId = _uuid.v4();

        await supabase.Supabase.instance.client.from('conversations').insert({
          'id': conversationId,
          'title': 'Chat with Teacher',
          'is_group': false,
          'created_at': DateTime.now().toIso8601String(),
        });

        await supabase.Supabase.instance.client
            .from('conversation_members')
            .insert({
          'conversation_id': conversationId,
          'user_id': _currentUser!.id,
        });

        if (!isGroup && _teacherId != null) {
          await supabase.Supabase.instance.client
              .from('conversation_members')
              .insert({
            'conversation_id': conversationId,
            'user_id': _teacherId,
          });
        }

        if (mounted) {
          print('Navigating to chat page'); // Debug log
          context.push('/chat/$conversationId');
          await _fetchConversations(_currentUser!);
        }
      }
    } catch (e) {
      print('Error creating conversation: $e'); // Debug log
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
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.defaultPadding),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.errorRed),
                textAlign: TextAlign.center,
              ),
              if (_error == 'Please log in to access chat') ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Go to Login'),
                ),
              ]
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Messages',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  print('New chat button pressed'); // Debug log
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
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('New Chat'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_conversations.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _createNewConversation(),
                    icon: const Icon(Icons.add),
                    label: const Text('Start a New Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  final conversation = _conversations[index];
                  final lastMessage = conversation['last_message'];
                  final isGroup = conversation['is_group'] ?? false;

                  // Get the title based on conversation type
                  String title;
                  if (isGroup) {
                    title = conversation['title'] ?? 'Unnamed Group';
                  } else {
                    final otherUser = conversation['other_user'] ??
                        {
                          'full_name': 'Unknown User',
                          'avatar_url': null,
                          'role': 'user'
                        };
                    title = otherUser['full_name'] ?? 'Unknown User';
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                        child: Icon(
                          isGroup ? Icons.group : Icons.person,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: lastMessage != null
                          ? Text(
                              '${lastMessage['sender']['full_name']}: ${lastMessage['content']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : const Text('No messages yet'),
                      onTap: () => context.push('/chat/${conversation['id']}'),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
