import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../../../core/theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../views/dashboard/sections/course_section.dart';

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
  List<String> _categories = [];
  List<Map<String, dynamic>> _recentCourses = [];
  Map<String, dynamic> _progressSummary = {};

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

      // Fetch recent courses (not enrolled)
      final coursesData =
          await Supabase.instance.client.from('courses').select('''
            *,
            category:categories!category_id (
              name
            ),
            teacher:users!teacher_id (
              id,
              full_name,
              email,
              avatar_url,
              role,
              created_at
            ),
            enrollments!course_id (count),
            rating
          ''').order('created_at', ascending: false).limit(3);

      // Fetch progress summary using lesson_progress table
      final progressData =
          await Supabase.instance.client.from('lesson_progress').select('''
            *,
            lessons!lesson_id (
              id,
              course_id,
              title
            )
          ''').eq('student_id', userId).eq('is_completed', true);

      final categories = coursesData
          .map((course) =>
              course['category']?['name']?.toString() ?? 'Uncategorized')
          .toSet()
          .toList();
      categories.sort();

      // Calculate progress summary
      final totalCompletedLessons = progressData.length;
      final totalEnrolledCourses = enrolledCoursesData.length;

      setState(() {
        _enrolledCourses = List<Map<String, dynamic>>.from(enrolledCoursesData);
        _categories = categories;
        _recentCourses = List<Map<String, dynamic>>.from(coursesData);
        _progressSummary = {
          'total_completed_lessons': totalCompletedLessons,
          'total_enrolled_courses': totalEnrolledCourses,
          'average_progress': totalEnrolledCourses > 0
              ? (totalCompletedLessons / (totalEnrolledCourses * 10) * 100)
                  .clamp(0, 100)
              : 0.0,
        };
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

  Future<Map<String, dynamic>> _fetchCourseProgress(
      String courseId, String studentId) async {
    final response = await Supabase.instance.client
        .from('course_progress')
        .select('*')
        .eq('course_id', courseId)
        .eq('student_id', studentId)
        .maybeSingle();
    if (response == null) {
      return {
        'completed_lessons': 0,
        'total_lessons': 0,
        'progress_percent': 0.0,
      };
    }
    return response;
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
    final isTablet = screenWidth > 600;

    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue.withOpacity(0.1),
                      AppTheme.primaryBlue.withOpacity(0.05)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Loading your dashboard...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.red.shade50,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _buildModernButton(
                  onPressed: _fetchData,
                  text: 'Retry',
                  icon: Icons.refresh_rounded,
                  color: AppTheme.primaryBlue,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade50],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            // Custom App Bar
            const SliverAppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              pinned: true,
              expandedHeight: 40,
              actions: [],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.zero,
                title: null,
              ),
            ),
            // Progress Summary Card
            SliverToBoxAdapter(child: _buildProgressSummaryCard(isTablet)),
            // Categories as horizontal chips
            SliverToBoxAdapter(child: _buildCategoryChips(context)),
            // Recent Courses as carousel
            SliverToBoxAdapter(
                child: _buildRecentCoursesCarousel(context, isTablet)),
            // ... other sections
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSummaryCard(bool isTablet) {
    final progress = _progressSummary['average_progress'] ?? 0.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 24),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryBlue,
              AppTheme.primaryBlue.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryBlue.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 24 : 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learning Progress',
                      style: TextStyle(
                        fontSize: isTablet ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${progress.toStringAsFixed(1)}% Complete',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: progress / 100,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                ),
                child: Icon(
                  Icons.trending_up_rounded,
                  color: Colors.white,
                  size: isTablet ? 32 : 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesSection(BuildContext context, bool isTablet) {
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
            crossAxisCount: isTablet ? 3 : 2,
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
                  print('Category tapped: $category');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        body: CourseSection(
                          initialCategory: category,
                        ),
                      ),
                    ),
                  );
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
                          color: _getCategoryColor(category).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getCategoryIcon(category),
                          color: _getCategoryColor(category),
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category ?? 'Unnamed Category',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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

  Widget _buildRecentCoursesSection(BuildContext context, bool isTablet) {
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
        FutureBuilder<Set<String>>(
          future: fetchCompletedLessonIds(
              _authService.currentUser!.id, _recentCourses[0]['id']),
          builder: (context, snapshot) {
            final completedLessonIds = snapshot.data ?? {};

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentCourses.length,
              itemBuilder: (context, index) {
                final course = _recentCourses[index];
                final isCompleted = completedLessonIds.contains(course['id']);

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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor:
                                  AppTheme.primaryBlue.withOpacity(0.1),
                              backgroundImage:
                                  course['teacher']?['avatar_url'] != null
                                      ? NetworkImage(
                                          course['teacher']['avatar_url'])
                                      : null,
                              child: course['teacher']?['avatar_url'] == null
                                  ? Text(
                                      (course['teacher']?['full_name'] ??
                                              'Unknown Teacher')
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                course['teacher']?['full_name'] ??
                                    'Unknown Teacher',
                                style: const TextStyle(
                                  color: AppTheme.textGrey,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (course['rating'] ?? 0.0).toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.group,
                              size: 12,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${course['enrollments']?[0]?['count'] ?? 0}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: isCompleted
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.radio_button_unchecked,
                            color: Colors.grey),
                    onTap: () async {
                      final courseId = course['id'];
                      if (courseId != null) {
                        await context.push('/course/$courseId');
                        await updateLessonProgress(
                          _authService.currentUser!.id,
                          courseId,
                          course['id'],
                        );
                        setState(() {});
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildModernButton({
    required VoidCallback onPressed,
    required String text,
    required IconData icon,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: Icon(icon, size: 20),
      label: Text(text),
    );
  }

  Future<void> enrollStudentInCourse(String studentId, String courseId) async {
    print('Enrolling student: $studentId in course: $courseId');
    // 1. Enroll the student in the course (existing logic)
    await Supabase.instance.client.from('enrollments').insert({
      'student_id': studentId,
      'course_id': courseId,
      'enrolled_at': DateTime.now().toIso8601String(),
    });

    // 2. Fetch total lessons for the course
    final lessons = await Supabase.instance.client
        .from('lessons')
        .select('id')
        .eq('course_id', courseId);
    final totalLessons = (lessons as List).length;

    print('Lessons for course $courseId: $lessons');
    print('Total lessons: $totalLessons');

    // 3. Create a new course_progress entry for this student and course
    await Supabase.instance.client.from('course_progress').insert({
      'student_id': studentId,
      'course_id': courseId,
      'completed_lessons': 0,
      'total_lessons': totalLessons,
      'progress_percent': 0.0,
    });
  }

  Future<void> updateLessonProgress(
      String studentId, String courseId, String lessonId) async {
    // 1. Check if this lesson is already marked as completed for this student
    final completed = await Supabase.instance.client
        .from('lesson_progress')
        .select('id')
        .eq('student_id', studentId)
        .eq('lesson_id', lessonId)
        .maybeSingle();

    if (completed == null) {
      // 2. Mark this lesson as completed
      await Supabase.instance.client.from('lesson_progress').insert({
        'student_id': studentId,
        'lesson_id': lessonId,
        'completed_at': DateTime.now().toIso8601String(),
      });

      // 3. Get the course_id for this lesson (if not passed in)
      // 4. Increment completed_lessons in course_progress
      final courseProgress = await Supabase.instance.client
          .from('course_progress')
          .select('*')
          .eq('student_id', studentId)
          .eq('course_id', courseId)
          .maybeSingle();

      if (courseProgress != null) {
        print('Course progress before update: $courseProgress');
        final completedLessons = (courseProgress['completed_lessons'] ?? 0) + 1;
        final totalLessons = courseProgress['total_lessons'] ?? 1;
        final progressPercent = (completedLessons / totalLessons) * 100.0;

        await Supabase.instance.client.from('course_progress').update({
          'completed_lessons': completedLessons,
          'progress_percent': progressPercent,
        }).eq('id', courseProgress['id']);
      }
    }

    print(
        'Updating lesson progress for student: $studentId, course: $courseId, lesson: $lessonId');
  }

  Future<void> updateTotalLessonsForCourse(String courseId) async {
    final lessons = await Supabase.instance.client
        .from('lessons')
        .select('id')
        .eq('course_id', courseId);
    final totalLessons = (lessons as List).length;

    await Supabase.instance.client
        .from('course_progress')
        .update({'total_lessons': totalLessons}).eq('course_id', courseId);
  }

  Future<Set<String>> fetchCompletedLessonIds(
      String studentId, String courseId) async {
    final response = await Supabase.instance.client
        .from('lesson_progress')
        .select('lesson_id')
        .eq('student_id', studentId)
        .eq('is_completed', true);

    return (response as List).map((row) => row['lesson_id'] as String).toSet();
  }

  // Example for horizontal category chips
  Widget _buildCategoryChips(BuildContext context) {
    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = _categories[index];
          return ActionChip(
            label: Text(category,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            avatar: Icon(_getCategoryIcon(category),
                color: _getCategoryColor(category)),
            backgroundColor: _getCategoryColor(category).withOpacity(0.1),
            onPressed: () {
              print('Category tapped: $category');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    body: CourseSection(
                      initialCategory: category,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Example for recent courses carousel
  Widget _buildRecentCoursesCarousel(BuildContext context, bool isTablet) {
    return Container(
      height: isTablet ? 220 : 180,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _recentCourses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final course = _recentCourses[index];
          return _buildCourseCard(course, /*isCompleted*/ false, isTablet);
        },
      ),
    );
  }

  Widget _buildCourseCard(
      Map<String, dynamic> course, bool isCompleted, bool isTablet) {
    final cardHeight = isTablet ? 220.0 : 180.0;
    return SizedBox(
      width: isTablet ? 280 : 240,
      height: cardHeight,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () async {
            final courseId = course['id'];
            if (courseId != null) {
              await context.push('/course/$courseId');
              await updateLessonProgress(
                _authService.currentUser!.id,
                courseId,
                course['id'],
              );
              setState(() {});
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: course['image_url'] != null
                    ? Image.network(
                        course['image_url'],
                        height: cardHeight * 0.55,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Image.asset(
                            'assets/images/course_placeholder.png',
                            height: cardHeight * 0.55,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          );
                        },
                      )
                    : Image.asset(
                        'assets/images/course_placeholder.png',
                        height: cardHeight * 0.55,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course['title'] ?? 'Untitled Course',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.textDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor:
                                AppTheme.primaryBlue.withOpacity(0.1),
                            backgroundImage: course['teacher']?['avatar_url'] !=
                                    null
                                ? NetworkImage(course['teacher']['avatar_url'])
                                : null,
                            child: course['teacher']?['avatar_url'] == null
                                ? Text(
                                    (course['teacher']?['full_name'] ??
                                            'Unknown Teacher')
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              course['teacher']?['full_name'] ??
                                  'Unknown Teacher',
                              style: const TextStyle(
                                color: AppTheme.textGrey,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (course['rating'] ?? 0.0).toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            Icons.group,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${course['enrollments']?[0]?['count'] ?? 0}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 20),
                  Center(
                    child: Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
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
