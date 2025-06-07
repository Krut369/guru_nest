import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/theme/app_theme.dart';
import '../../../services/auth_service.dart';

class HomeSection extends StatefulWidget {
  const HomeSection({super.key});

  @override
  State<HomeSection> createState() => _HomeSectionState();
}

class _HomeSectionState extends State<HomeSection> {
  final _authService = AuthService();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _enrolledCourses = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _recentCourses = [];

  @override
  void initState() {
    super.initState();
    _initializeHomeData();
  }

  Future<void> _initializeHomeData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Ensure user is loaded from SharedPreferences
      await _authService.loadSavedUser();

      final userId = _authService.currentUser?.id;
      print('Current user ID after loading: $userId');

      if (userId == null) {
        setState(() {
          _isLoading = false;
          _error = 'Please log in to access courses';
        });
        return;
      }

      // User is loaded, now fetch data
      await _fetchData();
    } catch (e) {
      print('Error initializing home data: $e');
      setState(() {
        _isLoading = false;
        _error = 'Failed to initialize data: ${e.toString()}';
      });
    }
  }

  Future<void> _fetchData() async {
    // The user check is now done in _initializeHomeData
    final userId = _authService.currentUser?.id;

    // This check should ideally not be needed if _initializeHomeData is successful,
    // but keeping it for safety
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Please log in to access courses';
      });
      return;
    }

    try {
      // Fetch enrolled courses with progress
      final enrolledCoursesData =
          await Supabase.instance.client.from('enrollments').select('''
            *,
            courses!course_id (
              *,
              users!teacher_id (
                id,
                full_name,
                email
              )
            )
          ''').eq('student_id', userId).order('enrolled_at', ascending: false);

      // Fetch categories with course counts
      final categoriesData = await Supabase.instance.client
          .from('courses')
          .select('category_id')
          .order('category_id');

      // Count courses per category
      final categoryCounts = <String, int>{};
      for (var course in categoriesData) {
        final category = course['category_id']?.toString() ?? 'Uncategorized';
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }

      // Fetch recent courses (not enrolled)
      final recentCoursesData =
          await Supabase.instance.client.from('courses').select('''
            *,
            users!teacher_id (
              id,
              full_name,
              email
            )
          ''').order('created_at', ascending: false).limit(3);

      setState(() {
        _enrolledCourses = List<Map<String, dynamic>>.from(enrolledCoursesData);
        _categories = categoryCounts.entries.map((entry) {
          return {
            'name': entry.key,
            'count': entry.value,
            'icon': _getCategoryIcon(entry.key),
            'color': _getCategoryColor(entry.key),
          };
        }).toList();
        _recentCourses = List<Map<String, dynamic>>.from(recentCoursesData);
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching home data: $e');
      setState(() {
        _error = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'development':
        return Icons.code;
      case 'design':
        return Icons.palette;
      case 'business':
        return Icons.business;
      case 'marketing':
        return Icons.trending_up;
      default:
        return Icons.category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'development':
        return AppTheme.primaryBlue;
      case 'design':
        return AppTheme.warningOrange;
      case 'business':
        return AppTheme.successGreen;
      case 'marketing':
        return AppTheme.errorRed;
      default:
        return AppTheme.primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;

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
                onPressed: _fetchData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
              child: Text(
                user?.fullName.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.fullName ?? 'User',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user?.email ?? 'user@example.com',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => context.go('/dashboard/analytics'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await _authService.signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error signing out: ${e.toString()}'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildQuickActionButton(
                  title: 'Manage Courses',
                  icon: Icons.school,
                  color: AppTheme.primaryBlue,
                  onTap: () => context.push('/teacher/courses'),
                ),
                _buildQuickActionButton(
                  title: 'Manage Categories',
                  icon: Icons.category,
                  color: AppTheme.successGreen,
                  onTap: () => context.push('/teacher/categories'),
                ),
                _buildQuickActionButton(
                  title: 'Manage Lessons',
                  icon: Icons.menu_book,
                  color: AppTheme.warningOrange,
                  onTap: () => context.push('/teacher/lessons'),
                ),
                _buildQuickActionButton(
                  title: 'Analytics',
                  icon: Icons.analytics,
                  color: AppTheme.errorRed,
                  onTap: () => context.push('/teacher/analytics'),
                ),
                _buildQuickActionButton(
                  title: 'Chat',
                  icon: Icons.chat,
                  color: AppTheme.primaryBlue,
                  onTap: () => context.push('/teacher/chat'),
                ),
                _buildQuickActionButton(
                  title: 'Students',
                  icon: Icons.people,
                  color: AppTheme.successGreen,
                  onTap: () => context.push('/teacher/students'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (_enrolledCourses.isNotEmpty) ...[
              _buildQuickAccessCard(context),
              const SizedBox(height: 32),
            ],
            _buildCategories(context, 2),
            const SizedBox(height: 32),
            _buildRecentCourses(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard(BuildContext context) {
    if (_enrolledCourses.isEmpty) return const SizedBox.shrink();

    final latestCourse = _enrolledCourses.first['courses'];
    final progress = _enrolledCourses.first['progress'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.defaultPadding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlueLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Continue Learning',
            style: TextStyle(
              color: AppTheme.backgroundWhite,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.defaultSpacing),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latestCourse['title'] ?? 'Untitled Course',
                      style: const TextStyle(
                        color: AppTheme.backgroundWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppTheme.smallSpacing),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor:
                          AppTheme.backgroundWhite.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.backgroundWhite,
                      ),
                    ),
                    const SizedBox(height: AppTheme.smallSpacing),
                    Text(
                      '${(progress * 100).toInt()}% Complete',
                      style: const TextStyle(
                        color: AppTheme.backgroundWhite,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  final courseId = latestCourse['id'];
                  if (courseId != null) {
                    context.push('/course/$courseId');
                  }
                },
                icon: const Icon(
                  Icons.play_circle_fill,
                  color: AppTheme.backgroundWhite,
                  size: 48,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategories(BuildContext context, int crossAxisCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textDark,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppTheme.defaultSpacing),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.0,
            crossAxisSpacing: AppTheme.defaultSpacing,
            mainAxisSpacing: AppTheme.defaultSpacing,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: () {
                  context.go('/dashboard/courses?category=${category['name']}');
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (category['color'] as Color).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          category['icon'] as IconData,
                          color: category['color'] as Color,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${category['count']} Courses',
                        style: const TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentCourses(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Courses',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textDark,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppTheme.defaultSpacing),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentCourses.length,
          itemBuilder: (context, index) {
            final course = _recentCourses[index];
            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: course['image_url'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            course['image_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.book,
                                color: AppTheme.primaryBlue,
                                size: 24,
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.book,
                          color: AppTheme.primaryBlue,
                          size: 24,
                        ),
                ),
                title: Text(
                  course['title'] ?? 'Untitled Course',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                subtitle: Text(
                  course['users']?['full_name'] ?? 'Unknown Teacher',
                  style: const TextStyle(
                    color: AppTheme.textGrey,
                    fontSize: 11,
                  ),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  final courseId = course['id'];
                  if (courseId != null) {
                    context.push('/course/$courseId');
                  }
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
