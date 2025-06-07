import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/course_model.dart';
import '../../../services/course_service.dart';
import '../../../services/enrollment_service.dart';

class CourseDetailSection extends StatefulWidget {
  final String courseId;

  const CourseDetailSection({
    Key? key,
    required this.courseId,
  }) : super(key: key);

  @override
  State<CourseDetailSection> createState() => _CourseDetailSectionState();
}

class _CourseDetailSectionState extends State<CourseDetailSection> {
  final CourseService _courseService = CourseService();
  final EnrollmentService _enrollmentService = EnrollmentService();
  bool _isLoading = true;
  bool _isEnrolling = false;
  String? _error;
  Course? _course;
  bool _isEnrolled = false;

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  Future<void> _loadCourse() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      if (userJson == null) {
        throw Exception('User not found');
      }

      final user = json.decode(userJson);
      final userId = user['id'] as String;

      final course = await _courseService.getCourse(widget.courseId);
      final isEnrolled =
          await _enrollmentService.isEnrolled(userId, widget.courseId);

      setState(() {
        _course = course;
        _isEnrolled = isEnrolled;
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
        _isEnrolling = true;
        _error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      if (userJson == null) {
        throw Exception('User not found');
      }

      final user = json.decode(userJson);
      final userId = user['id'] as String;

      await _enrollmentService.enrollInCourse(userId, widget.courseId);
      await _loadCourse();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully enrolled in course')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error enrolling in course: $e')),
        );
      }
    } finally {
      setState(() {
        _isEnrolling = false;
      });
    }
  }

  Future<void> _unenrollFromCourse() async {
    try {
      setState(() {
        _isEnrolling = true;
        _error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      if (userJson == null) {
        throw Exception('User not found');
      }

      final user = json.decode(userJson);
      final userId = user['id'] as String;

      await _enrollmentService.unenrollFromCourse(userId, widget.courseId);
      await _loadCourse();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully unenrolled from course')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error unenrolling from course: $e')),
        );
      }
    } finally {
      setState(() {
        _isEnrolling = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCourse,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_course == null) {
      return const Center(child: Text('Course not found'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_course!.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_course!.imageUrl != null && _course!.imageUrl!.isNotEmpty)
              Image.network(
                _course!.imageUrl!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    child: const Icon(
                      Icons.school,
                      size: 48,
                      color: AppTheme.primaryBlue,
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _course!.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _course!.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Price: \$${_course!.price.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isEnrolling
                          ? null
                          : (_isEnrolled
                              ? _unenrollFromCourse
                              : _enrollInCourse),
                      child: _isEnrolling
                          ? const CircularProgressIndicator()
                          : Text(_isEnrolled ? 'Unenroll' : 'Enroll Now'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
