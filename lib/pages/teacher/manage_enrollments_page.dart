import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';

class ManageEnrollmentsPage extends StatefulWidget {
  final String? courseId;

  const ManageEnrollmentsPage({
    super.key,
    this.courseId,
  });

  @override
  State<ManageEnrollmentsPage> createState() => _ManageEnrollmentsPageState();
}

class _ManageEnrollmentsPageState extends State<ManageEnrollmentsPage> {
  List<Map<String, dynamic>> _enrollments = [];
  List<Map<String, dynamic>> _courses = [];
  bool _isLoading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCourseId;
  String? _selectedCourseName;

  @override
  void initState() {
    super.initState();
    _selectedCourseId = widget.courseId;
    _loadCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCourses() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await supabase.Supabase.instance.client
          .from('courses')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _courses = List<Map<String, dynamic>>.from(response);
        _isLoading = false;

        if (_courses.isNotEmpty) {
          if (widget.courseId != null) {
            final initialCourse = _courses.firstWhere(
              (course) => course['id'] == widget.courseId,
              orElse: () => {},
            );
            if (initialCourse.isNotEmpty) {
              _selectedCourseId = initialCourse['id'];
              _selectedCourseName = initialCourse['title'] ?? 'Untitled Course';
            }
          }

          if (_selectedCourseId == null) {
            _selectedCourseId = _courses.first['id'];
            _selectedCourseName = _courses.first['title'] ?? 'Untitled Course';
          }
        }

        if (_selectedCourseId == null) {
          _enrollments = [];
        }
      });

      if (_selectedCourseId != null) {
        _loadEnrollments();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEnrollments() async {
    if (_selectedCourseId == null) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await supabase.Supabase.instance.client
          .from('enrollments')
          .select('''
            *,
            student:users!enrollments_student_id_fkey (
              id,
              full_name,
              email,
              avatar_url
            ),
            course:courses!enrollments_course_id_fkey (
              id,
              title
            )
          ''')
          .eq('course_id', _selectedCourseId!)
          .order('enrolled_at', ascending: false);

      setState(() {
        _enrollments = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _removeEnrollment(String enrollmentId) async {
    try {
      await supabase.Supabase.instance.client
          .from('enrollments')
          .delete()
          .eq('id', enrollmentId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student removed from course successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }

      _loadEnrollments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing student: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showRemoveConfirmation(String enrollmentId, String studentName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text(
            'Are you sure you want to remove $studentName from this course?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeEnrollment(enrollmentId);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredEnrollments {
    if (_searchQuery.isEmpty) return _enrollments;
    return _enrollments.where((enrollment) {
      final studentName =
          enrollment['student']?['full_name']?.toString().toLowerCase() ?? '';
      final studentEmail =
          enrollment['student']?['email']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return studentName.contains(query) || studentEmail.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Manage Enrollments'),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppTheme.backgroundWhite,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.borderGrey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('Select a course'),
                      value: _courses.isEmpty ? null : _selectedCourseId,
                      items: _courses.map((course) {
                        return DropdownMenuItem<String>(
                          value: course['id'],
                          child: Text(course['title'] ?? 'Untitled Course'),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCourseId = newValue;
                          if (newValue != null) {
                            _selectedCourseName = _courses.firstWhere(
                              (course) => course['id'] == newValue,
                              orElse: () => {},
                            )['title'];
                          }
                        });
                        _loadEnrollments();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search students...',
                    hintStyle: const TextStyle(color: AppTheme.textLightGrey),
                    prefixIcon:
                        const Icon(Icons.search, color: AppTheme.primaryBlue),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderGrey),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderGrey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryBlue, width: 2),
                    ),
                    filled: true,
                    fillColor: AppTheme.backgroundWhite,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: AppTheme.textGrey),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 14,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : _selectedCourseId == null
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.school,
                                  size: 64,
                                  color: AppTheme.textLightGrey,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Select a course to manage enrollments',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: AppTheme.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _filteredEnrollments.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people,
                                      size: 64,
                                      color: AppTheme.textLightGrey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No students enrolled',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: AppTheme.textGrey,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Add students by clicking the + button',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.textLightGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredEnrollments.length,
                                itemBuilder: (context, index) {
                                  final enrollment =
                                      _filteredEnrollments[index];
                                  final student = enrollment['student'] ?? {};
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    elevation: 2,
                                    shadowColor:
                                        AppTheme.primaryBlue.withOpacity(0.15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppTheme.backgroundWhite,
                                            AppTheme.primaryBlue
                                                .withOpacity(0.03),
                                            AppTheme.primaryBlue
                                                .withOpacity(0.05),
                                          ],
                                          stops: const [0.0, 0.6, 1.0],
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 24,
                                              backgroundColor: AppTheme
                                                  .primaryBlue
                                                  .withOpacity(0.1),
                                              backgroundImage:
                                                  student['avatar_url'] != null
                                                      ? NetworkImage(
                                                          student['avatar_url'])
                                                      : null,
                                              child: student['avatar_url'] ==
                                                      null
                                                  ? Text(
                                                      (student['full_name'] ??
                                                              '?')[0]
                                                          .toUpperCase(),
                                                      style: const TextStyle(
                                                        color: AppTheme
                                                            .primaryBlue,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    student['full_name'] ??
                                                        'Unknown Student',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    student['email'] ??
                                                        'No email',
                                                    style: const TextStyle(
                                                      color: AppTheme.textGrey,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline),
                                              color: AppTheme.errorRed,
                                              onPressed: () =>
                                                  _showRemoveConfirmation(
                                                enrollment['id'],
                                                student['full_name'] ??
                                                    'Unknown Student',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
          ),
        ],
      ),
      floatingActionButton: _selectedCourseId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                // TODO: Implement add student functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Add student functionality coming soon!'),
                  ),
                );
              },
              backgroundColor: AppTheme.primaryBlue,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Student'),
            ),
    );
  }
}
