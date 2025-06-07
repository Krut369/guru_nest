import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/user_model.dart';

class ChatSection extends StatefulWidget {
  const ChatSection({super.key});

  @override
  State<ChatSection> createState() => _ChatSectionState();
}

class _ChatSectionState extends State<ChatSection> {
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _filteredConversations = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;
  User? _currentUser;
  String? _teacherId;
  final _uuid = const Uuid();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _searchController.addListener(_filterConversations);
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

        // Debug: Check database structure
        await _debugDatabaseStructure();

        await _fetchConversations(_currentUser!);

        setState(() {
          _isLoading = false;
        });
      } catch (e) {
        print('Error processing user data: $e'); // Debug log
        setState(() {
          _isLoading = false;
          _error = 'Failed to load user data: ${e.toString()}';
        });
      }
    } catch (e) {
      print('Error initializing chat: $e');
      setState(() {
        _isLoading = false;
        _error = 'Failed to initialize chat: ${e.toString()}';
      });
    }
  }

  Future<void> _debugDatabaseStructure() async {
    try {
      print('=== DEBUG: Checking database structure ===');

      // Check all users
      final users = await supabase.Supabase.instance.client
          .from('users')
          .select('id, full_name, role')
          .limit(5);
      print('Sample users: $users');

      // Check all conversations
      final conversations = await supabase.Supabase.instance.client
          .from('conversations')
          .select('id, title, is_group')
          .limit(5);
      print('Sample conversations: $conversations');

      // Check conversation members
      final members = await supabase.Supabase.instance.client
          .from('conversation_members')
          .select('conversation_id, user_id')
          .limit(10);
      print('Sample conversation members: $members');

      // If no conversations exist, create a test one
      if (conversations.isEmpty && users.isNotEmpty) {
        print('No conversations found, creating test conversation...');
        await _createTestConversation(users.first);
      }

      print('=== END DEBUG ===');
    } catch (e) {
      print('Debug error: $e');
    }
  }

  Future<void> _createTestConversation(Map<String, dynamic> otherUser) async {
    try {
      final conversationId = _uuid.v4();

      // Create conversation
      await supabase.Supabase.instance.client.from('conversations').insert({
        'id': conversationId,
        'title': 'Test Chat with ${otherUser['full_name']}',
        'is_group': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Add members
      await supabase.Supabase.instance.client
          .from('conversation_members')
          .insert([
        {
          'conversation_id': conversationId,
          'user_id': _currentUser!.id,
        },
        {
          'conversation_id': conversationId,
          'user_id': otherUser['id'],
        },
      ]);

      print('Created test conversation: $conversationId');
    } catch (e) {
      print('Error creating test conversation: $e');
    }
  }

  Future<void> _fetchConversations(User user) async {
    try {
      print('Fetching conversations for user: ${user.id}'); // Debug log

      // First, get all conversations where the current user is a member
      final conversations = await supabase.Supabase.instance.client
          .from('conversations')
          .select('*')
          .order('created_at', ascending: false);

      print('Found ${conversations.length} total conversations'); // Debug log

      // Filter conversations where current user is a member
      final userConversations = <Map<String, dynamic>>[];

      for (final conversation in conversations) {
        // Get members for this conversation
        final members = await supabase.Supabase.instance.client
            .from('conversation_members')
            .select('''
              user_id,
              users!inner(id, full_name, avatar_url, role)
            ''').eq('conversation_id', conversation['id']);

        print(
            'Conversation ${conversation['id']} members: $members'); // Debug log

        // Check if current user is a member of this conversation
        final isMember = members.any((member) => member['user_id'] == user.id);

        if (isMember) {
          final membersList = List<Map<String, dynamic>>.from(members);

          if (conversation['is_group'] == true) {
            conversation['title'] = conversation['title'] ?? 'Group Chat';
            conversation['members'] =
                membersList.map((m) => m['users']).toList();
          } else {
            // For individual chats, find the other user (not the current user)
            final otherUserMember = membersList.firstWhere(
              (member) => member['users']['id'] != user.id,
              orElse: () => {
                'users': {
                  'id': 'unknown',
                  'full_name': 'Unknown User',
                  'avatar_url': null,
                  'role': 'user'
                }
              },
            );

            print('Other user found: ${otherUserMember['users']}'); // Debug log
            conversation['other_user'] = otherUserMember['users'];

            // Set the title for individual chats
            conversation['title'] =
                otherUserMember['users']['full_name'] ?? 'Unknown User';
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
          userConversations.add(conversation);
        }
      }

      print(
          'User is member of ${userConversations.length} conversations'); // Debug log

      if (mounted) {
        setState(() {
          _conversations = userConversations;
          _filteredConversations = userConversations;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching conversations: $e'); // Debug log
      if (mounted) {
        setState(() {
          _error = 'Failed to load conversations: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _filterConversations() {
    final searchText = _searchController.text.toLowerCase();
    setState(() {
      _filteredConversations = _conversations.where((conversation) {
        final title = conversation['title']?.toLowerCase() ?? '';
        final otherUserName =
            conversation['other_user']?['full_name']?.toLowerCase() ?? '';
        final lastMessageContent =
            conversation['last_message']?['content']?.toLowerCase() ?? '';

        return title.contains(searchText) ||
            otherUserName.contains(searchText) ||
            lastMessageContent.contains(searchText);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildErrorState();
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: double.infinity),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _filteredConversations.isEmpty
                    ? _buildEmptyState()
                    : _buildConversationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isMobile = screenWidth <= 600;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 32 : 24,
        isTablet ? 20 : 16,
        isTablet ? 32 : 24,
        isTablet ? 12 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue,
                      AppTheme.primaryBlue.withOpacity(0.8)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                ),
                child: Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: isTablet ? 28 : 24,
                ),
              ),
              SizedBox(width: isTablet ? 20 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Messages',
                      style: TextStyle(
                        fontSize: isTablet ? 28 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      _isSearching
                          ? '${_filteredConversations.length} of ${_conversations.length} conversations'
                          : '${_conversations.length} conversations',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) {
                      _searchController.clear();
                      _filteredConversations = List.from(_conversations);
                    }
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(isTablet ? 12 : 8),
                  decoration: BoxDecoration(
                    color: _isSearching
                        ? AppTheme.primaryBlue.withOpacity(0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                  ),
                  child: Icon(
                    _isSearching ? Icons.close_rounded : Icons.search_rounded,
                    color: _isSearching
                        ? AppTheme.primaryBlue
                        : Colors.grey.shade600,
                    size: isTablet ? 24 : 20,
                  ),
                ),
              ),
            ],
          ),
          if (_isSearching) ...[
            SizedBox(height: isTablet ? 20 : 16),
            Container(
              constraints: BoxConstraints(
                maxHeight: isTablet ? 60 : 50,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: isTablet ? 18 : 16,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey.shade500,
                    size: isTablet ? 24 : 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isTablet ? 16 : 12,
                  ),
                ),
                style: TextStyle(fontSize: isTablet ? 18 : 16),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.red.shade50,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_error == 'Please log in to access chat') ...[
                _buildModernButton(
                  onPressed: () => context.go('/login'),
                  text: 'Go to Login',
                  icon: Icons.login_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ] else if (_error != null &&
                  _error!.contains('Invalid user data')) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.3),
                    ),
                  ),
                  child: const Text(
                    'Chat is disabled: User data is incomplete or invalid. Please ensure your profile is up to date.',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.withOpacity(0.1),
                  AppTheme.primaryBlue.withOpacity(0.05)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading conversations...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearchResult = _isSearching && _conversations.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade100, Colors.grey.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isSearchResult
                    ? Icons.search_off_rounded
                    : Icons.chat_bubble_outline_rounded,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSearchResult
                  ? 'No conversations found'
                  : 'No conversations yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isSearchResult
                  ? 'Try adjusting your search terms or browse all conversations'
                  : 'You will see conversations here when teachers or other students start chats with you',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (!isSearchResult)
              _buildModernButton(
                onPressed: _showAvailableTeachers,
                text: 'Start New Chat',
                icon: Icons.add_rounded,
                color: AppTheme.primaryBlue,
              )
            else
              _buildModernButton(
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _filteredConversations = List.from(_conversations);
                  });
                },
                text: 'Clear Search',
                icon: Icons.clear_rounded,
                color: Colors.grey.shade600,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 16,
        vertical: isTablet ? 12 : 8,
      ),
      itemCount: _filteredConversations.length,
      itemBuilder: (context, index) {
        final conversation = _filteredConversations[index];
        final lastMessage = conversation['last_message'];
        final isGroup = conversation['is_group'] ?? false;

        // Get the title based on conversation type
        String title;
        if (isGroup) {
          title = conversation['title'] ?? 'Unnamed Group';
        } else {
          // Try multiple sources for the title
          final otherUser = conversation['other_user'];
          final conversationTitle = conversation['title'];

          if (otherUser != null && otherUser['full_name'] != null) {
            title = otherUser['full_name'];
          } else if (conversationTitle != null &&
              conversationTitle.isNotEmpty) {
            // Extract name from "Chat with [Name]" format if it exists
            if (conversationTitle.startsWith('Chat with ')) {
              title = conversationTitle.substring(10); // Remove "Chat with "
            } else {
              title = conversationTitle;
            }
          } else {
            title = 'Unknown User';
          }

          print(
              'Conversation ${conversation['id']} title: $title'); // Debug log
          print('Other user data: $otherUser'); // Debug log
        }

        return Container(
          margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
          child: _buildConversationCard(
            conversation: conversation,
            title: title,
            lastMessage: lastMessage,
            isGroup: isGroup,
            isTablet: isTablet,
            otherUser: conversation['other_user'],
          ),
        );
      },
    );
  }

  Widget _buildConversationCard({
    required Map<String, dynamic> conversation,
    required String title,
    required dynamic lastMessage,
    required bool isGroup,
    required bool isTablet,
    required Map<String, dynamic>? otherUser,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: isTablet ? 16 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
          onTap: () => context.push('/chat/${conversation['id']}'),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Row(
              children: [
                _buildAvatar(
                    isGroup: isGroup, isTablet: isTablet, otherUser: otherUser),
                SizedBox(width: isTablet ? 20 : 16),
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
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (lastMessage != null) ...[
                            SizedBox(width: isTablet ? 12 : 8),
                            Flexible(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isTablet ? 10 : 8,
                                  vertical: isTablet ? 6 : 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withOpacity(0.1),
                                  borderRadius:
                                      BorderRadius.circular(isTablet ? 14 : 12),
                                ),
                                child: Text(
                                  _formatTime(lastMessage['sent_at']),
                                  style: TextStyle(
                                    fontSize: isTablet ? 13 : 12,
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: isTablet ? 6 : 4),
                      if (lastMessage != null)
                        Text(
                          '${lastMessage['sender']['full_name']}: ${lastMessage['content']}',
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            color: Colors.grey.shade600,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: isTablet ? 12 : 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: isTablet ? 24 : 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
      {required bool isGroup,
      bool isTablet = false,
      Map<String, dynamic>? otherUser}) {
    return Container(
      width: isTablet ? 60 : 50,
      height: isTablet ? 60 : 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isGroup
              ? [Colors.purple.shade400, Colors.purple.shade600]
              : [AppTheme.primaryBlue, AppTheme.primaryBlue.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        boxShadow: [
          BoxShadow(
            color: (isGroup ? Colors.purple : AppTheme.primaryBlue)
                .withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: otherUser != null && otherUser['avatar_url'] != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
              child: Image.network(
                otherUser['avatar_url'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildAvatarFallback(otherUser, isTablet),
              ),
            )
          : _buildAvatarFallback(otherUser, isTablet),
    );
  }

  Widget _buildAvatarFallback(Map<String, dynamic>? otherUser, bool isTablet) {
    return Center(
      child: Icon(
        otherUser != null ? Icons.person_rounded : Icons.group_rounded,
        color: Colors.white,
        size: isTablet ? 28 : 24,
      ),
    );
  }

  Widget _buildModernButton({
    required VoidCallback onPressed,
    required String text,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String? timeString) {
    if (timeString == null) return '';

    try {
      final time = DateTime.parse(timeString);
      final now = DateTime.now();
      final difference = now.difference(time);

      if (difference.inDays > 0) {
        return '${difference.inDays}d';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'now';
      }
    } catch (e) {
      return '';
    }
  }

  Future<void> _showAvailableTeachers() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Fetch all teachers
      final teachers = await supabase.Supabase.instance.client
          .from('users')
          .select('id, full_name, avatar_url, role, bio')
          .eq('role', 'teacher')
          .order('full_name');

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }

      // Show teacher selection dialog
      final selectedTeacher = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _TeacherSelectionDialog(
          teachers: List<Map<String, dynamic>>.from(teachers),
          currentUserId: _currentUser!.id,
        ),
      );

      if (selectedTeacher != null) {
        await _createConversationWithTeacher(selectedTeacher);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading teachers: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createConversationWithTeacher(
      Map<String, dynamic> teacher) async {
    try {
      // Check if conversation already exists between current user and teacher
      // Get all conversations where current user is a member
      final userConversations = await supabase.Supabase.instance.client
          .from('conversations')
          .select('''
            id,
            conversation_members!inner(user_id)
          ''')
          .eq('is_group', false)
          .eq('conversation_members.user_id', _currentUser!.id);

      // Check if any of these conversations also has the teacher as a member
      String? existingConversationId;
      for (final conversation in userConversations) {
        final members = List<Map<String, dynamic>>.from(
            conversation['conversation_members'] ?? []);
        final memberIds = members.map((m) => m['user_id'] as String).toSet();
        if (memberIds.contains(teacher['id'])) {
          existingConversationId = conversation['id'];
          break;
        }
      }

      if (existingConversationId != null) {
        // Conversation already exists, navigate to it
        if (mounted) {
          context.push('/chat/$existingConversationId');
        }
        return;
      }

      // Create new conversation
      final conversationId = _uuid.v4();
      final conversationTitle = 'Chat with ${teacher['full_name']}';

      await supabase.Supabase.instance.client.from('conversations').insert({
        'id': conversationId,
        'title': conversationTitle,
        'is_group': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Add both users to the conversation
      await supabase.Supabase.instance.client
          .from('conversation_members')
          .insert([
        {
          'conversation_id': conversationId,
          'user_id': _currentUser!.id,
        },
        {
          'conversation_id': conversationId,
          'user_id': teacher['id'],
        },
      ]);

      // Refresh conversations list
      await _fetchConversations(_currentUser!);

      if (mounted) {
        // Navigate to the new conversation
        context.push('/chat/$conversationId');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started chat with ${teacher['full_name']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating conversation: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterConversations);
    _searchController.dispose();
    super.dispose();
  }
}

class _TeacherSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> teachers;
  final String currentUserId;

  const _TeacherSelectionDialog({
    required this.teachers,
    required this.currentUserId,
  });

  @override
  State<_TeacherSelectionDialog> createState() =>
      _TeacherSelectionDialogState();
}

class _TeacherSelectionDialogState extends State<_TeacherSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredTeachers {
    if (_searchQuery.isEmpty) return widget.teachers;
    return widget.teachers.where((teacher) {
      final name = teacher['full_name']?.toString().toLowerCase() ?? '';
      final bio = teacher['bio']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || bio.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isTablet ? 600 : double.infinity,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isTablet ? 24 : 20),
                  topRight: Radius.circular(isTablet ? 24 : 20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 12 : 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: isTablet ? 24 : 20,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select a Teacher',
                          style: TextStyle(
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_filteredTeachers.length} available teachers',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: isTablet ? 24 : 20,
                    ),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search teachers...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: isTablet ? 16 : 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade500,
                      size: isTablet ? 20 : 18,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 16 : 12,
                      vertical: isTablet ? 12 : 10,
                    ),
                  ),
                  style: TextStyle(fontSize: isTablet ? 16 : 14),
                ),
              ),
            ),

            // Teachers list
            Expanded(
              child: _filteredTeachers.isEmpty
                  ? _buildEmptyState(isTablet)
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 20 : 16,
                        vertical: isTablet ? 8 : 4,
                      ),
                      itemCount: _filteredTeachers.length,
                      itemBuilder: (context, index) {
                        final teacher = _filteredTeachers[index];
                        return _buildTeacherCard(teacher, isTablet);
                      },
                    ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(isTablet ? 24 : 20),
                  bottomRight: Radius.circular(isTablet ? 24 : 20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tap on a teacher to start chatting',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        color: Colors.grey.shade600,
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
  }

  Widget _buildEmptyState(bool isTablet) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 40 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: isTablet ? 48 : 40,
                color: Colors.grey.shade400,
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Text(
              'No teachers found',
              style: TextStyle(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: isTablet ? 8 : 6),
            Text(
              'Try adjusting your search terms',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> teacher, bool isTablet) {
    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 12 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
          onTap: () => Navigator.pop(context, teacher),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: isTablet ? 56 : 48,
                  height: isTablet ? 56 : 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryBlue,
                        AppTheme.primaryBlue.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                  ),
                  child: teacher['avatar_url'] != null
                      ? ClipRRect(
                          borderRadius:
                              BorderRadius.circular(isTablet ? 16 : 12),
                          child: Image.network(
                            teacher['avatar_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildAvatarFallback(teacher, isTablet),
                          ),
                        )
                      : _buildAvatarFallback(teacher, isTablet),
                ),

                SizedBox(width: isTablet ? 16 : 12),

                // Teacher info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher['full_name'] ?? 'Unknown Teacher',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (teacher['bio'] != null &&
                          teacher['bio'].toString().isNotEmpty) ...[
                        SizedBox(height: isTablet ? 4 : 2),
                        Text(
                          teacher['bio'],
                          style: TextStyle(
                            fontSize: isTablet ? 13 : 12,
                            color: Colors.grey.shade600,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: isTablet ? 4 : 2),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 8 : 6,
                          vertical: isTablet ? 4 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(isTablet ? 8 : 6),
                        ),
                        child: Text(
                          'Teacher',
                          style: TextStyle(
                            fontSize: isTablet ? 11 : 10,
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(width: isTablet ? 12 : 8),

                // Arrow icon
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: isTablet ? 24 : 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(Map<String, dynamic> teacher, bool isTablet) {
    return Center(
      child: Text(
        (teacher['full_name'] ?? 'T').substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: isTablet ? 20 : 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
