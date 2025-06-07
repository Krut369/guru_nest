import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:guru_nest/models/user_model.dart';
import 'package:guru_nest/services/auth_service.dart';
import 'package:guru_nest/services/user_reports_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';

class PerformanceSection extends StatefulWidget {
  const PerformanceSection({super.key});

  @override
  State<PerformanceSection> createState() => _PerformanceSectionState();
}

class _PerformanceSectionState extends State<PerformanceSection> {
  final _authService = AuthService();
  final _userReportsService = UserReportsService();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _userReport;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserAndReport();
  }

  Future<void> _loadUserAndReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load user from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');

      if (userJson == null) {
        setState(() {
          _isLoading = false;
          _error = 'Please log in to view your performance';
        });
        return;
      }

      final userData = jsonDecode(userJson);
      _currentUser = User.fromJson(userData);

      // Load user report
      final report = await _userReportsService.getUserReport(_currentUser!.id);
      setState(() {
        _userReport = report;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user report: $e');
      setState(() {
        _isLoading = false;
        _error = 'Failed to load performance data';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance'),
        actions: [
          if (_currentUser != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadUserAndReport,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
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
                        onPressed: _loadUserAndReport,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUserAndReport,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.defaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOverallProgress(context),
                        const SizedBox(height: AppTheme.defaultPadding),
                        _buildCourseProgress(context),
                        const SizedBox(height: AppTheme.defaultPadding),
                        _buildAchievements(context),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildOverallProgress(BuildContext context) {
    final totalCourses = _userReport?['total_courses_enrolled'] ?? 0;
    final totalLessons = _userReport?['total_lessons_accessed'] ?? 0;
    final totalMaterials = _userReport?['total_materials_accessed'] ?? 0;
    final averageScore = _userReport?['average_quiz_score'] ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall Progress',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textDark,
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
                        '$totalCourses',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Courses Enrolled',
                        style: TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${averageScore.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Average Score',
                        style: TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseProgress(BuildContext context) {
    final totalLessons = _userReport?['total_lessons_accessed'] ?? 0;
    final totalMaterials = _userReport?['total_materials_accessed'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Learning Progress',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppTheme.defaultSpacing),
            _buildProgressItem(
              'Lessons Completed',
              totalLessons,
              AppTheme.primaryBlue,
            ),
            const SizedBox(height: AppTheme.smallSpacing),
            _buildProgressItem(
              'Materials Accessed',
              totalMaterials,
              AppTheme.warningOrange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressItem(String title, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: value > 0 ? 1.0 : 0.0,
          backgroundColor: color.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  Widget _buildAchievements(BuildContext context) {
    final totalCourses = _userReport?['total_courses_enrolled'] ?? 0;
    final totalLessons = _userReport?['total_lessons_accessed'] ?? 0;
    final averageScore = _userReport?['average_quiz_score'] ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Achievements',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppTheme.defaultSpacing),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAchievementItem(
                  Icons.emoji_events,
                  totalCourses.toString(),
                  'Courses Enrolled',
                  AppTheme.warningOrange,
                ),
                _buildAchievementItem(
                  Icons.star,
                  averageScore.toStringAsFixed(1),
                  'Average Score',
                  AppTheme.successGreen,
                ),
                _buildAchievementItem(
                  Icons.trending_up,
                  totalLessons.toString(),
                  'Lessons Completed',
                  AppTheme.primaryBlue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 32,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textGrey,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
