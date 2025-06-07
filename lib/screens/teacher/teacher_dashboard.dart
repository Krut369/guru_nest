import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/theme/app_theme.dart';
import '../../models/teacher_dashboard_data.dart';
import '../../models/user_model.dart';
import '../../pages/teacher/manage_lessons_page.dart';
import '../../services/auth_service.dart';
import '../../services/teacher_dashboard_service.dart';
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
  TeacherDashboardData? _dashboardData;

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
      } else if (location.contains('/teacher/chat')) {
        setState(() => _currentIndex = 3);
      } else if (location.contains('/teacher/analytics')) {
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
        });
        await _loadDashboardData(prefs);
      } else {
        setState(() {
          _error = 'User not found';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading user: [31m${e.toString()}[0m';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDashboardData(SharedPreferences prefs) async {
    try {
      final service = TeacherDashboardService(prefs);
      final data = await service.getDashboardData();
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading dashboard data: [31m${e.toString()}[0m';
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
    print(
        'Teacher Dashboard: Navigation selected - index: $index'); // Debug print
    setState(() => _currentIndex = index);
    switch (index) {
      case 0:
        print('Teacher Dashboard: Navigating to dashboard'); // Debug print
        context.go('/teacher/dashboard');
        break;
      case 1:
        print('Teacher Dashboard: Navigating to courses'); // Debug print
        context.go('/teacher/courses');
        break;
      case 2:
        print('Teacher Dashboard: Navigating to students'); // Debug print
        context.go('/teacher/students');
        break;
      case 3:
        print('Teacher Dashboard: Navigating to chat'); // Debug print
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

    // Use real dashboard data
    final dashboardData = _dashboardData;
    final totalQuizzes = dashboardData?.totalQuizzes ?? 0;
    final totalCategories = dashboardData?.totalCategories ?? 0;
    final totalLessons = dashboardData?.courseStats
            .fold<int>(0, (sum, c) => sum + c.totalQuizzes) ??
        0;
    final totalMaterials = dashboardData?.totalMaterials ?? 0;

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
            // SUMMARY CARD
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatSummary(
                        icon: Icons.quiz,
                        label: 'Quizzes',
                        value: totalQuizzes),
                    _StatSummary(
                        icon: Icons.category,
                        label: 'Categories',
                        value: totalCategories),
                    _StatSummary(
                        icon: Icons.menu_book,
                        label: 'Lessons',
                        value: totalLessons),
                    _StatSummary(
                        icon: Icons.attach_file,
                        label: 'Materials',
                        value: totalMaterials),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
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
                  icon: Icons.category,
                  label: 'Manage Categories',
                  onTap: () => context.go('/teacher/categories'),
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
                _buildQuickActionButton(
                  icon: Icons.chat_outlined,
                  label: 'Chat',
                  onTap: () {
                    print(
                        'Teacher Dashboard: Quick action chat button pressed'); // Debug print
                    context.go('/teacher/chat');
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
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}

class _StatSummary extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  const _StatSummary(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32, color: AppTheme.primaryBlue),
        const SizedBox(height: 8),
        Text(
          value.toString(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }
}
