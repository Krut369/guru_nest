import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // Import go_router
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart'; // Import AppTheme for colors and spacing
import '../../models/course_model.dart'; // Corrected import path
import '../../models/lesson_model.dart'; // Corrected import path
import '../../services/course_service.dart';
import '../../services/enrollment_service.dart';

class CourseDetailPage extends StatefulWidget {
  final String courseId;

  const CourseDetailPage({
    super.key,
    required this.courseId,
  });

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  late Future<Course?> _courseFuture;
  late Future<List<Lesson>> _lessonsFuture;
  bool _isEnrolled = false;
  bool _isLoading = true;
  String? _error;
  String? _userId;

  final CourseService _courseService = CourseService();
  final EnrollmentService _enrollmentService = EnrollmentService();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get current user
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson == null) {
        throw Exception('User not found');
      }

      final userData = jsonDecode(userJson);
      _userId = userData['id'] as String;

      // Check enrollment status
      _isEnrolled =
          await _enrollmentService.isEnrolled(_userId!, widget.courseId);

      // Load course and lessons data
      _courseFuture = _courseService.fetchCourseById(widget.courseId);
      _lessonsFuture = _courseService.fetchLessonsForCourse(widget.courseId);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _enrollInCourse() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _enrollmentService.enrollInCourse(_userId!, widget.courseId);
      await _initializeData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully enrolled in course')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error enrolling in course: $e')),
        );
      }
    }
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
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Detail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: FutureBuilder<Course?>(
        future: _courseFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
                child: Text('Error loading course: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Course not found'));
          }

          final course = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(AppTheme.defaultPadding),
            children: [
              // Course Image
              if (course.imageUrl != null && course.imageUrl!.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    course.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        child: const Icon(
                          Icons.school,
                          size: 48,
                          color: AppTheme.primaryBlue,
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 200,
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  child: const Icon(
                    Icons.school,
                    size: 64,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              const SizedBox(height: AppTheme.defaultSpacing),
              // Course Title
              Text(
                course.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.smallSpacing),
              // Teacher Name
              if (course.teacher != null)
                Text(
                  'By ${course.teacher!.fullName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              const SizedBox(height: AppTheme.smallSpacing),
              // Rating and Enrollments
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    course.rating.toStringAsFixed(1) ?? '0.0',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: AppTheme.defaultSpacing),
                  const Icon(Icons.group, color: Colors.grey, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '${course.enrollments} Students',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.defaultSpacing),
              // Price
              if (course.isPremium)
                Text(
                  'Price: \$${course.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                )
              else
                const Text(
                  'Price: Free',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),

              // Course Description Section
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.smallSpacing),
              Text(
                course.description,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: AppTheme.defaultSpacing),

              if (_isEnrolled) ...[
                // Lessons Section (only visible to enrolled users)
                const Text(
                  'Lessons',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.smallSpacing),
                FutureBuilder<List<Lesson>>(
                  future: _lessonsFuture,
                  builder: (context, lessonsSnapshot) {
                    if (lessonsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (lessonsSnapshot.hasError) {
                      return Center(
                          child: Text(
                              'Error loading lessons: ${lessonsSnapshot.error}'));
                    } else if (!lessonsSnapshot.hasData ||
                        lessonsSnapshot.data!.isEmpty) {
                      return const Center(
                          child: Text('No lessons available yet.'));
                    }

                    final lessons = lessonsSnapshot.data!;
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: lessons.length,
                      itemBuilder: (context, index) {
                        final lesson = lessons[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppTheme.primaryBlue.withOpacity(0.1),
                            child: Text(
                              (index + 1).toString(),
                              style: const TextStyle(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(lesson.title),
                          onTap: () {
                            context.push(
                                '/course/${widget.courseId}/lesson/${lesson.id}');
                          },
                        );
                      },
                    );
                  },
                ),
              ] else ...[
                // Preview content for non-enrolled users
                Container(
                  padding: const EdgeInsets.all(AppTheme.defaultPadding),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preview Content',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.smallSpacing),
                      const Text(
                        'Enroll in this course to access all lessons and materials.',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: AppTheme.defaultSpacing),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _enrollInCourse,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Enroll Now',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
