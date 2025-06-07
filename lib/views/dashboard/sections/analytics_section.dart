import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/analytics_service.dart';

class AnalyticsSection extends StatefulWidget {
  const AnalyticsSection({super.key});

  @override
  State<AnalyticsSection> createState() => _AnalyticsSectionState();
}

class _AnalyticsSectionState extends State<AnalyticsSection> {
  final _analyticsService = AnalyticsService();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _analyticsData;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Test Supabase connection first
      final connectionOk = await _analyticsService.testConnection();
      if (!connectionOk) {
        setState(() {
          _isLoading = false;
          _error =
              'Unable to connect to database. Please check your internet connection.';
        });
        return;
      }

      // Load user from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');

      if (userJson == null) {
        setState(() {
          _isLoading = false;
          _error = 'Please log in to view analytics';
        });
        return;
      }

      final userData = jsonDecode(userJson) as Map<String, dynamic>;
      _userId = userData['id'] as String;

      if (_userId == null) {
        setState(() {
          _isLoading = false;
          _error = 'User ID not found';
        });
        return;
      }

      print('Loading analytics for user: $_userId'); // Debug print

      // Load comprehensive analytics data
      final analytics = await _analyticsService.getStudentAnalytics(_userId!);
      print('Analytics data loaded: ${analytics.length} items'); // Debug print

      // Debug: Print the structure of analytics data
      print('Analytics data structure:');
      analytics.forEach((key, value) {
        if (value is List) {
          print('  $key: List with ${value.length} items');
        } else if (value is Map) {
          print('  $key: Map with ${value.length} fields');
        } else {
          print('  $key: ${value.runtimeType} = $value');
        }
      });

      setState(() {
        _analyticsData = analytics;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics data: $e');
      setState(() {
        _isLoading = false;
        _error = 'Failed to load analytics data: ${e.toString()}';
      });
    }
  }

  void _navigateToDetailedAnalytics(BuildContext context) {
    // Navigate to analytics section as a full-screen page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AnalyticsFullScreenPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 768;
    final isDesktop = screenWidth > 1024;

    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBlue.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                strokeWidth: 3,
              ),
              SizedBox(height: 24),
              Text(
                'Loading your analytics...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryBlue.withOpacity(0.05),
            Colors.white,
            AppTheme.primaryBlue.withOpacity(0.02),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isTablet ? 32 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            _buildHeader(context, isTablet),
            SizedBox(height: isTablet ? 40 : 32),

            // Overview Cards
            _buildOverviewCards(context, isTablet, isDesktop),
            SizedBox(height: isTablet ? 40 : 32),

            // Recent Activity
            _buildRecentActivity(context, isTablet),
            SizedBox(height: isTablet ? 40 : 32),

            // Course Progress
            _buildCourseProgress(context, isTablet),
            SizedBox(height: isTablet ? 40 : 32),

            // Detailed Quiz Statistics
            _buildDetailedQuizStatistics(context, isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.primaryBlue.withOpacity(0.8)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.analytics,
                color: Colors.white,
                size: isTablet ? 32 : 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Learning Analytics ',
                    style: TextStyle(
                      fontSize: isTablet ? 32 : 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  Text(
                    'Track your progress and achievements',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // Add navigation button
            IconButton(
              onPressed: () {
                _navigateToDetailedAnalytics(context);
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_forward,
                  color: AppTheme.primaryBlue,
                  size: isTablet ? 24 : 20,
                ),
              ),
              tooltip: 'View Detailed Analytics',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewCards(
      BuildContext context, bool isTablet, bool isDesktop) {
    if (_analyticsData == null) {
      return Container(
        padding: EdgeInsets.all(isTablet ? 32 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: isTablet ? 80 : 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No analytics data available',
                style: TextStyle(
                  fontSize: isTablet ? 20 : 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final userReport = _analyticsData!['user_report'] as Map<String, dynamic>;
    final totalSpent = _analyticsData!['total_spent'] as double;
    final averageQuizScore = _analyticsData!['average_quiz_score'] as double;
    final lessonProgress =
        _analyticsData!['lesson_progress'] as List<dynamic>? ?? [];

    // Check if user has any activity
    final hasActivity = (userReport['total_courses_enrolled'] ?? 0) > 0 ||
        (userReport['total_lessons_accessed'] ?? 0) > 0 ||
        (userReport['total_quizzes'] ?? 0) > 0 ||
        lessonProgress.isNotEmpty;

    if (!hasActivity) {
      return Container(
        padding: EdgeInsets.all(isTablet ? 40 : 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBlue.withOpacity(0.1),
              AppTheme.primaryBlue.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.primaryBlue.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school,
                size: isTablet ? 60 : 48,
                color: AppTheme.primaryBlue,
              ),
            ),
            SizedBox(height: isTablet ? 24 : 20),
            Text(
              'Start Your Learning Journey',
              style: TextStyle(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTablet ? 16 : 12),
            Text(
              'Enroll in courses, access lessons, and take quizzes to see your analytics here.',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final metrics = [
      {
        'title': 'Courses',
        'value': userReport['total_courses_enrolled']?.toString() ?? '0',
        'icon': Icons.school,
        'color': AppTheme.primaryBlue,
        'subtitle': 'Enrolled',
        'gradient': [
          AppTheme.primaryBlue,
          AppTheme.primaryBlue.withOpacity(0.7)
        ],
      },
      {
        'title': 'Lessons',
        'value': lessonProgress.length.toString(),
        'icon': Icons.menu_book,
        'color': AppTheme.successGreen,
        'subtitle': 'Completed',
        'gradient': [
          AppTheme.successGreen,
          AppTheme.successGreen.withOpacity(0.7)
        ],
      },
      {
        'title': 'Quizzes',
        'value': userReport['total_quizzes']?.toString() ?? '0',
        'icon': Icons.assignment,
        'color': Colors.purple,
        'subtitle': 'Taken',
        'gradient': [Colors.purple, Colors.purple.withOpacity(0.7)],
      },
      {
        'title': 'Streak',
        'value': userReport['learning_streak']?.toString() ?? '0',
        'icon': Icons.local_fire_department,
        'color': Colors.orange,
        'subtitle': 'Days',
        'gradient': [Colors.orange, Colors.orange.withOpacity(0.7)],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: TextStyle(
            fontSize: isTablet ? 28 : 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        SizedBox(height: isTablet ? 24 : 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop ? 4 : (isTablet ? 3 : 2),
            crossAxisSpacing: isTablet ? 16 : 12, // Reduced spacing
            mainAxisSpacing: isTablet ? 16 : 12, // Reduced spacing
            childAspectRatio:
                isTablet ? 1.1 : 0.9, // Further reduced to give more height
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return Container(
              constraints: const BoxConstraints(
                minHeight: 120, // Minimum height to prevent too small cards
                maxHeight: 200, // Maximum height to prevent overflow
              ),
              child: _ModernAnalyticsCard(
                title: metric['title'] as String,
                value: metric['value'] as String,
                icon: metric['icon'] as IconData,
                color: metric['color'] as Color,
                subtitle: metric['subtitle'] as String,
                gradient: metric['gradient'] as List<Color>,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context, bool isTablet) {
    if (_analyticsData == null) return const SizedBox.shrink();

    final recentActivity = _analyticsData!['recent_activity'] as List<dynamic>;

    return Container(
      padding: EdgeInsets.all(isTablet ? 32 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.successGreen,
                      AppTheme.successGreen.withOpacity(0.8)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.history,
                  color: Colors.white,
                  size: isTablet ? 24 : 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successGreen,
                      ),
                    ),
                    Text(
                      'Your latest learning activities',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 24 : 20),
          if (recentActivity.isEmpty)
            Container(
              padding: EdgeInsets.all(isTablet ? 40 : 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.successGreen.withOpacity(0.05),
                    Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inbox,
                      size: isTablet ? 48 : 40,
                      color: AppTheme.successGreen,
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : 12),
                  Text(
                    'No Recent Activity',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successGreen,
                    ),
                  ),
                  SizedBox(height: isTablet ? 8 : 6),
                  Text(
                    'Start learning to see your activities here',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentActivity.length,
              itemBuilder: (context, index) {
                final activity = recentActivity[index];
                return _ModernActivityItem(
                  title: activity['title'] as String,
                  timestamp: activity['timestamp'] as String,
                  icon: activity['icon'] as IconData,
                  color: activity['color'] as Color,
                  isTablet: isTablet,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCourseProgress(BuildContext context, bool isTablet) {
    if (_analyticsData == null) return const SizedBox.shrink();

    final userReport = _analyticsData!['user_report'] as Map<String, dynamic>;
    final totalCourses =
        _safeToDouble(userReport['total_courses_enrolled'] ?? 0);
    final lessonProgress =
        _analyticsData!['lesson_progress'] as List<dynamic>? ?? [];
    final totalLessons = lessonProgress.length.toDouble();
    final averageScore = _safeToDouble(userReport['average_quiz_score'] ?? 0.0);
    final learningStreak = _safeToDouble(userReport['learning_streak'] ?? 0);

    // Get real totals from database for progress targets
    final totalAvailableCourses =
        _safeToDouble(userReport['total_available_courses'] ?? 0);
    final totalAvailableLessons =
        _safeToDouble(userReport['total_available_lessons'] ?? 0);
    final totalAvailableQuizzes =
        _safeToDouble(userReport['total_available_quizzes'] ?? 0);

    // Use real database totals for targets, with fallbacks for empty database
    final courseTarget =
        totalAvailableCourses > 0 ? totalAvailableCourses : 5.0;
    final lessonTarget =
        totalAvailableLessons > 0 ? totalAvailableLessons : 20.0;
    const quizTarget = 100.0; // Quiz performance is always out of 100
    const streakTarget = 7.0; // Target for learning streak

    return Container(
      padding: EdgeInsets.all(isTablet ? 32 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.warningOrange,
                      AppTheme.warningOrange.withOpacity(0.8)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: isTablet ? 24 : 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learning Progress',
                      style: TextStyle(
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warningOrange,
                      ),
                    ),
                    Text(
                      'Track your learning milestones',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 32 : 24),
          _buildModernProgressItem(
            'Course Engagement',
            totalCourses,
            courseTarget,
            AppTheme.primaryBlue,
            Icons.school,
            isTablet,
          ),
          SizedBox(height: isTablet ? 20 : 16),
          _buildModernProgressItem(
            'Lesson Completion',
            totalLessons,
            lessonTarget,
            AppTheme.successGreen,
            Icons.menu_book,
            isTablet,
          ),
          SizedBox(height: isTablet ? 20 : 16),
          _buildModernProgressItem(
            'Quiz Performance',
            averageScore,
            quizTarget,
            AppTheme.errorRed,
            Icons.quiz,
            isTablet,
          ),
          SizedBox(height: isTablet ? 20 : 16),
          _buildModernProgressItem(
            'Learning Streak',
            learningStreak,
            streakTarget,
            Colors.orange,
            Icons.local_fire_department,
            isTablet,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(
    String title,
    double value,
    double maxValue,
    Color color,
    bool isTablet,
  ) {
    final percentage = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    final isComplete = percentage >= 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: isTablet ? 16 : 14,
                ),
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)}/${maxValue.toStringAsFixed(1)}',
              style: TextStyle(
                color: isComplete ? AppTheme.successGreen : color,
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 14 : 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage,
          backgroundColor: color.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation<Color>(
            isComplete ? AppTheme.successGreen : color,
          ),
          minHeight: isTablet ? 12 : 8,
        ),
        const SizedBox(height: 4),
        Text(
          isComplete
              ? 'Complete! 🎉'
              : '${(percentage * 100).toStringAsFixed(1)}% Complete',
          style: TextStyle(
            color: isComplete ? AppTheme.successGreen : Colors.grey[600],
            fontSize: isTablet ? 12 : 10,
            fontWeight: isComplete ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedStats(
      BuildContext context, bool isTablet, bool isDesktop) {
    if (_analyticsData == null) return const SizedBox.shrink();

    final enrollments = _analyticsData!['enrollments'] as List<dynamic>;
    final quizResults = _analyticsData!['quiz_results'] as List<dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detailed Statistics',
          style: TextStyle(
            fontSize: isTablet ? 24 : 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        SizedBox(height: isTablet ? 20 : 16),
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildEnrollmentsList(context, isTablet)),
              const SizedBox(width: 20),
              Expanded(child: _buildQuizResultsList(context, isTablet)),
            ],
          )
        else
          Column(
            children: [
              _buildEnrollmentsList(context, isTablet),
              SizedBox(height: isTablet ? 24 : 20),
              _buildQuizResultsList(context, isTablet),
            ],
          ),
      ],
    );
  }

  Widget _buildEnrollmentsList(BuildContext context, bool isTablet) {
    final enrollments = _analyticsData!['enrollments'] as List<dynamic>;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.school,
                  color: AppTheme.primaryBlue,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Enrolled Courses',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: isTablet ? 16 : 12),
            if (enrollments.isEmpty)
              Center(
                child: Text(
                  'No courses enrolled yet',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isTablet ? 14 : 12,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: enrollments.length,
                itemBuilder: (context, index) {
                  final enrollment = enrollments[index];
                  final course = enrollment['courses'];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                      child: Icon(
                        Icons.school,
                        color: AppTheme.primaryBlue,
                        size: isTablet ? 20 : 16,
                      ),
                    ),
                    title: Text(
                      course['title'] ?? 'Unknown Course',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Enrolled: ${_formatDate(enrollment['enrolled_at'])}',
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 10,
                        color: Colors.grey[600],
                      ),
                    ),
                    trailing: Text(
                      '\$${(course['price'] ?? 0.0).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizResultsList(BuildContext context, bool isTablet) {
    final quizResults = _analyticsData!['quiz_results'] as List<dynamic>;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.quiz,
                  color: AppTheme.primaryBlue,
                  size: isTablet ? 24 : 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Quiz Results',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: isTablet ? 16 : 12),
            if (quizResults.isEmpty)
              Center(
                child: Text(
                  'No quiz results yet',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isTablet ? 14 : 12,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: quizResults.length,
                itemBuilder: (context, index) {
                  final result = quizResults[index];
                  final quiz = result['quizzes'];
                  final score = result['score'] as double;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: _getScoreColor(score).withOpacity(0.1),
                      child: Icon(
                        Icons.quiz,
                        color: _getScoreColor(score),
                        size: isTablet ? 20 : 16,
                      ),
                    ),
                    title: Text(
                      quiz['title'] ?? 'Unknown Quiz',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Taken: ${_formatDate(result['taken_at'])}',
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 10,
                        color: Colors.grey[600],
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getScoreColor(score),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${score.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
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
        return Colors.grey;
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return AppTheme.successGreen;
    if (score >= 80) return AppTheme.primaryBlue;
    if (score >= 70) return AppTheme.warningOrange;
    return AppTheme.errorRed;
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}';
    } catch (e) {
      return 'Invalid';
    }
  }

  Widget _buildDebugSection(BuildContext context, bool isTablet) {
    if (_analyticsData == null) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bug_report,
                  color: AppTheme.primaryBlue,
                  size: isTablet ? 28 : 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Debug Information',
                  style: TextStyle(
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Text(
              'User ID: $_userId',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                fontFamily: 'monospace',
                backgroundColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Data Sections: ${_analyticsData!.length}',
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            ..._analyticsData!.entries.map((entry) {
              final key = entry.key;
              final value = entry.value;
              String displayValue;

              if (value is List) {
                displayValue = 'List[${value.length}]';
              } else if (value is Map) {
                displayValue = 'Map{${value.length}}';
              } else {
                displayValue = value.toString();
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '$key: $displayValue',
                  style: TextStyle(
                    fontSize: isTablet ? 12 : 10,
                    fontFamily: 'monospace',
                    color: Colors.grey[700],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  double _safeToDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    } else {
      return 0.0;
    }
  }

  Widget _buildModernProgressItem(
    String title,
    double value,
    double maxValue,
    Color color,
    IconData icon,
    bool isTablet,
  ) {
    final percentage = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    final isComplete = percentage >= 1.0;

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: isTablet ? 24 : 20,
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isTablet ? 16 : 14,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    Text(
                      '${value.toStringAsFixed(1)}/${maxValue.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: isComplete ? AppTheme.successGreen : color,
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 14 : 12,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isTablet ? 12 : 8),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isComplete ? AppTheme.successGreen : color,
                  ),
                  minHeight: isTablet ? 8 : 6,
                ),
                SizedBox(height: isTablet ? 8 : 6),
                Text(
                  isComplete
                      ? 'Complete! 🎉'
                      : '${(percentage * 100).toStringAsFixed(1)}% Complete',
                  style: TextStyle(
                    color: isComplete ? AppTheme.successGreen : color,
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: isComplete ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedQuizStatistics(BuildContext context, bool isTablet) {
    if (_analyticsData == null) return const SizedBox.shrink();

    final userReport = _analyticsData!['user_report'] as Map<String, dynamic>;
    final averageQuizScore = userReport['average_quiz_score'] as double? ?? 0.0;
    final highestQuizScore = userReport['highest_quiz_score'] as int? ?? 0;
    final lowestQuizScore = userReport['lowest_quiz_score'] as int? ?? 100;
    final bestQuizTitle = userReport['best_quiz_title'] as String?;
    final worstQuizTitle = userReport['worst_quiz_title'] as String?;
    final totalQuizzes = userReport['total_quizzes'] as int? ?? 0;

    if (totalQuizzes == 0) {
      return Container(
        padding: EdgeInsets.all(isTablet ? 32 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.errorRed,
                        AppTheme.errorRed.withOpacity(0.8)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.quiz,
                    color: Colors.white,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quiz Performance',
                        style: TextStyle(
                          fontSize: isTablet ? 24 : 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.errorRed,
                        ),
                      ),
                      Text(
                        'Your quiz performance statistics',
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isTablet ? 24 : 20),
            Container(
              padding: EdgeInsets.all(isTablet ? 40 : 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.errorRed.withOpacity(0.05),
                    Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.quiz_outlined,
                      size: isTablet ? 48 : 40,
                      color: AppTheme.errorRed,
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : 12),
                  Text(
                    'No Quiz Results Yet',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.errorRed,
                    ),
                  ),
                  SizedBox(height: isTablet ? 8 : 6),
                  Text(
                    'Take quizzes to see your performance statistics here',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(isTablet ? 32 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.errorRed,
                      AppTheme.errorRed.withOpacity(0.8)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.quiz,
                  color: Colors.white,
                  size: isTablet ? 24 : 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quiz Performance',
                      style: TextStyle(
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.errorRed,
                      ),
                    ),
                    Text(
                      'Your detailed quiz statistics',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 32 : 24),
          _buildQuizStatCard(
            'Average Score',
            '${averageQuizScore.toStringAsFixed(1)}%',
            AppTheme.errorRed,
            Icons.analytics,
            isTablet,
          ),
          SizedBox(height: isTablet ? 20 : 16),
          _buildQuizStatCard(
            'Highest Score',
            '$highestQuizScore%',
            AppTheme.successGreen,
            Icons.trending_up,
            isTablet,
            subtitle: bestQuizTitle ?? 'Unknown Quiz',
          ),
          SizedBox(height: isTablet ? 20 : 16),
          _buildQuizStatCard(
            'Lowest Score',
            '$lowestQuizScore%',
            Colors.orange,
            Icons.trending_down,
            isTablet,
            subtitle: worstQuizTitle ?? 'Unknown Quiz',
          ),
        ],
      ),
    );
  }

  Widget _buildQuizStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
    bool isTablet, {
    String? subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: isTablet ? 24 : 20,
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 16 : 14,
                    color: Colors.grey[800],
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 10,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _AnalyticsCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 17,
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 8,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernAnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;
  final List<Color> gradient;

  const _ModernAnalyticsCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced from 16
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16), // Reduced from 20
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8, // Reduced from 10
            offset: const Offset(0, 4), // Reduced from 5
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // Added to prevent overflow
        children: [
          Icon(
            icon,
            size: 28, // Reduced from 32
            color: Colors.white,
          ),
          const SizedBox(height: 8), // Reduced from 12
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20, // Reduced from 24
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6), // Reduced from 8
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11, // Reduced from 12
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2), // Reduced from 4
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 9, // Reduced from 10
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernActivityItem extends StatelessWidget {
  final String title;
  final String timestamp;
  final IconData icon;
  final Color color;
  final bool isTablet;

  const _ModernActivityItem({
    required this.title,
    required this.timestamp,
    required this.icon,
    required this.color,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(isTablet ? 20 : 16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: isTablet ? 24 : 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                size: isTablet ? 16 : 14,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(timestamp),
                style: TextStyle(
                  fontSize: isTablet ? 12 : 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.arrow_forward_ios,
            size: isTablet ? 16 : 14,
            color: color,
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes} minutes ago';
        }
        return '${difference.inHours} hours ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Invalid date';
    }
  }
}

class _ActivityItem extends StatelessWidget {
  final String title;
  final String timestamp;
  final IconData icon;
  final Color color;
  final bool isTablet;

  const _ActivityItem({
    required this.title,
    required this.timestamp,
    required this.icon,
    required this.color,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon, color: color, size: isTablet ? 20 : 16),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        subtitle: Text(_formatDate(timestamp),
            style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Invalid';
    }
  }
}

// Full-screen analytics page
class AnalyticsFullScreenPage extends StatefulWidget {
  final String? studentId; // Add optional studentId parameter

  const AnalyticsFullScreenPage({
    super.key,
    this.studentId, // Add this parameter
  });

  @override
  State<AnalyticsFullScreenPage> createState() =>
      _AnalyticsFullScreenPageState();
}

class _AnalyticsFullScreenPageState extends State<AnalyticsFullScreenPage> {
  final _analyticsService = AnalyticsService();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _analyticsData;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Test Supabase connection first
      final connectionOk = await _analyticsService.testConnection();
      if (!connectionOk) {
        setState(() {
          _isLoading = false;
          _error =
              'Unable to connect to database. Please check your internet connection.';
        });
        return;
      }

      // If studentId is provided, use it; otherwise load current user
      if (widget.studentId != null) {
        _userId = widget.studentId;
        print('Loading analytics for student: $_userId'); // Debug print
      } else {
        // Load user from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final userJson = prefs.getString('current_user');

        if (userJson == null) {
          setState(() {
            _isLoading = false;
            _error = 'Please log in to view analytics';
          });
          return;
        }

        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        _userId = userData['id'] as String;

        if (_userId == null) {
          setState(() {
            _isLoading = false;
            _error = 'User ID not found';
          });
          return;
        }
        print('Loading analytics for current user: $_userId'); // Debug print
      }

      // Load comprehensive analytics data
      final analytics = await _analyticsService.getStudentAnalytics(_userId!);
      print('Analytics data loaded: ${analytics.length} items'); // Debug print

      setState(() {
        _analyticsData = analytics;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics data: $e');
      setState(() {
        _isLoading = false;
        _error = 'Failed to load analytics data: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 768;
    final isDesktop = screenWidth > 1024;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryBlue.withOpacity(0.1),
                    Colors.white,
                  ],
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Loading your analytics...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryBlue.withOpacity(0.05),
                    Colors.white,
                    AppTheme.primaryBlue.withOpacity(0.02),
                  ],
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isTablet ? 32 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    _buildHeader(context, isTablet),
                    SizedBox(height: isTablet ? 40 : 32),

                    // Overview Cards
                    _buildOverviewCards(context, isTablet, isDesktop),
                    SizedBox(height: isTablet ? 40 : 32),

                    // Recent Activity
                    _buildRecentActivity(context, isTablet),
                    SizedBox(height: isTablet ? 40 : 32),

                    // Course Progress
                    _buildCourseProgress(context, isTablet),
                    SizedBox(height: isTablet ? 40 : 32),

                    // Detailed Quiz Statistics
                    _buildDetailedQuizStatistics(context, isTablet),
                  ],
                ),
              ),
            ),
    );
  }

  // Reuse the same methods from AnalyticsSection
  Widget _buildHeader(BuildContext context, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryBlue,
                    AppTheme.primaryBlue.withOpacity(0.8)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.analytics,
                color: Colors.white,
                size: isTablet ? 32 : 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Learning Analytics ',
                    style: TextStyle(
                      fontSize: isTablet ? 32 : 28,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  Text(
                    'Track your progress and achievements',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Add placeholder methods for the other sections
  Widget _buildOverviewCards(
      BuildContext context, bool isTablet, bool isDesktop) {
    if (_analyticsData == null) {
      return Container(
        padding: EdgeInsets.all(isTablet ? 32 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: isTablet ? 80 : 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No analytics data available',
                style: TextStyle(
                  fontSize: isTablet ? 20 : 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final userReport = _analyticsData!['user_report'] as Map<String, dynamic>;
    final totalSpent = _analyticsData!['total_spent'] as double;
    final averageQuizScore = _analyticsData!['average_quiz_score'] as double;
    final lessonProgress =
        _analyticsData!['lesson_progress'] as List<dynamic>? ?? [];

    // Check if user has any activity
    final hasActivity = (userReport['total_courses_enrolled'] ?? 0) > 0 ||
        (userReport['total_lessons_accessed'] ?? 0) > 0 ||
        (userReport['total_quizzes'] ?? 0) > 0 ||
        lessonProgress.isNotEmpty;

    if (!hasActivity) {
      return Container(
        padding: EdgeInsets.all(isTablet ? 40 : 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBlue.withOpacity(0.1),
              AppTheme.primaryBlue.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppTheme.primaryBlue.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school,
                size: isTablet ? 60 : 48,
                color: AppTheme.primaryBlue,
              ),
            ),
            SizedBox(height: isTablet ? 24 : 20),
            Text(
              'Start Your Learning Journey',
              style: TextStyle(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTablet ? 16 : 12),
            Text(
              'Enroll in courses, access lessons, and take quizzes to see your analytics here.',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final metrics = [
      {
        'title': 'Courses',
        'value': userReport['total_courses_enrolled']?.toString() ?? '0',
        'icon': Icons.school,
        'color': AppTheme.primaryBlue,
        'subtitle': 'Enrolled',
        'gradient': [
          AppTheme.primaryBlue,
          AppTheme.primaryBlue.withOpacity(0.7)
        ],
      },
      {
        'title': 'Lessons',
        'value': lessonProgress.length.toString(),
        'icon': Icons.menu_book,
        'color': AppTheme.successGreen,
        'subtitle': 'Completed',
        'gradient': [
          AppTheme.successGreen,
          AppTheme.successGreen.withOpacity(0.7)
        ],
      },
      {
        'title': 'Quizzes',
        'value': userReport['total_quizzes']?.toString() ?? '0',
        'icon': Icons.assignment,
        'color': Colors.purple,
        'subtitle': 'Taken',
        'gradient': [Colors.purple, Colors.purple.withOpacity(0.7)],
      },
      {
        'title': 'Streak',
        'value': userReport['learning_streak']?.toString() ?? '0',
        'icon': Icons.local_fire_department,
        'color': Colors.orange,
        'subtitle': 'Days',
        'gradient': [Colors.orange, Colors.orange.withOpacity(0.7)],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: TextStyle(
            fontSize: isTablet ? 28 : 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        SizedBox(height: isTablet ? 24 : 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop ? 4 : (isTablet ? 3 : 2),
            crossAxisSpacing: isTablet ? 16 : 12,
            mainAxisSpacing: isTablet ? 16 : 12,
            childAspectRatio: isTablet ? 1.1 : 0.9,
          ),
          itemCount: metrics.length,
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return Container(
              constraints: const BoxConstraints(
                minHeight: 120,
                maxHeight: 200,
              ),
              child: _ModernAnalyticsCard(
                title: metric['title'] as String,
                value: metric['value'] as String,
                icon: metric['icon'] as IconData,
                color: metric['color'] as Color,
                subtitle: metric['subtitle'] as String,
                gradient: metric['gradient'] as List<Color>,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context, bool isTablet) {
    if (_analyticsData == null) return const SizedBox.shrink();

    final recentActivity = _analyticsData!['recent_activity'] as List<dynamic>;

    return Container(
      padding: EdgeInsets.all(isTablet ? 32 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.successGreen,
                      AppTheme.successGreen.withOpacity(0.8)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.history,
                  color: Colors.white,
                  size: isTablet ? 24 : 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successGreen,
                      ),
                    ),
                    Text(
                      'Your latest learning activities',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 24 : 20),
          if (recentActivity.isEmpty)
            Container(
              padding: EdgeInsets.all(isTablet ? 40 : 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.successGreen.withOpacity(0.05),
                    Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inbox,
                      size: isTablet ? 48 : 40,
                      color: AppTheme.successGreen,
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : 12),
                  Text(
                    'No Recent Activity',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successGreen,
                    ),
                  ),
                  SizedBox(height: isTablet ? 8 : 6),
                  Text(
                    'Start learning to see your activities here',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentActivity.length,
              itemBuilder: (context, index) {
                final activity = recentActivity[index];
                return _ModernActivityItem(
                  title: activity['title'] as String,
                  timestamp: activity['timestamp'] as String,
                  icon: activity['icon'] as IconData,
                  color: activity['color'] as Color,
                  isTablet: isTablet,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCourseProgress(BuildContext context, bool isTablet) {
    if (_analyticsData == null) return const SizedBox.shrink();

    final userReport = _analyticsData!['user_report'] as Map<String, dynamic>;
    final totalCourses =
        _safeToDouble(userReport['total_courses_enrolled'] ?? 0);
    final lessonProgress =
        _analyticsData!['lesson_progress'] as List<dynamic>? ?? [];
    final totalLessons = lessonProgress.length.toDouble();
    final averageScore = _safeToDouble(userReport['average_quiz_score'] ?? 0.0);
    final learningStreak = _safeToDouble(userReport['learning_streak'] ?? 0);

    // Get real totals from database for progress targets
    final totalAvailableCourses =
        _safeToDouble(userReport['total_available_courses'] ?? 0);
    final totalAvailableLessons =
        _safeToDouble(userReport['total_available_lessons'] ?? 0);
    final totalAvailableQuizzes =
        _safeToDouble(userReport['total_available_quizzes'] ?? 0);

    // Use real database totals for targets, with fallbacks for empty database
    final courseTarget =
        totalAvailableCourses > 0 ? totalAvailableCourses : 5.0;
    final lessonTarget =
        totalAvailableLessons > 0 ? totalAvailableLessons : 20.0;
    const quizTarget = 100.0; // Quiz performance is always out of 100
    const streakTarget = 7.0; // Target for learning streak

    return Container(
      padding: EdgeInsets.all(isTablet ? 32 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.warningOrange,
                      AppTheme.warningOrange.withOpacity(0.8)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: isTablet ? 24 : 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learning Progress',
                      style: TextStyle(
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warningOrange,
                      ),
                    ),
                    Text(
                      'Track your learning milestones',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 32 : 24),
          _buildModernProgressItem(
            'Course Engagement',
            totalCourses,
            courseTarget,
            AppTheme.primaryBlue,
            Icons.school,
            isTablet,
          ),
          SizedBox(height: isTablet ? 20 : 16),
          _buildModernProgressItem(
            'Lesson Completion',
            totalLessons,
            lessonTarget,
            AppTheme.successGreen,
            Icons.menu_book,
            isTablet,
          ),
          SizedBox(height: isTablet ? 20 : 16),
          _buildModernProgressItem(
            'Quiz Performance',
            averageScore,
            quizTarget,
            AppTheme.errorRed,
            Icons.quiz,
            isTablet,
          ),
          SizedBox(height: isTablet ? 20 : 16),
          _buildModernProgressItem(
            'Learning Streak',
            learningStreak,
            streakTarget,
            Colors.orange,
            Icons.local_fire_department,
            isTablet,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedQuizStatistics(BuildContext context, bool isTablet) {
    if (_analyticsData == null) return const SizedBox.shrink();

    final userReport = _analyticsData!['user_report'] as Map<String, dynamic>;
    final averageQuizScore = userReport['average_quiz_score'] as double? ?? 0.0;
    final highestQuizScore = userReport['highest_quiz_score'] as int? ?? 0;
    final lowestQuizScore = userReport['lowest_quiz_score'] as int? ?? 100;
    final bestQuizTitle = userReport['best_quiz_title'] as String?;
    final worstQuizTitle = userReport['worst_quiz_title'] as String?;
    final totalQuizzes = userReport['total_quizzes'] as int? ?? 0;

    if (totalQuizzes == 0) {
      return Container(
        padding: EdgeInsets.all(isTablet ? 32 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.errorRed,
                        AppTheme.errorRed.withOpacity(0.8)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.quiz,
                    color: Colors.white,
                    size: isTablet ? 24 : 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quiz Performance',
                        style: TextStyle(
                          fontSize: isTablet ? 24 : 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.errorRed,
                        ),
                      ),
                      Text(
                        'Your quiz performance statistics',
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isTablet ? 24 : 20),
            Container(
              padding: EdgeInsets.all(isTablet ? 40 : 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.errorRed.withOpacity(0.05),
                    Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.quiz_outlined,
                      size: isTablet ? 48 : 40,
                      color: AppTheme.errorRed,
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : 12),
                  Text(
                    'No Quiz Results Yet',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.errorRed,
                    ),
                  ),
                  SizedBox(height: isTablet ? 8 : 6),
                  Text(
                    'Take quizzes to see your performance statistics here',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(isTablet ? 32 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.errorRed,
                      AppTheme.errorRed.withOpacity(0.8)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.quiz,
                  color: Colors.white,
                  size: isTablet ? 24 : 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quiz Performance',
                      style: TextStyle(
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.errorRed,
                      ),
                    ),
                    Text(
                      'Your detailed quiz statistics',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 32 : 24),
          _buildQuizStatCard(
            'Average Score',
            '${averageQuizScore.toStringAsFixed(1)}%',
            AppTheme.errorRed,
            Icons.analytics,
            isTablet,
          ),
          SizedBox(height: isTablet ? 20 : 16),
          _buildQuizStatCard(
            'Highest Score',
            '$highestQuizScore%',
            AppTheme.successGreen,
            Icons.trending_up,
            isTablet,
            subtitle: bestQuizTitle ?? 'Unknown Quiz',
          ),
          SizedBox(height: isTablet ? 20 : 16),
          _buildQuizStatCard(
            'Lowest Score',
            '$lowestQuizScore%',
            Colors.orange,
            Icons.trending_down,
            isTablet,
            subtitle: worstQuizTitle ?? 'Unknown Quiz',
          ),
        ],
      ),
    );
  }

  // Helper methods
  double _safeToDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    } else {
      return 0.0;
    }
  }

  Widget _buildModernProgressItem(
    String title,
    double value,
    double maxValue,
    Color color,
    IconData icon,
    bool isTablet,
  ) {
    final percentage = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    final isComplete = percentage >= 1.0;

    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: isTablet ? 24 : 20,
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isTablet ? 16 : 14,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                    Text(
                      '${value.toStringAsFixed(1)}/${maxValue.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: isComplete ? AppTheme.successGreen : color,
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 14 : 12,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isTablet ? 12 : 8),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isComplete ? AppTheme.successGreen : color,
                  ),
                  minHeight: isTablet ? 8 : 6,
                ),
                SizedBox(height: isTablet ? 8 : 6),
                Text(
                  isComplete
                      ? 'Complete! 🎉'
                      : '${(percentage * 100).toStringAsFixed(1)}% Complete',
                  style: TextStyle(
                    color: isComplete ? AppTheme.successGreen : color,
                    fontSize: isTablet ? 12 : 10,
                    fontWeight: isComplete ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
    bool isTablet, {
    String? subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: isTablet ? 24 : 20,
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 16 : 14,
                    color: Colors.grey[800],
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 10,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
