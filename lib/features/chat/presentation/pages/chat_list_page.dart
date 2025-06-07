import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/custom_icon_widget.dart';
import '../widgets/chat_list_item_widget.dart';
import '../widgets/chat_search_delegate.dart';
import '../widgets/empty_chat_widget.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  final bool _isSearching = false;
  String _searchQuery = '';

  // Mock chat data - replace with actual Supabase integration
  final List<Map<String, dynamic>> _allChats = [
    {
      "id": "chat_001",
      "participantId": "teacher_001",
      "participantName": "Dr. Sarah Johnson",
      "participantAvatar":
          "https://images.unsplash.com/photo-1494790108755-2616b612b786?w=150&h=150&fit=crop&crop=face",
      "participantRole": "teacher",
      "subject": "Chemistry",
      "lastMessage":
          "Great work on your latest assignment! I can see you've really understood the concepts.",
      "lastMessageTime": DateTime.now().subtract(const Duration(minutes: 5)),
      "lastMessageSender": "teacher_001",
      "unreadCount": 2,
      "isOnline": true,
      "isTyping": false,
      "isPinned": true,
      "isMuted": false,
      "chatType": "individual"
    },
    {
      "id": "chat_002",
      "participantId": "teacher_002",
      "participantName": "Prof. Michael Chen",
      "participantAvatar":
          "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face",
      "participantRole": "teacher",
      "subject": "Mathematics",
      "lastMessage": "Don't forget to submit your calculus homework by Friday.",
      "lastMessageTime": DateTime.now().subtract(const Duration(hours: 2)),
      "lastMessageSender": "teacher_002",
      "unreadCount": 0,
      "isOnline": false,
      "isTyping": false,
      "isPinned": false,
      "isMuted": false,
      "chatType": "individual"
    },
    {
      "id": "chat_003",
      "participantId": "teacher_003",
      "participantName": "Dr. Emily Rodriguez",
      "participantAvatar":
          "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face",
      "participantRole": "teacher",
      "subject": "Physics",
      "lastMessage":
          "The lab report looks good. Just make sure to include the error analysis section.",
      "lastMessageTime": DateTime.now().subtract(const Duration(hours: 4)),
      "lastMessageSender": "teacher_003",
      "unreadCount": 1,
      "isOnline": true,
      "isTyping": false,
      "isPinned": false,
      "isMuted": false,
      "chatType": "individual"
    },
    {
      "id": "chat_004",
      "participantId": "teacher_004",
      "participantName": "Mr. James Wilson",
      "participantAvatar":
          "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop&crop=face",
      "participantRole": "teacher",
      "subject": "English Literature",
      "lastMessage":
          "Your essay on Shakespeare was excellent. Keep up the great work!",
      "lastMessageTime": DateTime.now().subtract(const Duration(days: 1)),
      "lastMessageSender": "teacher_004",
      "unreadCount": 0,
      "isOnline": false,
      "isTyping": false,
      "isPinned": false,
      "isMuted": false,
      "chatType": "individual"
    },
    {
      "id": "chat_005",
      "participantId": "teacher_005",
      "participantName": "Dr. Lisa Thompson",
      "participantAvatar":
          "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150&h=150&fit=crop&crop=face",
      "participantRole": "teacher",
      "subject": "Biology",
      "lastMessage":
          "The cell structure diagrams need more detail. Let me know if you need help.",
      "lastMessageTime": DateTime.now().subtract(const Duration(days: 2)),
      "lastMessageSender": "teacher_005",
      "unreadCount": 0,
      "isOnline": true,
      "isTyping": true,
      "isPinned": false,
      "isMuted": true,
      "chatType": "individual"
    },
    {
      "id": "chat_006",
      "participantId": "teacher_006",
      "participantName": "Prof. David Kumar",
      "participantAvatar":
          "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face",
      "participantRole": "teacher",
      "subject": "Computer Science",
      "lastMessage":
          "Your coding project is looking great! The algorithm is efficient.",
      "lastMessageTime": DateTime.now().subtract(const Duration(days: 3)),
      "lastMessageSender": "teacher_006",
      "unreadCount": 0,
      "isOnline": false,
      "isTyping": false,
      "isPinned": false,
      "isMuted": false,
      "chatType": "individual"
    },
  ];

  List<Map<String, dynamic>> _filteredChats = [];

  @override
  void initState() {
    super.initState();
    _filteredChats = List.from(_allChats);
    _sortChatsByRecentActivity();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredChats = List.from(_allChats);
      } else {
        _filteredChats = _allChats.where((chat) {
          return chat['participantName'].toLowerCase().contains(query) ||
              chat['subject'].toLowerCase().contains(query) ||
              chat['lastMessage'].toLowerCase().contains(query);
        }).toList();
      }
      _sortChatsByRecentActivity();
    });
  }

  void _sortChatsByRecentActivity() {
    _filteredChats.sort((a, b) {
      // Pinned chats first
      if (a['isPinned'] && !b['isPinned']) return -1;
      if (!a['isPinned'] && b['isPinned']) return 1;

      // Then by most recent activity
      return b['lastMessageTime'].compareTo(a['lastMessageTime']);
    });
  }

  Future<void> _refreshChats() async {
    setState(() {
      _isLoading = true;
    });

    // Mock API call delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock new message update
    if (_allChats.isNotEmpty) {
      _allChats[0]['lastMessage'] = 'New message received!';
      _allChats[0]['lastMessageTime'] = DateTime.now();
      _allChats[0]['unreadCount'] = (_allChats[0]['unreadCount'] ?? 0) + 1;
    }

    setState(() {
      _isLoading = false;
      _filteredChats = List.from(_allChats);
      _sortChatsByRecentActivity();
    });
  }

  void _onChatTap(Map<String, dynamic> chat) {
    // Mark chat as read
    setState(() {
      chat['unreadCount'] = 0;
    });

    // Navigate to chat screen with chat data
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: chat,
    );
  }

  void _onChatLongPress(Map<String, dynamic> chat) {
    HapticFeedback.mediumImpact();
    _showChatOptions(chat);
  }

  void _showChatOptions(Map<String, dynamic> chat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: chat['isPinned'] ? 'push_pin' : 'push_pin_outlined',
                color: AppTheme.lightTheme.colorScheme.onSurface,
                size: 24,
              ),
              title: Text(
                chat['isPinned'] ? 'Unpin Chat' : 'Pin Chat',
                style: AppTheme.lightTheme.textTheme.bodyLarge,
              ),
              onTap: () {
                Navigator.pop(context);
                _togglePinChat(chat);
              },
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: chat['isMuted'] ? 'volume_off' : 'volume_up',
                color: AppTheme.lightTheme.colorScheme.onSurface,
                size: 24,
              ),
              title: Text(
                chat['isMuted'] ? 'Unmute Chat' : 'Mute Chat',
                style: AppTheme.lightTheme.textTheme.bodyLarge,
              ),
              onTap: () {
                Navigator.pop(context);
                _toggleMuteChat(chat);
              },
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'person',
                color: AppTheme.lightTheme.colorScheme.onSurface,
                size: 24,
              ),
              title: Text(
                'View Profile',
                style: AppTheme.lightTheme.textTheme.bodyLarge,
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/profile',
                  arguments: chat['participantId'],
                );
              },
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'delete',
                color: AppTheme.errorRed,
                size: 24,
              ),
              title: Text(
                'Delete Chat',
                style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.errorRed,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(chat);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  void _togglePinChat(Map<String, dynamic> chat) {
    setState(() {
      chat['isPinned'] = !chat['isPinned'];
      _sortChatsByRecentActivity();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          chat['isPinned'] ? 'Chat pinned' : 'Chat unpinned',
        ),
      ),
    );
  }

  void _toggleMuteChat(Map<String, dynamic> chat) {
    setState(() {
      chat['isMuted'] = !chat['isMuted'];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          chat['isMuted'] ? 'Chat muted' : 'Chat unmuted',
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> chat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text(
          'Are you sure you want to delete this chat with \\${chat['participantName']}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChat(chat);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteChat(Map<String, dynamic> chat) {
    setState(() {
      _allChats.removeWhere((c) => c['id'] == chat['id']);
      _filteredChats.removeWhere((c) => c['id'] == chat['id']);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chat with \\${chat['participantName']} deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            setState(() {
              _allChats.add(chat);
              _filteredChats = List.from(_allChats);
              _sortChatsByRecentActivity();
            });
          },
        ),
      ),
    );
  }

  void _showSearch() {
    showSearch(
      context: context,
      delegate: ChatSearchDelegate(_allChats, _onChatTap),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_isSearching) _buildSearchBar(),
          Expanded(
            child: _filteredChats.isEmpty
                ? EmptyChatWidget(
                    isSearching: _searchQuery.isNotEmpty,
                    searchQuery: _searchQuery,
                    onClearSearch: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                        _filteredChats = List.from(_allChats);
                      });
                    },
                  )
                : RefreshIndicator(
                    onRefresh: _refreshChats,
                    color: AppTheme.lightTheme.colorScheme.primary,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 1.h,
                      ),
                      itemCount: _filteredChats.length,
                      itemBuilder: (context, index) {
                        final chat = _filteredChats[index];
                        return ChatListItemWidget(
                          chat: chat,
                          onTap: () => _onChatTap(chat),
                          onLongPress: () => _onChatLongPress(chat),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      elevation: 1,
      shadowColor: AppTheme.lightTheme.colorScheme.shadow,
      title: Text(
        'Messages',
        style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          onPressed: _showSearch,
          icon: CustomIconWidget(
            iconName: 'search',
            color: AppTheme.lightTheme.colorScheme.onSurface,
            size: 24,
          ),
        ),
        PopupMenuButton<String>(
          icon: CustomIconWidget(
            iconName: 'more_vert',
            color: AppTheme.lightTheme.colorScheme.onSurface,
            size: 24,
          ),
          onSelected: (value) {
            switch (value) {
              case 'mark_all_read':
                _markAllAsRead();
                break;
              case 'archived':
                _showArchivedChats();
                break;
              case 'settings':
                _showChatSettings();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'mark_all_read',
              child: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'mark_email_read',
                    color: AppTheme.lightTheme.colorScheme.onSurface,
                    size: 20,
                  ),
                  SizedBox(width: 3.w),
                  const Text('Mark All as Read'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'archived',
              child: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'archive',
                    color: AppTheme.lightTheme.colorScheme.onSurface,
                    size: 20,
                  ),
                  SizedBox(width: 3.w),
                  const Text('Archived'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  CustomIconWidget(
                    iconName: 'settings',
                    color: AppTheme.lightTheme.colorScheme.onSurface,
                    size: 20,
                  ),
                  SizedBox(width: 3.w),
                  const Text('Settings'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.lightTheme.colorScheme.outline,
            width: 0.5,
          ),
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          prefixIcon: CustomIconWidget(
            iconName: 'search',
            color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                  },
                  icon: CustomIconWidget(
                    iconName: 'clear',
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppTheme.lightTheme.colorScheme.surfaceContainerHighest,
          contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
          _onSearchChanged();
        },
      ),
    );
  }

  void _markAllAsRead() {
    setState(() {
      for (var chat in _allChats) {
        chat['unreadCount'] = 0;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All chats marked as read')),
    );
  }

  void _showArchivedChats() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Archived chats feature coming soon')),
    );
  }

  void _showChatSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat settings feature coming soon')),
    );
  }
}
