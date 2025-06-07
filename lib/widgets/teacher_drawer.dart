import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

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
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  title: 'Dashboard',
                  onTap: () {
                    context.go('/teacher/dashboard');
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Course Management',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.school_outlined,
                  selectedIcon: Icons.school,
                  title: 'Manage Courses',
                  onTap: () {
                    context.go('/teacher/courses');
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Lesson Management',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.menu_book,
                  selectedIcon: Icons.menu_book,
                  title: 'Add Lesson',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Select Course'),
                        content: FutureBuilder<List<Map<String, dynamic>>>(
                          future: supabase.Supabase.instance.client
                              .from('courses')
                              .select()
                              .order('created_at', ascending: false),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Text('No courses available');
                            }
                            return SizedBox(
                              width: double.maxFinite,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  final course = snapshot.data![index];
                                  return ListTile(
                                    title: Text(
                                        course['title'] ?? 'Untitled Course'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      context.push(
                                          '/teacher/course/${course['id']}/add-lesson');
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.list_alt,
                  selectedIcon: Icons.list_alt,
                  title: 'List Lessons',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Select Course'),
                        content: FutureBuilder<List<Map<String, dynamic>>>(
                          future: supabase.Supabase.instance.client
                              .from('courses')
                              .select()
                              .order('created_at', ascending: false),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Text('No courses available');
                            }
                            return SizedBox(
                              width: double.maxFinite,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  final course = snapshot.data![index];
                                  return ListTile(
                                    title: Text(
                                        course['title'] ?? 'Untitled Course'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      context.push(
                                          '/teacher/course/${course['id']}/lessons');
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.edit,
                  selectedIcon: Icons.edit,
                  title: 'Edit Lesson',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Select Course'),
                        content: FutureBuilder<List<Map<String, dynamic>>>(
                          future: supabase.Supabase.instance.client
                              .from('courses')
                              .select()
                              .order('created_at', ascending: false),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Text('No courses available');
                            }
                            return SizedBox(
                              width: double.maxFinite,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  final course = snapshot.data![index];
                                  return ListTile(
                                    title: Text(
                                        course['title'] ?? 'Untitled Course'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      context.push(
                                          '/teacher/course/${course['id']}/edit-lessons');
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.delete_outline,
                  selectedIcon: Icons.delete,
                  title: 'Delete Lesson',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Select Course'),
                        content: FutureBuilder<List<Map<String, dynamic>>>(
                          future: supabase.Supabase.instance.client
                              .from('courses')
                              .select()
                              .order('created_at', ascending: false),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError) {
                              return Text('Error: ${snapshot.error}');
                            }
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Text('No courses available');
                            }
                            return SizedBox(
                              width: double.maxFinite,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  final course = snapshot.data![index];
                                  return ListTile(
                                    title: Text(
                                        course['title'] ?? 'Untitled Course'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      context.push(
                                          '/teacher/course/${course['id']}/delete-lessons');
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(),
                const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Category Management',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.category,
                  selectedIcon: Icons.category,
                  title: 'Add Category',
                  onTap: () {
                    context.go('/teacher/add-category');
                    Navigator.pop(context);
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.category,
                  selectedIcon: Icons.category,
                  title: 'Manage Categories',
                  onTap: () {
                    context.go('/teacher/categories');
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Other',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.people_outline,
                  selectedIcon: Icons.people,
                  title: 'Students',
                  onTap: () {
                    context.go('/teacher/students');
                    Navigator.pop(context);
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.analytics_outlined,
                  selectedIcon: Icons.analytics,
                  title: 'Analytics',
                  onTap: () {
                    context.go('/teacher/analytics');
                    Navigator.pop(context);
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  title: 'Settings',
                  onTap: () {
                    context.go('/teacher/settings');
                    Navigator.pop(context);
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.help_outline,
                  selectedIcon: Icons.help,
                  title: 'Help & Support',
                  onTap: () {
                    context.go('/teacher/help');
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/teacher/profile');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppTheme.errorRed),
                  title: const Text(
                    'Logout',
                    style: TextStyle(color: AppTheme.errorRed),
                  ),
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

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required IconData selectedIcon,
    required String title,
    required VoidCallback onTap,
  }) {
    final isSelected = _isCurrentRoute(context, title);
    return ListTile(
      leading: Icon(
        isSelected ? selectedIcon : icon,
        color: isSelected ? AppTheme.primaryBlue : Colors.grey[600],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryBlue : Colors.grey[800],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: onTap,
    );
  }

  bool _isCurrentRoute(BuildContext context, String title) {
    final currentRoute = GoRouterState.of(context).uri.path;
    switch (title) {
      case 'Dashboard':
        return currentRoute == '/teacher/dashboard';
      case 'Manage Courses':
        return currentRoute == '/teacher/courses';
      case 'Students':
        return currentRoute == '/teacher/students';
      case 'Analytics':
        return currentRoute == '/teacher/analytics';
      case 'Settings':
        return currentRoute == '/teacher/settings';
      case 'Help & Support':
        return currentRoute == '/teacher/help';
      case 'Add Category':
        return currentRoute == '/teacher/add-category';
      case 'List Lessons':
        return currentRoute.contains('/lessons');
      case 'Edit Lesson':
        return currentRoute.contains('/edit-lessons');
      case 'Delete Lesson':
        return currentRoute.contains('/delete-lessons');
      default:
        return false;
    }
  }
}
