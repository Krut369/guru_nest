import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../widgets/custom_icon_widget.dart';
import 'chat_list_item_widget.dart';

class ChatSearchDelegate extends SearchDelegate<String> {
  final List<Map<String, dynamic>> allChats;
  final Function(Map<String, dynamic>) onChatTap;

  ChatSearchDelegate(this.allChats, this.onChatTap);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return _buildEmptyState('Start typing to search conversations');
    }

    final filteredChats = allChats.where((chat) {
      final searchLower = query.toLowerCase();
      return chat['participantName']
              .toString()
              .toLowerCase()
              .contains(searchLower) ||
          chat['subject'].toString().toLowerCase().contains(searchLower) ||
          chat['lastMessage'].toString().toLowerCase().contains(searchLower);
    }).toList();

    if (filteredChats.isEmpty) {
      return _buildEmptyState('No conversations found for "$query"');
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      itemCount: filteredChats.length,
      itemBuilder: (context, index) {
        final chat = filteredChats[index];
        return ChatListItemWidget(
          chat: chat,
          onTap: () {
            onChatTap(chat);
            close(context, chat['id']);
          },
          onLongPress: () {
            // Handle long press if needed
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomIconWidget(
            iconName: 'search',
            color: AppTheme.textLightGrey,
            size: 64,
          ),
          SizedBox(height: 2.h),
          Text(
            message,
            style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.textGrey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  String get searchFieldLabel => 'Search conversations...';

  @override
  TextStyle? get searchFieldStyle => AppTheme.lightTheme.textTheme.bodyLarge;

  @override
  ThemeData appBarTheme(BuildContext context) {
    return AppTheme.lightTheme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        elevation: 1,
        iconTheme: IconThemeData(
          color: AppTheme.lightTheme.colorScheme.onSurface,
        ),
        titleTextStyle: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
          color: AppTheme.lightTheme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
