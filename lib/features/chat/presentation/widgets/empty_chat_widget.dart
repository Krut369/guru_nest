import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../../core/theme/app_theme.dart';

class EmptyChatWidget extends StatelessWidget {
  final bool isSearching;
  final String searchQuery;
  final VoidCallback onClearSearch;

  const EmptyChatWidget({
    super.key,
    required this.isSearching,
    required this.searchQuery,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.chat_bubble_outline,
            size: 80,
            color: AppTheme.textGrey,
          ),
          SizedBox(height: 2.h),
          Text(
            isSearching ? 'No results found' : 'No conversations yet',
            style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
              color: AppTheme.textGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            isSearching
                ? 'Try searching with different keywords'
                : 'Start a conversation to begin chatting',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textLightGrey,
            ),
            textAlign: TextAlign.center,
          ),
          if (isSearching) ...[
            SizedBox(height: 2.h),
            TextButton(
              onPressed: onClearSearch,
              child: const Text('Clear Search'),
            ),
          ],
        ],
      ),
    );
  }
}
