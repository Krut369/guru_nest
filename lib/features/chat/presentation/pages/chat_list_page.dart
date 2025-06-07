import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/custom_app_bar.dart';

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
  static const String _lastRefreshKey = 'chat_list_last_refresh';
  static const String _cachedConversationsKey = 'cached_conversations';
  static const String _userIdKey = 'user_id';
  static const String _userTokenKey = 'user_token';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    // First try to load cached data
    await _loadCachedData();
    // Then refresh from server
    await _loadConversations();
  }

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cachedConversationsKey);

      if (cachedData != null) {
        setState(() {
          _conversations = List<Map<String, dynamic>>.from(
            (supabase.Supabase.instance.client
                    .rpc('parse_json', params: {'json': cachedData}) as List)
                .map((item) => item as Map<String, dynamic>)
                .toList(),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      // If there's an error loading cached data, just continue with server load
      print('Error loading cached data: $e');
    }
  }

  Future<void> _saveCachedData(List<Map<String, dynamic>> conversations) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedConversationsKey, conversations.toString());
      await prefs.setString(_lastRefreshKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Error saving cached data: $e');
    }
  }

  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<void> _loadConversations() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = await _getUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      setState(() {
        _userId = userId;
      });

      final response = await supabase.Supabase.instance.client
          .from('conversations')
          .select('''
            id,
            last_message,
            updated_at,
            unread_count,
            participants:conversation_participants(
              user:users(
                id,
                full_name,
                avatar_url
              )
            )
          ''').contains('participant_ids', [
        userId
      ]).order('updated_at', ascending: false);

      final conversations = List<Map<String, dynamic>>.from(response);

      // Save to cache
      await _saveCachedData(conversations);

      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshConversations() async {
    await _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Messages'),
      body: RefreshIndicator(
        onRefresh: _refreshConversations,
        child: _isLoading
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
                              conversation['participants'] ?? []);

                          // Get the other participant (not the current user)
                          final otherParticipant = participants.firstWhere(
                            (p) => p['user']?['id'] != _userId,
                            orElse: () => {
                              'user': {'full_name': 'Unknown User'}
                            },
                          );

                          final unreadCount =
                              conversation['unread_count'] as int? ?? 0;

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
                                child: otherParticipant['user']
                                            ?['avatar_url'] !=
                                        null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(25),
                                        child: Image.network(
                                          otherParticipant['user']
                                                  ?['avatar_url'] ??
                                              '',
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
                                otherParticipant['user']?['full_name'] ??
                                    'Unknown User',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                conversation['last_message'] ??
                                    'No messages yet',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: unreadCount > 0
                                  ? Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        unreadCount.toString(),
                                        style: const TextStyle(
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/chat/new');
        },
        backgroundColor: AppTheme.primaryBlue,
        child: const Icon(Icons.add),
      ),
    );
  }
}
