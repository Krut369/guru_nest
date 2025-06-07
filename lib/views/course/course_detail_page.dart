import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconly/iconly.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../models/course_include_model.dart';
import '../../models/course_learning_model.dart';
import '../../models/course_model.dart';
import '../../models/lesson_model.dart';
import '../../models/user_model.dart';
import '../../services/course_service.dart';
import '../../services/enrollment_service.dart';
import '../../services/instructor_service.dart';
import '../payment/student_payment_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;

  const CourseDetailScreen({
    super.key,
    required this.courseId,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailScreen> {
  late Future<Course?> _courseFuture;
  late Future<List<Lesson>> _lessonsFuture;
  Future<Map<String, dynamic>?>? _instructorDetailsFuture;
  Future<int>? _lessonCountFuture;
  Future<List<CourseInclude>>? _courseIncludesFuture;
  Future<List<CourseLearning>>? _courseLearningsFuture;
  bool _isEnrolled = false;
  bool _isLoading = true;
  String? _error;
  String? _userId;
  int _selectedTabIndex = 0;

  final CourseService _courseService = CourseService();
  final EnrollmentService _enrollmentService = EnrollmentService();
  final InstructorService _instructorService = InstructorService();

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
      _lessonCountFuture = _courseService.getLessonCount(widget.courseId);
      _courseIncludesFuture =
          _courseService.fetchCourseIncludes(widget.courseId);
      _courseLearningsFuture =
          _courseService.fetchCourseLearnings(widget.courseId);

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
      await _loadCourse();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully enrolled in course'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error enrolling in course: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _handleEnrollButton(Course course) async {
    if (course.isPremium) {
      final paymentResult = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => StudentPaymentScreen(
            courseId: course.id,
            amount: course.price,
            courseTitle: course.title,
          ),
        ),
      );
      if (paymentResult == true) {
        await _enrollInCourse();
      }
    } else {
      await _enrollInCourse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading course details...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Course Detail'),
          backgroundColor: AppTheme.primaryBlue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorRed,
              ),
              const SizedBox(height: 16),
              const Text(
                'Error loading course',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.errorRed,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadCourse,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: FutureBuilder<Course?>(
        future: _courseFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error loading course: ${snapshot.error}'),
            );
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Course not found'));
          }

          final course = snapshot.data!;

          return CustomScrollView(
            slivers: [
              // App Bar with Course Image
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Course Image
                      if (course.imageUrl != null &&
                          course.imageUrl!.isNotEmpty)
                        Image.network(
                          course.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppTheme.primaryBlue.withOpacity(0.8),
                              child: const Icon(
                                Icons.school,
                                size: 80,
                                color: Colors.white,
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          color: AppTheme.primaryBlue.withOpacity(0.8),
                          child: const Icon(
                            Icons.school,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                      // Course title overlay
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 3,
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (course.teacher != null)
                              Text(
                                'By ${course.teacher!.fullName}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0, 1),
                                      blurRadius: 2,
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () {
                      // TODO: Implement share functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Share feature coming soon!')),
                      );
                    },
                  ),
                ],
              ),

              // Course Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Course Stats Card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                Icons.star,
                                course.rating.toStringAsFixed(1),
                                'Rating',
                                Colors.amber,
                              ),
                              _buildStatItem(
                                Icons.people,
                                course.enrollments.toString(),
                                'Students',
                                AppTheme.primaryBlue,
                              ),
                              FutureBuilder<int>(
                                future: _lessonCountFuture,
                                builder: (context, snapshot) {
                                  final lessonCount = snapshot.data ?? 0;
                                  return _buildStatItem(
                                    Icons.schedule,
                                    lessonCount.toString(),
                                    'Lessons',
                                    Colors.green,
                                  );
                                },
                              ),
                              _buildStatItem(
                                Icons.attach_money,
                                course.isPremium
                                    ? '\$${course.price.toStringAsFixed(0)}'
                                    : 'Free',
                                'Price',
                                course.isPremium ? Colors.green : Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Tab Bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTabButton(
                                'Overview',
                                0,
                                Icons.info_outline,
                              ),
                            ),
                            Expanded(
                              child: _buildTabButton(
                                'Lessons',
                                1,
                                Icons.menu_book,
                              ),
                            ),
                            if (course.teacher != null)
                              Expanded(
                                child: _buildTabButton(
                                  'Instructor',
                                  2,
                                  Icons.person,
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Tab Content
                      IndexedStack(
                        index: _selectedTabIndex,
                        children: [
                          _buildOverviewTab(course),
                          _buildLessonsTab(course),
                          if (course.teacher != null)
                            _buildInstructorTab(course.teacher!),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Enrollment Button
                      if (!_isEnrolled)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () => _handleEnrollButton(course),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                            ),
                            child: const Text(
                              'Enroll Now',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
          // Reset instructor details when switching to instructor tab (if it exists)
          if (index == 2 && _instructorDetailsFuture != null) {
            _instructorDetailsFuture = null;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(Course course) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About This Course',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          course.description,
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 24),

        // Course Details
        const Text(
          'Course Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildDetailItem(Icons.category, 'Category', 'Uncategorized'),
        _buildDetailItem(Icons.school, 'Level', 'All Levels'),
        _buildDetailItem(Icons.language, 'Language', 'English'),
        FutureBuilder<int>(
          future: _lessonCountFuture,
          builder: (context, snapshot) {
            final lessonCount = snapshot.data ?? 0;
            return _buildDetailItem(
                Icons.access_time, 'Duration', '$lessonCount lessons');
          },
        ),

        const SizedBox(height: 24),

        // What You'll Learn Section
        const Text(
          'What You\'ll Learn',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<CourseLearning>>(
          future: _courseLearningsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final learnings = snapshot.data ?? [];
            if (learnings.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: Colors.grey[600], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Learning outcomes will be added soon',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: learnings.map<Widget>((learning) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.primaryBlue.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          learning.description ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),

        const SizedBox(height: 24),

        // Course Includes Section
        const Text(
          'This Course Includes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<CourseInclude>>(
          future: _courseIncludesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final includes = snapshot.data ?? [];
            if (includes.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        color: Colors.grey[600], size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Course materials will be added soon',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: includes.map<Widget>((include) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getIconFromString(include.icon ?? ''),
                          color: Colors.green,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          include.title ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLessonsTab(Course course) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Course Content',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            FutureBuilder<int>(
              future: _lessonCountFuture,
              builder: (context, snapshot) {
                final lessonCount = snapshot.data ?? 0;
                return Text(
                  '$lessonCount lessons',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isEnrolled)
          FutureBuilder<List<Lesson>>(
            future: _lessonsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading lessons: ${snapshot.error}'),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No lessons available yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Lessons will be added soon',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              }

              final lessons = snapshot.data!;
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lessons.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final lesson = lessons[index];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                        child: Text(
                          (index + 1).toString(),
                          style: const TextStyle(
                            color: AppTheme.primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        lesson.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: lesson.content != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                lesson.content!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : null,
                      trailing: const Icon(
                        Icons.play_circle_outline,
                        color: AppTheme.primaryBlue,
                      ),
                      onTap: () {
                        context.push(
                            '/course/${widget.courseId}/lesson/${lesson.id}');
                      },
                    ),
                  );
                },
              );
            },
          )
        else
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryBlue.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: AppTheme.primaryBlue,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enroll to Access Lessons',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enroll in this course to access all lessons and materials',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInstructorTab(User teacher) {
    // Initialize instructor details future if not already done
    _instructorDetailsFuture ??=
        _instructorService.getInstructorDetails(teacher.id);

    return FutureBuilder<Map<String, dynamic>?>(
      future: _instructorDetailsFuture!,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppTheme.errorRed,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Error loading instructor details',
                  style: TextStyle(
                    color: AppTheme.errorRed,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final instructorData = snapshot.data;
        if (instructorData == null) {
          return _buildBasicInstructorInfo(teacher);
        }

        final instructor = instructorData['instructor'] as User;
        final totalCourses = instructorData['totalCourses'] as int;
        final totalStudents = instructorData['totalStudents'] as int;
        final averageRating = instructorData['averageRating'] as double;
        final experienceDays = instructorData['experienceDays'] as int;
        final recentCourses = instructorData['recentCourses'] as List;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructor Profile Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                        backgroundImage: instructor.avatarUrl != null
                            ? NetworkImage(instructor.avatarUrl!)
                            : null,
                        child: instructor.avatarUrl == null
                            ? Text(
                                instructor.fullName
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              instructor.fullName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Instructor',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              instructor.email,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (instructor.bio != null &&
                                instructor.bio!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                instructor.bio!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Instructor Statistics
              const Text(
                'Instructor Statistics',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      Icons.school,
                      totalCourses.toString(),
                      'Courses',
                      AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      Icons.people,
                      totalStudents.toString(),
                      'Students',
                      Colors.green,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Recent Courses
              if (recentCourses.isNotEmpty) ...[
                const Text(
                  'Recent Courses',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentCourses.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final course = recentCourses[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.primaryBlue.withOpacity(0.1),
                          backgroundImage: course['image_url'] != null
                              ? NetworkImage(course['image_url'])
                              : null,
                          child: course['image_url'] == null
                              ? const Icon(
                                  Icons.school,
                                  color: AppTheme.primaryBlue,
                                )
                              : null,
                        ),
                        title: Text(
                          course['title'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  (course['rating'] as num?)
                                          ?.toStringAsFixed(1) ??
                                      '0.0',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Icon(
                                  Icons.people,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${(course['enrollments'] as List?)?.first?['count'] ?? 0}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: course['is_premium'] == true
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '\$${(course['price'] as num?)?.toStringAsFixed(0) ?? '0'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Free',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ],

              const SizedBox(height: 24),

              // Contact Information
              const Text(
                'Contact Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildContactItem(
                        Icons.email,
                        'Email',
                        instructor.email,
                      ),
                      const SizedBox(height: 12),
                      _buildContactItem(
                        Icons.calendar_today,
                        'Member Since',
                        _formatDate(instructor.createdAt),
                      ),
                      if (experienceDays > 0) ...[
                        const SizedBox(height: 12),
                        _buildContactItem(
                          Icons.work,
                          'Teaching Experience',
                          '${(experienceDays / 30).round()} months',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBasicInstructorInfo(User teacher) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About the Instructor',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                  backgroundImage: teacher.avatarUrl != null
                      ? NetworkImage(teacher.avatarUrl!)
                      : null,
                  child: teacher.avatarUrl == null
                      ? Text(
                          teacher.fullName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teacher.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (teacher.bio != null && teacher.bio!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          teacher.bio!,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      IconData icon, String value, String label, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppTheme.primaryBlue,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconFromString(String iconName) {
    // Map string names to Iconly icons
    final Map<String, IconData> iconMap = {
      'video': IconlyBold.video,
      'download': IconlyBold.download,
      'access': IconlyBold.time_circle,
      'certificate': IconlyBold.tick_square,
      'book': IconlyBold.bookmark,
      'file': IconlyBold.document,
      'calendar': IconlyBold.calendar,
      'message': IconlyBold.message,
      'notification': IconlyBold.notification,
      'star': IconlyBold.star,
      'heart': IconlyBold.heart,
      'check': IconlyBold.tick_square,
      'play': IconlyBold.play,
      'volume': IconlyBold.volume_up,
      'camera': IconlyBold.camera,
      'image': IconlyBold.image,
      'folder': IconlyBold.folder,
      'home': IconlyBold.home,
      'settings': IconlyBold.setting,
      'search': IconlyBold.search,
      'plus': IconlyBold.plus,
      'close': IconlyBold.close_square,
      'edit': IconlyBold.edit,
      'delete': IconlyBold.delete,
      'share': IconlyBold.send,
      'lock': IconlyBold.lock,
      'unlock': IconlyBold.unlock,
      'eye': IconlyBold.show,
      'hide': IconlyBold.hide,
      'filter': IconlyBold.filter,
      'grid': IconlyBold.category,
      'more': IconlyBold.more_circle,
      'back': IconlyBold.arrow_left,
      'forward': IconlyBold.arrow_right,
      'up': IconlyBold.arrow_up,
      'down': IconlyBold.arrow_down,
      'quiz': IconlyBold.tick_square,
      'project': IconlyBold.folder,
      'live': IconlyBold.video,
      'handout': IconlyBold.document,
      'resource': IconlyBold.folder,
      'forum': IconlyBold.message,
      'assignment': IconlyBold.edit,
      'discussion': IconlyBold.message,
      'survey': IconlyBold.star,
      'test': IconlyBold.tick_square,
      'guide': IconlyBold.info_circle,
      'template': IconlyBold.document,
    };

    return iconMap[iconName.toLowerCase()] ?? IconlyBold.tick_square;
  }
}
