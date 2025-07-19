import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/analytics_service.dart';
import '../../../services/lesson_progress_service.dart';

class AnalyticsSectionWithLessonProgress extends StatefulWidget {
  const AnalyticsSectionWithLessonProgress({super.key});

  @override
  State<AnalyticsSectionWithLessonProgress> createState() =>
      _AnalyticsSectionWithLessonProgressState();
}

class _AnalyticsSectionWithLessonProgressState
    extends State<AnalyticsSectionWithLessonProgress> {
  final _analyticsService = AnalyticsService();
  final _lessonProgressService = LessonProgressService();
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

      print('Loading analytics for user: $_userId');

      // Load comprehensive analytics data
      final analytics = await _analyticsService.getStudentAnalytics(_userId!);
      print('Analytics data loaded: ${analytics.length} items');

      // Load lesson progress data from lesson_progress table
      final lessonProgressData = await _loadLessonProgressData(_userId!);

      // Merge lesson progress data with analytics
      analytics.addAll(lessonProgressData);

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

  // Load lesson progress data from lesson_progress table
  Future<Map<String, dynamic>> _loadLessonProgressData(String userId) async {
    try {
      // Get completed lessons
      final completedLessons =
          await _lessonProgressService.getCompletedLessons(userId);

      // Get student learning stats
      final learningStats =
          await _lessonProgressService.getStudentLearningStats(userId);

      // Get recent completions
      final recentCompletions =
          await _lessonProgressService.getRecentCompletions(userId, limit: 10);

      return {
        'lesson_progress': {
          'completed_lessons': completedLessons,
          'learning_stats': learningStats,
          'recent_completions': recentCompletions,
          'total_completed': completedLessons.length,
        }
      };
    } catch (e) {
      print('Error loading lesson progress data: $e');
      return {
        'lesson_progress': {
          'completed_lessons': [],
          'learning_stats': {
            'total_completed': 0,
            'this_week_completed': 0,
            'this_month_completed': 0,
            'average_per_week': '0.0',
          },
          'recent_completions': [],
          'total_completed': 0,
        }
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
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

            // Overview Cards with Lesson Progress
            _buildOverviewCardsWithLessonProgress(context, isTablet, isDesktop),
            SizedBox(height: isTablet ? 40 : 32),

            // Lesson Progress Section
            _buildLessonProgressSection(context, isTablet),
            SizedBox(height: isTablet ? 40 : 32),

            // Recent Lesson Completions
            _buildRecentLessonCompletions(context, isTablet),
            SizedBox(height: isTablet ? 40 : 32),

            // Learning Statistics
            _buildLearningStatistics(context, isTablet),
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
                    'Learning Analytics',
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

  Widget _buildOverviewCardsWithLessonProgress(
      BuildContext context, bool isTablet, bool isDesktop) {
    if (_analyticsData == null) {
      return _buildEmptyState(isTablet);
    }

    final userReport =
        _analyticsData!['user_report'] as Map<String, dynamic>? ?? {};
    final lessonProgress =
        _analyticsData!['lesson_progress'] as Map<String, dynamic>? ?? {};
    final learningStats =
        lessonProgress['learning_stats'] as Map<String, dynamic>? ?? {};

    // Get lesson progress data
    final totalCompletedLessons =
        lessonProgress['total_completed'] as int? ?? 0;
    final thisWeekCompleted = learningStats['this_week_completed'] as int? ?? 0;
    final thisMonthCompleted =
        learningStats['this_month_completed'] as int? ?? 0;
    final averagePerWeek =
        learningStats['average_per_week'] as String? ?? '0.0';

    final metrics = [
      {
        'title': 'Completed Lessons',
        'value': totalCompletedLessons.toString(),
        'icon': Icons.check_circle,
        'color': AppTheme.successGreen,
        'subtitle': 'Total',
        'gradient': [
          AppTheme.successGreen,
          AppTheme.successGreen.withOpacity(0.7)
        ],
      },
      {
        'title': 'This Week',
        'value': thisWeekCompleted.toString(),
        'icon': Icons.calendar_today,
        'color': AppTheme.primaryBlue,
        'subtitle': 'Lessons',
        'gradient': [
          AppTheme.primaryBlue,
          AppTheme.primaryBlue.withOpacity(0.7)
        ],
      },
      {
        'title': 'This Month',
        'value': thisMonthCompleted.toString(),
        'icon': Icons.calendar_month,
        'color': AppTheme.warningOrange,
        'subtitle': 'Lessons',
        'gradient': [
          AppTheme.warningOrange,
          AppTheme.warningOrange.withOpacity(0.7)
        ],
      },
      {
        'title': 'Weekly Average',
        'value': averagePerWeek,
        'icon': Icons.trending_up,
        'color': Colors.purple,
        'subtitle': 'Lessons',
        'gradient': [Colors.purple, Colors.purple.withOpacity(0.7)],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lesson Progress Overview',
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
            crossAxisCount: isDesktop ? 4 : (isTablet ? 2 : 2),
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

  Widget _buildLessonProgressSection(BuildContext context, bool isTablet) {
    if (_analyticsData == null) return const SizedBox.shrink();

    final lessonProgress =
        _analyticsData!['lesson_progress'] as Map<String, dynamic>? ?? {};
    final completedLessons =
        lessonProgress['completed_lessons'] as List<dynamic>? ?? [];

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
                  Icons.check_circle,
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
                      'Completed Lessons',
                      style: TextStyle(
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successGreen,
                      ),
                    ),
                    Text(
                      'Your lesson completion history',
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
          if (completedLessons.isEmpty)
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
                      Icons.menu_book,
                      size: isTablet ? 48 : 40,
                      color: AppTheme.successGreen,
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : 12),
                  Text(
                    'No Completed Lessons Yet',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successGreen,
                    ),
                  ),
                  SizedBox(height: isTablet ? 8 : 6),
                  Text(
                    'Start completing lessons to see your progress here',
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
              itemCount:
                  completedLessons.length > 10 ? 10 : completedLessons.length,
              itemBuilder: (context, index) {
                final lesson = completedLessons[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.successGreen.withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.successGreen.withOpacity(0.05),
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
                        color: AppTheme.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: AppTheme.successGreen,
                        size: isTablet ? 24 : 20,
                      ),
                    ),
                    title: Text(
                      lesson['lesson_title'] ?? 'Unknown Lesson',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson['course_title'] ?? 'Unknown Course',
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 10,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: isTablet ? 16 : 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(lesson['completed_at']),
                              style: TextStyle(
                                fontSize: isTablet ? 12 : 10,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.check,
                        size: isTablet ? 16 : 14,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentLessonCompletions(BuildContext context, bool isTablet) {
    if (_analyticsData == null) return const SizedBox.shrink();

    final lessonProgress =
        _analyticsData!['lesson_progress'] as Map<String, dynamic>? ?? {};
    final recentCompletions =
        lessonProgress['recent_completions'] as List<dynamic>? ?? [];

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
                    colors: [Colors.orange, Colors.orange.withOpacity(0.8)],
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
                      'Recent Completions',
                      style: TextStyle(
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                    Text(
                      'Your latest lesson completions',
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
          if (recentCompletions.isEmpty)
            Container(
              padding: EdgeInsets.all(isTablet ? 40 : 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.orange.withOpacity(0.05),
                    Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.schedule,
                      size: isTablet ? 48 : 40,
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : 12),
                  Text(
                    'No Recent Completions',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700],
                    ),
                  ),
                  SizedBox(height: isTablet ? 8 : 6),
                  Text(
                    'Complete lessons to see recent activity here',
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
              itemCount:
                  recentCompletions.length > 5 ? 5 : recentCompletions.length,
              itemBuilder: (context, index) {
                final completion = recentCompletions[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.05),
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
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.play_circle,
                        color: Colors.orange,
                        size: isTablet ? 24 : 20,
                      ),
                    ),
                    title: Text(
                      completion['lesson_title'] ?? 'Unknown Lesson',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          completion['course_title'] ?? 'Unknown Course',
                          style: TextStyle(
                            fontSize: isTablet ? 12 : 10,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: isTablet ? 16 : 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(completion['completed_at']),
                              style: TextStyle(
                                fontSize: isTablet ? 12 : 10,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: isTablet ? 16 : 14,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLearningStatistics(BuildContext context, bool isTablet) {
    if (_analyticsData == null) return const SizedBox.shrink();

    final lessonProgress =
        _analyticsData!['lesson_progress'] as Map<String, dynamic>? ?? {};
    final learningStats =
        lessonProgress['learning_stats'] as Map<String, dynamic>? ?? {};

    final totalCompleted = learningStats['total_completed'] as int? ?? 0;
    final thisWeekCompleted = learningStats['this_week_completed'] as int? ?? 0;
    final thisMonthCompleted =
        learningStats['this_month_completed'] as int? ?? 0;
    final averagePerWeek =
        learningStats['average_per_week'] as String? ?? '0.0';

    return Container(
      padding: EdgeInsets.all(isTablet ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.withOpacity(0.1),
            Colors.purple.withOpacity(0.05),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.purple.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
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
                    colors: [Colors.purple, Colors.purple.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.analytics,
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
                      'Learning Statistics',
                      style: TextStyle(
                        fontSize: isTablet ? 24 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[700],
                      ),
                    ),
                    Text(
                      'Your learning performance metrics',
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
          _buildStatCard(
            'Total Completed',
            totalCompleted.toString(),
            Colors.purple,
            Icons.check_circle,
            isTablet,
          ),
          SizedBox(height: isTablet ? 20 : 16),
          _buildStatCard(
            'This Week',
            thisWeekCompleted.toString(),
            Colors.blue,
            Icons.calendar_today,
            isTablet,
          ),
          SizedBox(height: isTablet ? 20 : 16),
          _buildStatCard(
            'This Month',
            thisMonthCompleted.toString(),
            Colors.orange,
            Icons.calendar_month,
            isTablet,
          ),
          SizedBox(height: isTablet ? 20 : 16),
          _buildStatCard(
            'Weekly Average',
            averagePerWeek,
            Colors.green,
            Icons.trending_up,
            isTablet,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
    bool isTablet,
  ) {
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
                const SizedBox(height: 4),
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
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isTablet) {
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
            'Complete lessons to see your analytics here.',
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 28,
            color: Colors.white,
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 9,
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
