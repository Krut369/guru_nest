import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/theme/app_theme.dart';

class CourseFormDialog extends StatefulWidget {
  final Map<String, dynamic>? course;
  final VoidCallback onSaved;

  const CourseFormDialog({
    Key? key,
    this.course,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<CourseFormDialog> createState() => _CourseFormDialogState();
}

class _CourseFormDialogState extends State<CourseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _priceController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedLevel;
  String? _selectedLanguage;
  bool _isPremium = false;
  bool _isLoading = false;

  List<Map<String, dynamic>> _categories = [];
  List<String> _learnings = [];
  List<Map<String, dynamic>> _includes = [];

  final List<String> _levels = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'All Levels'
  ];
  final List<String> _languages = [
    'English',
    'Spanish',
    'French',
    'German',
    'Chinese',
    'Japanese'
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (widget.course != null) {
      _loadCourseData();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _loadCourseData() {
    final course = widget.course!;
    _titleController.text = course['title'] ?? '';
    _descriptionController.text = course['description'] ?? '';
    _imageUrlController.text = course['image_url'] ?? '';
    _priceController.text = course['price']?.toString() ?? '';
    _selectedCategoryId = course['category_id'];
    _selectedLevel = course['level'] ?? 'Beginner';
    _selectedLanguage = course['language'] ?? 'English';
    _isPremium = course['is_premium'] ?? false;

    _loadCourseDetails();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await supabase.Supabase.instance.client
          .from('categories')
          .select('id, name')
          .order('name');

      setState(() {
        _categories = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  Future<void> _loadCourseDetails() async {
    if (widget.course == null) return;

    try {
      final courseId = widget.course!['id'];

      final learningsResponse = await supabase.Supabase.instance.client
          .from('course_learnings')
          .select('description')
          .eq('course_id', courseId);

      final includesResponse = await supabase.Supabase.instance.client
          .from('course_includes')
          .select('icon, title')
          .eq('course_id', courseId);

      setState(() {
        _learnings =
            List<String>.from(learningsResponse.map((l) => l['description']));
        _includes = List<Map<String, dynamic>>.from(includesResponse);
      });
    } catch (e) {
      print('Error loading course details: $e');
    }
  }

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final courseData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'image_url': _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        'category_id': _selectedCategoryId,
        'level': _selectedLevel ?? 'Beginner',
        'language': _selectedLanguage ?? 'English',
        'is_premium': _isPremium,
        'price': _isPremium && _priceController.text.isNotEmpty
            ? double.tryParse(_priceController.text)
            : null,
      };

      String courseId;
      if (widget.course != null) {
        await supabase.Supabase.instance.client
            .from('courses')
            .update(courseData)
            .eq('id', widget.course!['id']);
        courseId = widget.course!['id'];
      } else {
        final response = await supabase.Supabase.instance.client
            .from('courses')
            .insert(courseData)
            .select('id')
            .single();
        courseId = response['id'];
      }

      // Save learnings
      if (_learnings.isNotEmpty) {
        if (widget.course != null) {
          await supabase.Supabase.instance.client
              .from('course_learnings')
              .delete()
              .eq('course_id', courseId);
        }

        for (final learning in _learnings) {
          await supabase.Supabase.instance.client
              .from('course_learnings')
              .insert({
            'course_id': courseId,
            'description': learning,
          });
        }
      }

      // Save includes
      if (_includes.isNotEmpty) {
        if (widget.course != null) {
          await supabase.Supabase.instance.client
              .from('course_includes')
              .delete()
              .eq('course_id', courseId);
        }

        for (final include in _includes) {
          await supabase.Supabase.instance.client
              .from('course_includes')
              .insert({
            'course_id': courseId,
            'icon': include['icon'],
            'title': include['title'],
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.course != null
                ? 'Course updated successfully'
                : 'Course created successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving course: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addLearning() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Learning Outcome'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'What will students learn?',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _learnings.add(controller.text.trim());
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addInclude() {
    final iconController = TextEditingController();
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Course Include'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: iconController,
              decoration: const InputDecoration(
                hintText: 'Icon (e.g., video, download, access)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: 'Title (e.g., 10 hours on-demand video)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                setState(() {
                  _includes.add({
                    'icon': iconController.text.trim(),
                    'title': titleController.text.trim(),
                  });
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(
                  widget.course != null ? Icons.edit : Icons.add,
                  color: AppTheme.primaryBlue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.course != null ? 'Edit Course' : 'Create Course',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Information
                      _buildSectionTitle('Basic Information'),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Course Title *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Please enter a course title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _imageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Image URL',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Course Details
                      _buildSectionTitle('Course Details'),
                      DropdownButtonFormField<String>(
                        value: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category['id'].toString(),
                            child: Text(category['name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategoryId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedLevel,
                              decoration: const InputDecoration(
                                labelText: 'Level',
                                border: OutlineInputBorder(),
                              ),
                              items: _levels.map((level) {
                                return DropdownMenuItem(
                                  value: level,
                                  child: Text(level),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedLevel = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedLanguage,
                              decoration: const InputDecoration(
                                labelText: 'Language',
                                border: OutlineInputBorder(),
                              ),
                              items: _languages.map((language) {
                                return DropdownMenuItem(
                                  value: language,
                                  child: Text(language),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedLanguage = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Pricing
                      _buildSectionTitle('Pricing'),
                      Row(
                        children: [
                          Checkbox(
                            value: _isPremium,
                            onChanged: (value) {
                              setState(() {
                                _isPremium = value ?? false;
                              });
                            },
                          ),
                          const Text('Premium Course'),
                        ],
                      ),
                      if (_isPremium) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(
                            labelText: 'Price (\$)',
                            border: OutlineInputBorder(),
                            prefixText: '\$',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (_isPremium && (value?.trim().isEmpty ?? true)) {
                              return 'Please enter a price for premium courses';
                            }
                            if (value?.isNotEmpty ?? false) {
                              final price = double.tryParse(value!);
                              if (price == null || price < 0) {
                                return 'Please enter a valid price';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Learning Outcomes
                      _buildSectionTitle('Learning Outcomes'),
                      ..._learnings.map((learning) => Card(
                            child: ListTile(
                              title: Text(learning),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  setState(() {
                                    _learnings.remove(learning);
                                  });
                                },
                              ),
                            ),
                          )),
                      ElevatedButton.icon(
                        onPressed: _addLearning,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Learning Outcome'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Course Includes
                      _buildSectionTitle('Course Includes'),
                      ..._includes.map((include) => Card(
                            child: ListTile(
                              leading: Icon(
                                _getIconFromString(include['icon']),
                                color: AppTheme.primaryBlue,
                              ),
                              title: Text(include['title']),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  setState(() {
                                    _includes.remove(include);
                                  });
                                },
                              ),
                            ),
                          )),
                      ElevatedButton.icon(
                        onPressed: _addInclude,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Course Include'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveCourse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(widget.course != null ? 'Update' : 'Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryBlue,
        ),
      ),
    );
  }

  IconData _getIconFromString(String? iconString) {
    if (iconString == null || iconString.isEmpty) {
      return Icons.check_circle;
    }

    switch (iconString.toLowerCase()) {
      case 'video':
        return Icons.video_library;
      case 'download':
        return Icons.download;
      case 'access':
        return Icons.access_time;
      case 'certificate':
        return Icons.verified;
      default:
        return Icons.check_circle;
    }
  }
}
