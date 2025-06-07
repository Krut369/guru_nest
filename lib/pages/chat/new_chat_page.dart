import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';

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

      final currentUser = supabase.Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final response = await supabase.Supabase.instance.client
          .from('users')
          .select('id, full_name, avatar_url, role')
          .neq('id', currentUser.id)
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
    return Scaffold(
      appBar: const CustomAppBar(title: 'New Chat'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_search,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No users found',
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
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
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
                                    child: user['avatar_url'] != null
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(25),
                                            child: Image.network(
                                              user['avatar_url'],
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
                                    user['full_name'] ?? 'Unknown User',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    user['role'] ?? 'User',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  onTap: () => _startConversation(user),
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
