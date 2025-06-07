import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/enrollment_model.dart';
import '../../../services/enrollment_service.dart';

class MyCoursesSection extends StatefulWidget {
  const MyCoursesSection({super.key});

  @override
  State<MyCoursesSection> createState() => _MyCoursesSectionState();
}

class _MyCoursesSectionState extends State<MyCoursesSection> {
  final _enrollmentService = EnrollmentService();
  bool _isLoading = true;
  String? _error;
  List<Enrollment> _enrollments = [];

  @override
  void initState() {
    super.initState();
    _loadEnrollments();
  }

  Future<void> _loadEnrollments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');

      if (userJson == null) {
        setState(() {
          _isLoading = false;
          _error = 'Please log in to view your courses';
        });
        return;
      }

      final userData = jsonDecode(userJson);
      final userId = userData['id'] as String;

      final enrollments = await _enrollmentService.getEnrollments(userId);
      setState(() {
        _enrollments = enrollments;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading enrollments: $e');
      setState(() {
        _isLoading = false;
        _error = 'Failed to load courses';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Courses'),
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
                        onPressed: _loadEnrollments,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _enrollments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'You haven\'t enrolled in any courses yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.textGrey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              context.push('/dashboard/courses');
                            },
                            child: const Text('Browse Courses'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadEnrollments,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.defaultPadding),
                        itemCount: _enrollments.length,
                        itemBuilder: (context, index) {
                          final enrollment = _enrollments[index];
                          final course = enrollment.course;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: InkWell(
                              onTap: () {
                                context.push('/dashboard/courses/${course.id}');
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (course.imageUrl != null &&
                                      course.imageUrl!.isNotEmpty)
                                    Image.network(
                                      course.imageUrl!,
                                      height: 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          height: 200,
                                          color: AppTheme.primaryBlue
                                              .withOpacity(0.1),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          course.title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          course.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppTheme.textGrey,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Enrolled on ${_formatDate(enrollment.enrolledAt)}',
                                              style: const TextStyle(
                                                color: AppTheme.textGrey,
                                                fontSize: 12,
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                context.push(
                                                    '/dashboard/courses/${course.id}');
                                              },
                                              child: const Text(
                                                  'Continue Learning'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
