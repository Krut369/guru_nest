import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/analytics_service.dart';
import '../services/user_reports_service.dart';

class ActivityTrackerWidget extends StatefulWidget {
  final String userId;

  const ActivityTrackerWidget({
    super.key,
    required this.userId,
  });

  @override
  State<ActivityTrackerWidget> createState() => _ActivityTrackerWidgetState();
}

class _ActivityTrackerWidgetState extends State<ActivityTrackerWidget> {
  final UserReportsService _userReportsService = UserReportsService();
  final AnalyticsService _analyticsService = AnalyticsService();
  bool _isLoading = false;

  Future<void> _trackLessonAccess() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _userReportsService.updateUserReportOnLessonAccess(widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lesson access tracked! Learning streak updated.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error tracking lesson access: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _trackMaterialAccess() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _userReportsService.updateUserReportOnMaterialAccess(widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Material access tracked! Learning streak updated.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error tracking material access: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _trackQuizCompletion() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate a quiz score of 85%
      await _userReportsService.updateUserReportOnQuizCompletion(
          widget.userId, 85.0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Quiz completion tracked! Learning streak and score updated.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error tracking quiz completion: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _trackCourseEnrollment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _userReportsService
          .updateUserReportOnCourseEnrollment(widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course enrollment tracked!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error tracking course enrollment: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshLearningStreak() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success =
          await _userReportsService.refreshLearningStreak(widget.userId);
      if (mounted) {
        if (success) {
          final currentStreak =
              await _userReportsService.getCurrentLearningStreak(widget.userId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Learning streak refreshed! Current streak: $currentStreak days'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to refresh learning streak'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing learning streak: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.track_changes,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Activity Tracker',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Track your learning activities to update your learning streak:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                ),
              )
            else
              Column(
                children: [
                  _buildActivityButton(
                    'Track Lesson Access',
                    Icons.menu_book,
                    AppTheme.primaryBlue,
                    _trackLessonAccess,
                  ),
                  const SizedBox(height: 8),
                  _buildActivityButton(
                    'Track Material Access',
                    Icons.attach_file,
                    AppTheme.successGreen,
                    _trackMaterialAccess,
                  ),
                  const SizedBox(height: 8),
                  _buildActivityButton(
                    'Track Quiz Completion',
                    Icons.quiz,
                    AppTheme.warningOrange,
                    _trackQuizCompletion,
                  ),
                  const SizedBox(height: 8),
                  _buildActivityButton(
                    'Track Course Enrollment',
                    Icons.school,
                    AppTheme.errorRed,
                    _trackCourseEnrollment,
                  ),
                  const SizedBox(height: 8),
                  _buildActivityButton(
                    'Refresh Streak',
                    Icons.refresh,
                    AppTheme.primaryBlue,
                    _refreshLearningStreak,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
