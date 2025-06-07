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
            conversation_members(
              user_id,
              users(
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

      // Debug: Print conversation data
      print('Loaded ${_conversations.length} conversations');
      for (var conv in _conversations) {
        print('Conversation: ${conv['id']}');
        print('  Is Group: ${conv['is_group']}');
        print('  Title: ${conv['title']}');
        print('  Members: ${conv['conversation_members']}');
      }
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

        // Add all selected members to the conversation (current user is already included)
        for (final memberId in selectedMembers) {
          await supabase.Supabase.instance.client
              .from('conversation_members')
              .insert({
            'conversation_id': conversationId,
            'user_id': memberId,
          });
        }

        if (mounted) {
          context.push('/teacher/chat/$conversationId');
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
          context.push('/teacher/chat/$conversationId');
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

  Future<void> _deleteConversation(String conversationId) async {
    try {
      // Delete all messages in the conversation
      await supabase.Supabase.instance.client
          .from('messages')
          .delete()
          .eq('conversation_id', conversationId);

      // Delete all conversation members
      await supabase.Supabase.instance.client
          .from('conversation_members')
          .delete()
          .eq('conversation_id', conversationId);

      // Delete the conversation itself
      await supabase.Supabase.instance.client
          .from('conversations')
          .delete()
          .eq('id', conversationId);

      // Remove from local list
      setState(() {
        _conversations.removeWhere((conv) => conv['id'] == conversationId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conversation deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting conversation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 768;

    // Check if this is being used in TeacherChatPage (has gradient background)
    final isInTeacherChat =
        context.findAncestorWidgetOfExactType<Scaffold>()?.body is Container;

    return Scaffold(
      appBar: isInTeacherChat ? null : const CustomAppBar(title: 'Messages'),
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
        child: _isLoading
            ? _buildLoadingState(isTablet)
            : _error != null
                ? _buildErrorState(isTablet)
                : _conversations.isEmpty
                    ? _buildEmptyState(isTablet)
                    : _buildConversationsList(isTablet),
      ),
      floatingActionButton: _buildModernFloatingActionButton(isTablet),
    );
  }

  Widget _buildLoadingState(bool isTablet) {
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
            'Loading conversations...',
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

  Widget _buildErrorState(bool isTablet) {
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
              'Failed to load conversations',
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
              onPressed: _loadConversations,
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

  Widget _buildEmptyState(bool isTablet) {
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
              'No conversations yet',
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTablet ? 12 : 8),
            Text(
              'Start a conversation to begin chatting',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTablet ? 20 : 16),
            ElevatedButton.icon(
              onPressed: () => _showCreateChatDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Start New Chat'),
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

  Widget _buildConversationsList(bool isTablet) {
    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        final participants = List<Map<String, dynamic>>.from(
            conversation['conversation_members'] ?? []);
        final isGroup = conversation['is_group'] ?? false;

        // Get the title based on conversation type
        String title;
        if (isGroup) {
          title = conversation['title'] ?? 'Unnamed Group';
        } else {
          // Get the other participant (not the current user)
          final otherParticipant = participants.firstWhere(
            (p) => p['user_id'] != _userId,
            orElse: () => {
              'user_id': 'unknown',
              'users': {'full_name': 'Unknown User'}
            },
          );

          // Try to get name from participant first, then fallback to conversation title
          String participantName =
              otherParticipant['users']['full_name'] ?? 'Unknown User';
          String conversationTitle = conversation['title'] ?? '';

          if (participantName == 'Unknown User' &&
              conversationTitle.isNotEmpty) {
            // Extract name from "Chat with [Name]" format
            if (conversationTitle.startsWith('Chat with ')) {
              title = conversationTitle.substring(10); // Remove "Chat with "
            } else {
              title = conversationTitle;
            }
          } else {
            title = participantName;
          }
        }

        // Get the last message safely
        final messages =
            List<Map<String, dynamic>>.from(conversation['messages'] ?? []);
        final lastMessage = messages.isNotEmpty ? messages.last : null;
        final isUnread = lastMessage != null && lastMessage['is_read'] == false;

        // Format the subtitle
        String subtitle;
        if (lastMessage != null) {
          final senderName = lastMessage['sender']?['full_name'] ?? 'Unknown';
          final content = lastMessage['content'] ?? '';
          subtitle = '$senderName: $content';
        } else {
          subtitle = 'No messages yet';
        }

        return _buildModernConversationCard(
          conversation,
          title,
          subtitle,
          isGroup,
          participants,
          isUnread,
          isTablet,
        );
      },
    );
  }

  Widget _buildModernConversationCard(
    Map<String, dynamic> conversation,
    String title,
    String subtitle,
    bool isGroup,
    List<Map<String, dynamic>> participants,
    bool isUnread,
    bool isTablet,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isUnread
              ? [
                  AppTheme.primaryBlue.withOpacity(0.1),
                  Colors.white,
                ]
              : [
                  Colors.white,
                  Colors.grey[50]!,
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnread
              ? AppTheme.primaryBlue.withOpacity(0.3)
              : Colors.grey.withOpacity(0.1),
          width: isUnread ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isUnread
                ? AppTheme.primaryBlue.withOpacity(0.1)
                : Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            context.push('/teacher/chat/${conversation['id']}');
          },
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: isTablet ? 60 : 50,
                  height: isTablet ? 60 : 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isGroup
                          ? [
                              AppTheme.successGreen,
                              AppTheme.successGreen.withOpacity(0.8),
                            ]
                          : [
                              AppTheme.primaryBlue,
                              AppTheme.primaryBlue.withOpacity(0.8),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (isGroup
                                ? AppTheme.successGreen
                                : AppTheme.primaryBlue)
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: isGroup
                      ? Icon(
                          Icons.group,
                          color: Colors.white,
                          size: isTablet ? 28 : 24,
                        )
                      : participants.firstWhere(
                                (p) => p['user_id'] != _userId,
                                orElse: () => {
                                  'user_id': 'unknown',
                                  'users': {'avatar_url': null}
                                },
                              )['users']['avatar_url'] !=
                              null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                participants.firstWhere(
                                  (p) => p['user_id'] != _userId,
                                  orElse: () => {
                                    'user_id': 'unknown',
                                    'users': {'avatar_url': null}
                                  },
                                )['users']['avatar_url'],
                                width: isTablet ? 60 : 50,
                                height: isTablet ? 60 : 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: isTablet ? 28 : 24,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.person,
                              color: Colors.white,
                              size: isTablet ? 28 : 24,
                            ),
                ),
                SizedBox(width: isTablet ? 16 : 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: isTablet ? 18 : 16,
                                fontWeight: isUnread
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                color: isUnread
                                    ? AppTheme.primaryBlue
                                    : Colors.grey[800],
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'New',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isTablet ? 12 : 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: isTablet ? 8 : 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          color: isUnread
                              ? AppTheme.primaryBlue
                              : Colors.grey[600],
                          fontWeight:
                              isUnread ? FontWeight.w500 : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  Icons.arrow_forward_ios,
                  color: AppTheme.primaryBlue.withOpacity(0.6),
                  size: isTablet ? 20 : 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernFloatingActionButton(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: 'chat_list_fab',
        onPressed: () => _showCreateChatDialog(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Icon(
          Icons.add,
          color: Colors.white,
          size: isTablet ? 32 : 28,
        ),
      ),
    );
  }

  void _showCreateChatDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400,
              maxHeight: 500,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline,
                          color: AppTheme.primaryBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Create New Chat',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlueDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildCreateChatOption(
                    icon: Icons.group_add,
                    title: 'Create Group Chat',
                    subtitle: 'Start a conversation with multiple people',
                    onTap: () {
                      Navigator.pop(context);
                      _createNewConversation(isGroup: true);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildCreateChatOption(
                    icon: Icons.person_add,
                    title: 'New Individual Chat',
                    subtitle: 'Start a one-on-one conversation',
                    onTap: () {
                      Navigator.pop(context);
                      _createNewConversation(isGroup: false);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateChatOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primaryBlue.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: AppTheme.primaryBlue.withOpacity(0.6),
                size: 16,
              ),
            ],
          ),
        ),
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
      // Fetch all users from Supabase, no auth logic, no filtering
      final users = await supabase.Supabase.instance.client
          .from('users')
          .select('id, full_name, email, role, avatar_url')
          .order('full_name');

      setState(() {
        _users = List<Map<String, dynamic>>.from(users);
        _isLoading = false;
        // Auto-select the current user (instructor) who is creating the group
        _selectedUserIds.add(widget.currentUserId);
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 768;
    final isLandscape = screenWidth > screenHeight;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 500 : 400,
          maxHeight: isTablet
              ? (isLandscape ? screenHeight * 0.8 : screenHeight * 0.7)
              : screenHeight * 0.8,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32 : 24,
            vertical: isTablet ? 32 : 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 16 : 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.group_add,
                      color: AppTheme.primaryBlue,
                      size: isTablet ? 28 : 24,
                    ),
                  ),
                  SizedBox(width: isTablet ? 20 : 16),
                  Expanded(
                    child: Text(
                      'Create Group Chat',
                      style: TextStyle(
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 24 : 20),

              // Group Name Input
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelStyle: TextStyle(
                    color: Colors.black54,
                    fontSize: isTablet ? 16 : 14,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isTablet ? 16 : 12,
                  ),
                ),
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                ),
              ),
              SizedBox(height: isTablet ? 24 : 20),

              // Members Section
              Row(
                children: [
                  Icon(
                    Icons.people,
                    color: AppTheme.primaryBlue,
                    size: isTablet ? 20 : 18,
                  ),
                  SizedBox(width: isTablet ? 12 : 8),
                  Text(
                    'Select Members',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_selectedUserIds.length} selected',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 16 : 12),

              // Users List
              if (_isLoading)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        SizedBox(height: isTablet ? 16 : 12),
                        Text(
                          'Loading users...',
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final isCurrentUser = user['id'] == widget.currentUserId;
                      final isSelected = _selectedUserIds.contains(user['id']);

                      return Container(
                        margin: EdgeInsets.only(bottom: isTablet ? 12 : 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryBlue.withOpacity(0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primaryBlue.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: Colors.transparent,
                          activeColor: AppTheme.primaryBlue,
                          checkColor: Colors.white,
                          value: isSelected,
                          onChanged: isCurrentUser
                              ? null
                              : (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedUserIds.add(user['id']);
                                    } else {
                                      _selectedUserIds.remove(user['id']);
                                    }
                                  });
                                },
                          title: Row(
                            children: [
                              Text(
                                user['full_name'],
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                  fontSize: isTablet ? 16 : 14,
                                ),
                              ),
                              if (isCurrentUser) ...[
                                SizedBox(width: isTablet ? 8 : 6),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 8 : 6,
                                    vertical: isTablet ? 4 : 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.primaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          AppTheme.primaryBlue.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'You',
                                    style: TextStyle(
                                      fontSize: isTablet ? 12 : 10,
                                      color: AppTheme.primaryBlue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            user['email'],
                            style: TextStyle(
                              fontSize: isTablet ? 13 : 12,
                              color: Colors.black54,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 20 : 16,
                            vertical: isTablet ? 8 : 4,
                          ),
                        ),
                      );
                    },
                  ),
                ),

              SizedBox(height: isTablet ? 24 : 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 20,
                        vertical: isTablet ? 12 : 10,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: isTablet ? 16 : 14,
                      ),
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  ElevatedButton(
                    onPressed:
                        _selectedUserIds.isEmpty || _nameController.text.isEmpty
                            ? null
                            : () {
                                Navigator.pop(context, {
                                  'name': _nameController.text,
                                  'members': _selectedUserIds,
                                });
                              },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: Size(
                        isTablet ? 120 : 100,
                        isTablet ? 48 : 44,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : 20,
                        vertical: isTablet ? 12 : 10,
                      ),
                    ),
                    child: Text(
                      'Create',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
      // Fetch all users from Supabase, no auth logic, no filtering
      final users = await supabase.Supabase.instance.client
          .from('users')
          .select('id, full_name, email, role, avatar_url')
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
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 600,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select User',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  height: 300,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor:
                                AppTheme.primaryBlue.withOpacity(0.1),
                            child: user['avatar_url'] != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(25),
                                    child: Image.network(
                                      user['avatar_url'],
                                      width: 40,
                                      height: 40,
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
                            user['full_name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            user['email'],
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context, {
                              'user_id': user['id'],
                              'user_name': user['full_name'],
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
