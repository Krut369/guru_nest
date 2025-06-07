import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/theme/app_theme.dart';
import '../../widgets/custom_app_bar.dart';

class ManageLessonsPage extends StatefulWidget {
  final String? courseId;

  const ManageLessonsPage({
    super.key,
    this.courseId,
  });

  @override
  State<ManageLessonsPage> createState() => _ManageLessonsPageState();
}

class _ManageLessonsPageState extends State<ManageLessonsPage> {
  List<Map<String, dynamic>> _lessons = [];
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

        // Filter out courses with null IDs
        _courses = _courses.where((course) => course['id'] != null).toList();

        String? determinedSelectedCourseId;
        String? determinedSelectedCourseName;

        if (_courses.isNotEmpty) {
          // Try to find the course based on widget.courseId if provided
          if (widget.courseId != null) {
            final initialCourse = _courses.firstWhere(
              (course) => course['id'] == widget.courseId,
              orElse: () => {},
            );
            if (initialCourse.isNotEmpty) {
              determinedSelectedCourseId = initialCourse['id'];
              determinedSelectedCourseName =
                  initialCourse['title'] ?? 'Untitled Course';
            }
          }

          // If no course selected yet (either no widget.courseId or not found), default to the first course
          if (determinedSelectedCourseId == null) {
            determinedSelectedCourseId = _courses.first['id'];
            determinedSelectedCourseName =
                _courses.first['title'] ?? 'Untitled Course';
          }
        }

        _selectedCourseId = determinedSelectedCourseId;
        _selectedCourseName = determinedSelectedCourseName;

        // Clear lessons if no course is selected
        if (_selectedCourseId == null) {
          _lessons = [];
        }
      });

      // Only load lessons if a course is successfully selected
      if (_selectedCourseId != null) {
        _loadLessons();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLessons() async {
    if (_selectedCourseId == null) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await supabase.Supabase.instance.client
          .from('lessons')
          .select()
          .eq('course_id', _selectedCourseId!)
          .order('lesson_order', ascending: true);

      setState(() {
        _lessons = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteLesson(String lessonId) async {
    try {
      await supabase.Supabase.instance.client
          .from('lessons')
          .delete()
          .eq('id', lessonId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lesson deleted successfully')),
        );
      }

      _loadLessons();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting lesson: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmation(String lessonId, String lessonTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lesson'),
        content: Text('Are you sure you want to delete "$lessonTitle"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteLesson(lessonId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredLessons {
    if (_searchQuery.isEmpty) return _lessons;
    return _lessons.where((lesson) {
      final title = lesson['title']?.toString().toLowerCase() ?? '';
      final content = lesson['content']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || content.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Manage Lessons'),
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
                    borderRadius: BorderRadius.circular(10),
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
                        _loadLessons();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search lessons...',
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
                                  'Select a course to manage lessons',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: AppTheme.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _filteredLessons.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.menu_book,
                                      size: 64,
                                      color: AppTheme.textLightGrey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No lessons found',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: AppTheme.textGrey,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Add your first lesson by clicking the + button',
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
                                itemCount: _filteredLessons.length,
                                itemBuilder: (context, index) {
                                  final lesson = _filteredLessons[index];
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
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    lesson['title'] ??
                                                        'Untitled Lesson',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 18,
                                                    ),
                                                  ),
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    if (index > 0)
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.arrow_upward,
                                                          color: AppTheme
                                                              .primaryBlue,
                                                        ),
                                                        onPressed: () async {
                                                          try {
                                                            final currentOrder =
                                                                lesson['lesson_order']
                                                                    as int;
                                                            final targetLesson =
                                                                _filteredLessons[
                                                                    index - 1];
                                                            final targetOrder =
                                                                targetLesson[
                                                                        'lesson_order']
                                                                    as int;

                                                            await supabase
                                                                .Supabase
                                                                .instance
                                                                .client
                                                                .from('lessons')
                                                                .update({
                                                              'lesson_order':
                                                                  targetOrder
                                                            }).eq(
                                                                    'id',
                                                                    lesson[
                                                                        'id']);

                                                            await supabase
                                                                .Supabase
                                                                .instance
                                                                .client
                                                                .from('lessons')
                                                                .update({
                                                              'lesson_order':
                                                                  currentOrder
                                                            }).eq(
                                                                    'id',
                                                                    targetLesson[
                                                                        'id']);

                                                            _loadLessons();
                                                          } catch (e) {
                                                            if (mounted) {
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                      'Error updating lesson order: $e'),
                                                                  backgroundColor:
                                                                      AppTheme
                                                                          .errorRed,
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        },
                                                      ),
                                                    if (index <
                                                        _filteredLessons
                                                                .length -
                                                            1)
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.arrow_downward,
                                                          color: AppTheme
                                                              .primaryBlue,
                                                        ),
                                                        onPressed: () async {
                                                          try {
                                                            final currentOrder =
                                                                lesson['lesson_order']
                                                                    as int;
                                                            final targetLesson =
                                                                _filteredLessons[
                                                                    index + 1];
                                                            final targetOrder =
                                                                targetLesson[
                                                                        'lesson_order']
                                                                    as int;

                                                            await supabase
                                                                .Supabase
                                                                .instance
                                                                .client
                                                                .from('lessons')
                                                                .update({
                                                              'lesson_order':
                                                                  targetOrder
                                                            }).eq(
                                                                    'id',
                                                                    lesson[
                                                                        'id']);

                                                            await supabase
                                                                .Supabase
                                                                .instance
                                                                .client
                                                                .from('lessons')
                                                                .update({
                                                              'lesson_order':
                                                                  currentOrder
                                                            }).eq(
                                                                    'id',
                                                                    targetLesson[
                                                                        'id']);

                                                            _loadLessons();
                                                          } catch (e) {
                                                            if (mounted) {
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                      'Error updating lesson order: $e'),
                                                                  backgroundColor:
                                                                      AppTheme
                                                                          .errorRed,
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        },
                                                      ),
                                                    PopupMenuButton(
                                                      itemBuilder: (context) =>
                                                          [
                                                        const PopupMenuItem(
                                                          value: 'edit',
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.edit,
                                                                color: AppTheme
                                                                    .primaryBlue,
                                                              ),
                                                              SizedBox(
                                                                  width: 8),
                                                              Text('Edit'),
                                                            ],
                                                          ),
                                                        ),
                                                        const PopupMenuItem(
                                                          value: 'add_material',
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .attach_file,
                                                                color: AppTheme
                                                                    .primaryBlue,
                                                              ),
                                                              SizedBox(
                                                                  width: 8),
                                                              Text(
                                                                  'Add Material'),
                                                            ],
                                                          ),
                                                        ),
                                                        if (index > 0)
                                                          const PopupMenuItem(
                                                            value: 'move_up',
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .arrow_upward,
                                                                  color: AppTheme
                                                                      .primaryBlue,
                                                                ),
                                                                SizedBox(
                                                                    width: 8),
                                                                Text('Move Up'),
                                                              ],
                                                            ),
                                                          ),
                                                        if (index <
                                                            _filteredLessons
                                                                    .length -
                                                                1)
                                                          const PopupMenuItem(
                                                            value: 'move_down',
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  Icons
                                                                      .arrow_downward,
                                                                  color: AppTheme
                                                                      .primaryBlue,
                                                                ),
                                                                SizedBox(
                                                                    width: 8),
                                                                Text(
                                                                    'Move Down'),
                                                              ],
                                                            ),
                                                          ),
                                                        const PopupMenuItem(
                                                          value: 'delete',
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.delete,
                                                                color: AppTheme
                                                                    .errorRed,
                                                              ),
                                                              SizedBox(
                                                                  width: 8),
                                                              Text(
                                                                'Delete',
                                                                style:
                                                                    TextStyle(
                                                                  color: AppTheme
                                                                      .errorRed,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                      onSelected:
                                                          (value) async {
                                                        if (value == 'edit') {
                                                          context.push(
                                                            '/teacher/course/$_selectedCourseId/edit-lesson/${lesson['id']}',
                                                          );
                                                        } else if (value ==
                                                            'add_material') {
                                                          try {
                                                            final courses = await supabase
                                                                .Supabase
                                                                .instance
                                                                .client
                                                                .from('courses')
                                                                .select(
                                                                    'id, title')
                                                                .order(
                                                                    'created_at',
                                                                    ascending:
                                                                        false);

                                                            if (context
                                                                .mounted) {
                                                              showDialog(
                                                                context:
                                                                    context,
                                                                builder:
                                                                    (context) =>
                                                                        AlertDialog(
                                                                  title: const Text(
                                                                      'Select Course'),
                                                                  content: courses
                                                                          .isEmpty
                                                                      ? const Text(
                                                                          'You need to create a course first.')
                                                                      : SizedBox(
                                                                          width:
                                                                              double.maxFinite,
                                                                          child:
                                                                              ListView.builder(
                                                                            shrinkWrap:
                                                                                true,
                                                                            itemCount:
                                                                                courses.length,
                                                                            itemBuilder:
                                                                                (context, index) {
                                                                              final course = courses[index];
                                                                              return ListTile(
                                                                                title: Text(course['title'] ?? 'Untitled Course'),
                                                                                onTap: () {
                                                                                  Navigator.pop(context);
                                                                                  if (context.mounted) {
                                                                                    context.push(
                                                                                      '/teacher/course/${course['id']}/materials',
                                                                                    );
                                                                                  }
                                                                                },
                                                                              );
                                                                            },
                                                                          ),
                                                                        ),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed:
                                                                          () =>
                                                                              Navigator.pop(context),
                                                                      child: const Text(
                                                                          'Cancel'),
                                                                    ),
                                                                  ],
                                                                ),
                                                              );
                                                            }
                                                          } catch (e) {
                                                            if (context
                                                                .mounted) {
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                      'Error loading courses: ${e.toString()}'),
                                                                  backgroundColor:
                                                                      AppTheme
                                                                          .errorRed,
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        } else if (value ==
                                                            'delete') {
                                                          _showDeleteConfirmation(
                                                            lesson['id'],
                                                            lesson['title'] ??
                                                                'Untitled Lesson',
                                                          );
                                                        } else if (value ==
                                                                'move_up' ||
                                                            value ==
                                                                'move_down') {
                                                          try {
                                                            final currentOrder =
                                                                lesson['lesson_order']
                                                                    as int;
                                                            final targetIndex =
                                                                value ==
                                                                        'move_up'
                                                                    ? index - 1
                                                                    : index + 1;
                                                            final targetLesson =
                                                                _filteredLessons[
                                                                    targetIndex];
                                                            final targetOrder =
                                                                targetLesson[
                                                                        'lesson_order']
                                                                    as int;

                                                            await supabase
                                                                .Supabase
                                                                .instance
                                                                .client
                                                                .from('lessons')
                                                                .update({
                                                              'lesson_order':
                                                                  targetOrder
                                                            }).eq(
                                                                    'id',
                                                                    lesson[
                                                                        'id']);

                                                            await supabase
                                                                .Supabase
                                                                .instance
                                                                .client
                                                                .from('lessons')
                                                                .update({
                                                              'lesson_order':
                                                                  currentOrder
                                                            }).eq(
                                                                    'id',
                                                                    targetLesson[
                                                                        'id']);

                                                            _loadLessons();
                                                          } catch (e) {
                                                            if (mounted) {
                                                              ScaffoldMessenger
                                                                      .of(context)
                                                                  .showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                      'Error updating lesson order: $e'),
                                                                  backgroundColor:
                                                                      AppTheme
                                                                          .errorRed,
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              lesson['content'] ?? 'No content',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppTheme.textGrey,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                _buildInfoChip(
                                                  Icons.access_time,
                                                  'Duration: ${lesson['duration'] ?? 'N/A'}',
                                                ),
                                                const SizedBox(width: 12),
                                                _buildInfoChip(
                                                  Icons.sort,
                                                  'Order: ${lesson['lesson_order'] ?? 'N/A'}',
                                                ),
                                              ],
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
                try {
                  final highestOrder = _lessons.isEmpty
                      ? 0
                      : _lessons
                          .map((lesson) => lesson['lesson_order'] as int)
                          .reduce((a, b) => a > b ? a : b);

                  final response = await supabase.Supabase.instance.client
                      .from('lessons')
                      .insert({
                        'title': 'New Lesson',
                        'content': 'Add your lesson content here',
                        'course_id': _selectedCourseId,
                        'lesson_order': highestOrder + 1,
                      })
                      .select()
                      .single();

                  if (mounted) {
                    context.push(
                      '/teacher/course/$_selectedCourseId/edit-lesson/${response['id']}',
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error creating new lesson: $e'),
                        backgroundColor: AppTheme.errorRed,
                      ),
                    );
                  }
                }
              },
              backgroundColor: AppTheme.primaryBlue,
              icon: const Icon(Icons.add),
              label: const Text('Add Lesson'),
            ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.backgroundGrey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppTheme.textGrey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textGrey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
