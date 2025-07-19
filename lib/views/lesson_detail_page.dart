import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_theme.dart';
import '../services/lesson_progress_service.dart';

class LessonDetailPage extends StatefulWidget {
  final String lessonId;
  final String lessonTitle;
  final String courseId;
  final String? lessonDescription; // Add lesson description

  const LessonDetailPage({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
    required this.courseId,
    this.lessonDescription,
  });

  @override
  State<LessonDetailPage> createState() => _LessonDetailPageState();
}

class _LessonDetailPageState extends State<LessonDetailPage> {
  final LessonProgressService _lessonProgressService = LessonProgressService();
  bool _isLoading = true;
  bool _isCompleted = false;
  String? _userId;
  double _completionPercentage = 0.0;
  DateTime? _completedAt;
  List<Map<String, dynamic>> _courseLessons = [];
  int _currentLessonIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadLessonData();
  }

  Future<void> _loadLessonData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get current user ID
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');

      if (userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        _userId = userData['id'] as String;

        if (_userId != null) {
          // Load all data in parallel
          await Future.wait([
            _loadLessonCompletionStatus(),
            _loadCourseProgress(),
            _loadCourseLessons(),
          ]);
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading lesson data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLessonCompletionStatus() async {
    try {
      _isCompleted = await _lessonProgressService.isLessonCompleted(
        _userId!,
        widget.lessonId,
      );

      // Get completion timestamp if completed
      if (_isCompleted) {
        final completedLessons =
            await _lessonProgressService.getCompletedLessons(_userId!);
        final thisLesson = completedLessons.firstWhere(
          (lesson) => lesson['lesson_id'] == widget.lessonId,
          orElse: () => {},
        );
        if (thisLesson.isNotEmpty && thisLesson['completed_at'] != null) {
          _completedAt = DateTime.parse(thisLesson['completed_at']);
        }
      }
    } catch (e) {
      print('Error loading lesson completion status: $e');
    }
  }

  Future<void> _loadCourseProgress() async {
    try {
      _completionPercentage =
          await _lessonProgressService.getCourseCompletionPercentage(
        _userId!,
        widget.courseId,
      );
    } catch (e) {
      print('Error loading course progress: $e');
    }
  }

  Future<void> _loadCourseLessons() async {
    try {
      _courseLessons = await _lessonProgressService.getCourseLessonProgress(
        _userId!,
        widget.courseId,
      );

      // Find current lesson index
      _currentLessonIndex = _courseLessons.indexWhere(
        (lesson) => lesson['lesson_id'] == widget.lessonId,
      );
      if (_currentLessonIndex == -1) _currentLessonIndex = 0;
    } catch (e) {
      print('Error loading course lessons: $e');
    }
  }

  Future<void> _markLessonAsCompleted() async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to mark lesson as completed'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      // Show loading message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marking lesson as completed...'),
          backgroundColor: AppTheme.primaryBlue,
          duration: Duration(seconds: 2),
        ),
      );

      // Debug: Check table structure first
      await _lessonProgressService.debugCheckTableStructure();

      await _lessonProgressService.markLessonCompleted(
        _userId!,
        widget.lessonId,
      );

      // Reload data to update completion status
      await _loadLessonData();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Lesson marked as completed! 🎉'),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          duration: Duration(seconds: 3),
        ),
      );

      // Verify the completion was actually saved
      final verificationCompleted =
          await _lessonProgressService.isLessonCompleted(
        _userId!,
        widget.lessonId,
      );

      if (!verificationCompleted) {
        print('Warning: Lesson completion verification failed');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Warning: Lesson completion may not have been saved properly'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error marking lesson as completed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Error: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: AppTheme.errorRed,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lessonTitle),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isCompleted)
            const IconButton(
              icon: Icon(Icons.check_circle, color: AppTheme.successGreen),
              onPressed: null,
            ),
          // Debug button
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white),
            onPressed: () async {
              print('=== DEBUG BUTTON PRESSED ===');
              await _lessonProgressService.debugCheckTableStructure();
              if (_userId != null) {
                await _lessonProgressService.debugCheckLessonProgress(
                  _userId!,
                  widget.lessonId,
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lesson Header
                  _buildLessonHeader(),
                  const SizedBox(height: 24),

                  // Course Progress
                  _buildCourseProgress(),
                  const SizedBox(height: 24),

                  // Lesson Navigation
                  if (_courseLessons.isNotEmpty) ...[
                    _buildLessonNavigation(),
                    const SizedBox(height: 24),
                  ],

                  // Lesson Content
                  _buildLessonContent(),
                  const SizedBox(height: 32),

                  // Complete Lesson Button
                  _buildCompleteButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildLessonHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue,
            AppTheme.primaryBlue.withOpacity(0.8),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isCompleted ? Icons.check_circle : Icons.play_circle,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.lessonTitle,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isCompleted
                  ? AppTheme.successGreen
                  : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isCompleted ? 'Completed' : 'In Progress',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    _isCompleted ? Colors.white : Colors.white.withOpacity(0.9),
              ),
            ),
          ),
          if (_isCompleted && _completedAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Completed on ${_formatDate(_completedAt!)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCourseProgress() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.trending_up,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Course Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: _completionPercentage / 100,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.successGreen),
                  minHeight: 8,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${_completionPercentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Course completion progress',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonNavigation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.list,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Course Lessons',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...(_courseLessons.asMap().entries.map((entry) {
            final index = entry.key;
            final lesson = entry.value;
            final isCurrentLesson = lesson['lesson_id'] == widget.lessonId;
            final isCompleted = lesson['is_completed'] as bool? ?? false;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCurrentLesson
                    ? AppTheme.primaryBlue.withOpacity(0.1)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCurrentLesson
                      ? AppTheme.primaryBlue
                      : Colors.grey[300]!,
                  width: isCurrentLesson ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCompleted
                        ? Icons.check_circle
                        : isCurrentLesson
                            ? Icons.play_circle
                            : Icons.circle_outlined,
                    color: isCompleted
                        ? AppTheme.successGreen
                        : isCurrentLesson
                            ? AppTheme.primaryBlue
                            : Colors.grey[400],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lesson['lesson_title'] ?? 'Unknown Lesson',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isCurrentLesson
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isCurrentLesson
                            ? AppTheme.primaryBlue
                            : Colors.grey[700],
                      ),
                    ),
                  ),
                  if (isCompleted)
                    const Icon(
                      Icons.check,
                      color: AppTheme.successGreen,
                      size: 16,
                    ),
                ],
              ),
            );
          }).toList()),
        ],
      ),
    );
  }

  Widget _buildLessonContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.menu_book,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
              SizedBox(width: 12),
              Text(
                'Lesson Content',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Display actual lesson description if available
          if (widget.lessonDescription != null &&
              widget.lessonDescription!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                widget.lessonDescription!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
            )
          else
            // Placeholder content
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lesson Content',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This is where your actual lesson content would be displayed. It could include text, images, videos, or interactive elements.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompleteButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isCompleted ? null : _markLessonAsCompleted,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _isCompleted ? AppTheme.successGreen : AppTheme.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isCompleted ? Icons.check_circle : Icons.play_arrow,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              _isCompleted ? 'Lesson Completed' : 'Mark as Completed vbn',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
