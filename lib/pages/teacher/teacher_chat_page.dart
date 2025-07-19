import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../chat/chat_list_page.dart';

class TeacherChatPage extends StatefulWidget {
  const TeacherChatPage({super.key});

  @override
  State<TeacherChatPage> createState() => _TeacherChatPageState();
}

class _TeacherChatPageState extends State<TeacherChatPage> {
  @override
  void initState() {
    super.initState();
    print('TeacherChatPage: Initialized'); // Debug print
  }

  @override
  Widget build(BuildContext context) {
    print('TeacherChatPage: Building widget'); // Debug print
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Teacher Chat',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Chat Features'),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Available Features:'),
                      SizedBox(height: 8),
                      Text('• Swipe left to delete conversations'),
                      Text('• Tap chat title to view members'),
                      Text('• Use three-dot menu for group management'),
                      Text('• Add/remove members in group chats'),
                      Text('• Delete groups or leave groups'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              AppTheme.primaryBlue.withOpacity(0.03),
              AppTheme.primaryBlue.withOpacity(0.05),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: const ChatListPage(),
      ),
    );
  }
}
