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
      if (widget.lesson == null) {
        // Create new lesson using service
        await _courseService.createLesson(
          courseId: widget.courseId,
          title: _titleController.text,
          content: _contentController.text,
          lessonOrder: int.parse(_orderController.text),
        );
      } else {
        // Update existing lesson using service
        await _courseService.updateLesson(
          lessonId: widget.lesson!.id,
          courseId: widget.courseId,
          title: _titleController.text,
          content: _contentController.text,
          lessonOrder: int.parse(_orderController.text),
        );
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
    // Glass blue gradient for cards (matches quiz management)
    final BoxDecoration glassBlueCardDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          AppTheme.primaryBlue.withOpacity(0.03),
          AppTheme.primaryBlue.withOpacity(0.05),
        ],
        stops: const [0.0, 0.6, 1.0],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.lesson == null ? 'Add Lesson' : 'Update Lesson',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: Colors.transparent,
                      child: Container(
                        decoration: glassBlueCardDecoration,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lesson Details',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlueDark,
                              ),
                            ),
                            const SizedBox(height: 20),
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
                            const SizedBox(height: 16),
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
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _orderController,
                              decoration: const InputDecoration(
                                labelText: 'Lesson Order',
                                border: OutlineInputBorder(),
                                hintText:
                                    'Enter the order number for this lesson',
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
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _saveLesson,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : Text(
                                        widget.lesson == null
                                            ? 'Add Lesson'
                                            : 'Update Lesson',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                              ),
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
}
