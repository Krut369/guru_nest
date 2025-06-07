import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/app_theme.dart';
import '../../models/lesson_model.dart';
import '../../services/course_service.dart';

class AddLessonScreen extends StatefulWidget {
  final String courseId;
  final Lesson? lesson; // For editing existing lesson

  const AddLessonScreen({
    Key? key,
    required this.courseId,
    this.lesson,
  }) : super(key: key);

  @override
  State<AddLessonScreen> createState() => _AddLessonScreenState();
}

class _AddLessonScreenState extends State<AddLessonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _orderController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();
  final _courseService = CourseService();
  Lesson? _currentLesson;

  @override
  void initState() {
    super.initState();
    if (widget.lesson != null) {
      _loadLessonData();
    } else {
      _orderController.text = '1';
    }
  }

  Future<void> _loadLessonData() async {
    if (widget.lesson == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final lesson = await _courseService.fetchLessonById(widget.lesson!.id);
      setState(() {
        _currentLesson = lesson;
        _titleController.text = lesson.title;
        _contentController.text = lesson.content ?? '';
        _orderController.text = lesson.lessonOrder.toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading lesson: $e';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _saveLesson() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final lessonData = {
        'id': widget.lesson?.id ?? _uuid.v4(),
        'course_id': widget.courseId,
        'title': _titleController.text,
        'content': _contentController.text,
        'lesson_order': int.parse(_orderController.text),
      };

      if (widget.lesson == null) {
        // Create new lesson
        await _supabase.from('lessons').insert(lessonData);
      } else {
        // Update existing lesson
        await _supabase
            .from('lessons')
            .update(lessonData)
            .eq('id', widget.lesson!.id);
      }

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson == null ? 'Add Lesson' : 'Edit Lesson'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.defaultPadding),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(AppTheme.smallSpacing),
                        margin: const EdgeInsets.only(
                            bottom: AppTheme.defaultSpacing),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Lesson Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.defaultSpacing),
                    TextFormField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: 'Lesson Content',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 10,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter lesson content';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.defaultSpacing),
                    TextFormField(
                      controller: _orderController,
                      decoration: const InputDecoration(
                        labelText: 'Lesson Order',
                        border: OutlineInputBorder(),
                        helperText: 'Enter the order number for this lesson',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter lesson order';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.defaultSpacing * 2),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveLesson,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(widget.lesson == null
                              ? 'Add Lesson'
                              : 'Update Lesson'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
