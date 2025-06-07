import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../pages/teacher/manage_lessons_page.dart';
import '../../services/auth_service.dart';
import '../../widgets/teacher_drawer.dart';
import 'quiz_management_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final _authService = AuthService();
  User? _currentUser;
  bool _isLoading = true;
  String? _error;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _updateCurrentIndex();
  }

  void _updateCurrentIndex() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final location = GoRouterState.of(context).uri.path;
      if (location.contains('/teacher/courses')) {
        setState(() => _currentIndex = 1);
      } else if (location.contains('/teacher/students')) {
        setState(() => _currentIndex = 2);
      } else if (location.contains('/teacher/analytics')) {
        setState(() => _currentIndex = 3);
      } else if (location.contains('/teacher/chat')) {
        setState(() => _currentIndex = 4);
      } else {
        setState(() => _currentIndex = 0);
      }
    });
  }

  Future<void> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        setState(() {
          _currentUser = User.fromJson(userData);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'User not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading user: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _onDestinationSelected(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        context.go('/teacher/dashboard');
        break;
      case 1:
        context.go('/teacher/courses');
        break;
      case 2:
        context.go('/teacher/students');
        break;
      case 3:
        context.go('/teacher/analytics');
        break;
      case 4:
        context.go('/teacher/chat');
        break;
    }
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? backgroundColor,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: backgroundColor ?? Colors.white,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: backgroundColor != null
                    ? Colors.white
                    : AppTheme.primaryBlue,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      backgroundColor != null ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.errorRed),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  if (mounted) {
                    context.go('/login');
                  }
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
        ],
      ),
      drawer: TeacherDrawer(
        user: _currentUser,
        onSignOut: _handleSignOut,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildQuickActionButton(
                  icon: Icons.school_outlined,
                  label: 'Manage Courses',
                  onTap: () => context.go('/teacher/courses'),
                ),
                _buildQuickActionButton(
                  icon: Icons.menu_book,
                  label: 'Manage Lessons',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageLessonsPage(),
                      ),
                    );
                  },
                ),
                _buildQuickActionButton(
                  icon: Icons.quiz,
                  label: 'Manage Quiz',
                  onTap: () {
                    if (!mounted) return;

                    try {
                      print(
                          'Attempting to navigate to quiz management'); // Debug print
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QuizManagementScreen(
                            courseId: '',
                          ),
                        ),
                      );
                    } catch (e, stackTrace) {
                      print('Navigation error details:');
                      print('Error: $e');
                      print('Stack trace: $stackTrace');

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Error navigating to quiz management: ${e.toString()}'),
                            backgroundColor: AppTheme.errorRed,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  },
                ),
                _buildQuickActionButton(
                  icon: Icons.attach_file,
                  label: 'Add Material',
                  onTap: () async {
                    try {
                      final courses = await supabase.Supabase.instance.client
                          .from('courses')
                          .select('id, title')
                          .eq('teacher_id', _currentUser!.id)
                          .order('created_at', ascending: false);

                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Select Course'),
                            content: courses.isEmpty
                                ? const Text(
                                    'You need to create a course first.')
                                : SizedBox(
                                    width: double.maxFinite,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: courses.length,
                                      itemBuilder: (context, index) {
                                        final course = courses[index];
                                        return ListTile(
                                          title: Text(course['title'] ??
                                              'Untitled Course'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            if (context.mounted) {
                                              context.push(
                                                  '/teacher/course/${course['id']}/add-material');
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Error loading courses: ${e.toString()}'),
                            backgroundColor: AppTheme.errorRed,
                          ),
                        );
                      }
                    }
                  },
                ),
                _buildQuickActionButton(
                  icon: Icons.category,
                  label: 'Manage Categories',
                  onTap: () => context.go('/teacher/categories'),
                ),
                _buildQuickActionButton(
                  icon: Icons.analytics_outlined,
                  label: 'Analytics',
                  onTap: () => context.go('/teacher/analytics'),
                ),
                _buildQuickActionButton(
                  icon: Icons.attach_file,
                  label: 'Manage Material',
                  onTap: () async {
                    try {
                      final courses = await supabase.Supabase.instance.client
                          .from('courses')
                          .select('id, title')
                          .eq('teacher_id', _currentUser!.id)
                          .order('created_at', ascending: false);

                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Select Course'),
                            content: courses.isEmpty
                                ? const Text(
                                    'You need to create a course first.')
                                : SizedBox(
                                    width: double.maxFinite,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: courses.length,
                                      itemBuilder: (context, index) {
                                        final course = courses[index];
                                        return ListTile(
                                          title: Text(course['title'] ??
                                              'Untitled Course'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            if (context.mounted) {
                                              context.push(
                                                  '/teacher/course/${course['id']}/materials');
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('Error loading courses: ${e.toString()}'),
                            backgroundColor: AppTheme.errorRed,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Courses',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Students',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}
