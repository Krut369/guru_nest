import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/theme/app_theme.dart';

class NewChatPage extends StatefulWidget {
  const NewChatPage({super.key});

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch all users from Supabase, no auth logic, no filtering
      final response = await supabase.Supabase.instance.client
          .from('users')
          .select('id, full_name, avatar_url, role')
          .order('full_name');

      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _startConversation(Map<String, dynamic> user) async {
    try {
      final currentUser = supabase.Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // Check if conversation already exists
      final existingConversation = await supabase.Supabase.instance.client
          .from('conversations')
          .select('id')
          .contains(
              'participant_ids', [currentUser.id, user['id']]).maybeSingle();

      if (existingConversation != null) {
        if (mounted) {
          context.push('/chat/${existingConversation['id']}');
        }
        return;
      }

      // Create new conversation
      final conversation = await supabase.Supabase.instance.client
          .from('conversations')
          .insert({
            'participant_ids': [currentUser.id, user['id']],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // Add participants
      await supabase.Supabase.instance.client
          .from('conversation_participants')
          .insert([
        {
          'conversation_id': conversation['id'],
          'user_id': currentUser.id,
        },
        {
          'conversation_id': conversation['id'],
          'user_id': user['id'],
        },
      ]);

      if (mounted) {
        context.push('/chat/${conversation['id']}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting conversation: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchController.text.isEmpty) return _users;
    final query = _searchController.text.toLowerCase();
    return _users.where((user) {
      final name = user['full_name']?.toString().toLowerCase() ?? '';
      return name.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
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
        child: SafeArea(
          child: Column(
            children: [
              // Modern Header
              _buildModernHeader(context, isTablet),

              // Search Bar
              _buildSearchBar(context, isTablet),

              // Users List
              Expanded(
                child: _isLoading
                    ? _buildLoadingState(context, isTablet)
                    : _error != null
                        ? _buildErrorState(context, isTablet)
                        : _filteredUsers.isEmpty
                            ? _buildEmptyState(context, isTablet)
                            : _buildUsersList(context, isTablet),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : 20),
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
          SizedBox(width: isTablet ? 20 : 16),

          // Icon and Title
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.person_add,
              color: Colors.white,
              size: isTablet ? 32 : 28,
            ),
          ),
          SizedBox(width: isTablet ? 20 : 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Chat',
                  style: TextStyle(
                    fontSize: isTablet ? 32 : 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Start a conversation with someone',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search users...',
            hintStyle: TextStyle(
              color: Colors.grey[500],
              fontSize: isTablet ? 16 : 14,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: AppTheme.primaryBlue,
              size: isTablet ? 24 : 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: Colors.grey[500],
                      size: isTablet ? 20 : 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 16 : 12,
            ),
          ),
          onChanged: (value) {
            setState(() {});
          },
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
            'Loading users...',
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
              'Failed to load users',
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
              onPressed: _loadUsers,
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
                Icons.person_search,
                size: isTablet ? 48 : 40,
                color: AppTheme.primaryBlue,
              ),
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No users found'
                  : 'No matching users',
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTablet ? 12 : 8),
            Text(
              _searchController.text.isEmpty
                  ? 'There are no users available to chat with'
                  : 'Try adjusting your search terms',
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

  Widget _buildUsersList(BuildContext context, bool isTablet) {
    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserCard(user, context, isTablet);
      },
    );
  }

  Widget _buildUserCard(
    Map<String, dynamic> user,
    BuildContext context,
    bool isTablet,
  ) {
    final name = user['full_name'] as String? ?? 'Unknown User';
    final role = user['role'] as String? ?? 'User';
    final avatarUrl = user['avatar_url'] as String?;

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppTheme.primaryBlue.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryBlue.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _startConversation(user),
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
                      colors: [
                        AppTheme.primaryBlue,
                        AppTheme.primaryBlue.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            avatarUrl,
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

                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: isTablet ? 4 : 2),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 12 : 8,
                          vertical: isTablet ? 6 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(role).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getRoleColor(role).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 10,
                            fontWeight: FontWeight.bold,
                            color: _getRoleColor(role),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Chat Button
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
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: isTablet ? 24 : 20,
                    ),
                    onPressed: () => _startConversation(user),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return AppTheme.errorRed;
      case 'teacher':
        return AppTheme.successGreen;
      case 'student':
        return AppTheme.primaryBlue;
      default:
        return Colors.grey;
    }
  }
}
