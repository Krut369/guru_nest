import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../models/user_model.dart';

class TeacherDrawer extends StatelessWidget {
  final User? user;
  final VoidCallback onSignOut;

  const TeacherDrawer({
    super.key,
    required this.user,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppTheme.primaryBlue,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      user?.fullName.substring(0, 1).toUpperCase() ?? 'T',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.fullName ?? 'Teacher',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user?.email ?? 'teacher@example.com',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('Dashboard'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/teacher/dashboard');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.school),
                  title: const Text('My Courses'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/teacher/courses');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people),
                  title: const Text('Students'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/teacher/students');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.chat),
                  title: const Text('Chat'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/teacher/chat');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/teacher/profile');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/teacher/settings');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign Out'),
                  onTap: () {
                    Navigator.pop(context);
                    onSignOut();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'GuruNest v1.0.0',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
